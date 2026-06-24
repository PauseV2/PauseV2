--[[
    server/loot.lua
    Server-authoritative reward granting: search-spot loot rolls,
    vehicle part scrap rewards, scrap->materials conversion and
    direct selling. Every action re-validates distance, instance
    ownership and required items - never trust the client's word.
]]

local function buildPartKey(partType, index)
    if index ~= nil then
        return ('%s_%s'):format(partType, tostring(index))
    end
    return partType
end

-- ---------------------------------------------------------------
-- Search spots (toolboxes, cabinets, shelves, parts bins, workbenches)
-- ---------------------------------------------------------------
RegisterNetEvent('garagerobbery:server:SearchSpot', function(spotIndex)
    local src = source
    if not GarageRobbery.RateLimitOk(src, 'searchSpot') then return end

    local instance, garageId = GarageRobbery.GetPlayerInstance(src)
    if not instance then return end

    local shell = Config.Shells[instance.tier]
    local spot = shell.lootSpots[spotIndex]
    if not spot then return end

    if instance.lootedSpots[spotIndex] then
        GarageRobbery.Notify(src, Config.Locales.search_empty, 'error')
        return
    end

    if not GarageRobbery.IsNearCoords(src, spot.coords, Config.AntiAbuse.MaxInteractDistance) then
        GarageRobbery.Notify(src, Config.Locales.too_far, 'error')
        return
    end

    instance.lootedSpots[spotIndex] = true

    local tierConf = Config.Tiers[instance.tier]
    local lootTable = Config.LootTables[tierConf.lootTable] or {}

    local foundAny = false
    for _, entry in ipairs(lootTable) do
        if GarageRobbery.RollChance(entry.chance) then
            local amount = GarageRobbery.RandomAmount(entry.min, entry.max)
            if GarageRobbery.AddItem(src, entry.item, amount) then
                foundAny = true
                GarageRobbery.Notify(src, Config.Locales.found_item:format(amount, entry.item), entry.rare and 'success' or 'primary')
            end
        end
    end

    if not foundAny then
        GarageRobbery.Notify(src, Config.Locales.search_empty, 'error')
    end

    local garage = GarageRobbery.GetGarageById(garageId)
    if garage then
        GarageRobbery.MaybeDropEvidence(src, garage)
    end

    TriggerClientEvent('garagerobbery:client:SpotLooted', src, spotIndex)
end)

-- ---------------------------------------------------------------
-- Vehicle part scrapping
-- ---------------------------------------------------------------
RegisterNetEvent('garagerobbery:server:ScrapPart', function(netId, partType, partIndex)
    local src = source
    if not GarageRobbery.RateLimitOk(src, 'scrapPart') then return end

    local instance, garageId = GarageRobbery.GetPlayerInstance(src)
    if not instance then return end

    local vehicleData = instance.vehicles[netId]
    if not vehicleData then return end -- entity ownership check: must belong to this instance

    local partConf = Config.VehicleParts[partType]
    if not partConf then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return end

    local ped = GetPlayerPed(src)
    local dist = #(GetEntityCoords(ped) - GetEntityCoords(entity))
    if dist > Config.AntiAbuse.MaxVehicleDistance then
        GarageRobbery.Notify(src, Config.Locales.too_far, 'error')
        return
    end

    local key = buildPartKey(partType, partIndex)
    if vehicleData.removed[key] then return end -- anti-duplication: part already taken

    if partConf.requiresHoodRemoved and not vehicleData.removed['hood'] then
        GarageRobbery.Notify(src, 'Remove the hood first.', 'error')
        return
    end

    if partConf.requiredItem and not GarageRobbery.HasItem(src, partConf.requiredItem) then
        GarageRobbery.Notify(src, Config.Locales.no_required_item, 'error')
        return
    end

    if partConf.consumeItem and partConf.requiredItem then
        GarageRobbery.RemoveItem(src, partConf.requiredItem, 1)
    end

    if not GarageRobbery.RollChance(partConf.successChance) then
        GarageRobbery.Notify(src, Config.Locales.scrap_failed:format(partConf.label), 'error')
        TriggerClientEvent('garagerobbery:client:ScrapResult', src, netId, partType, partIndex, false)
        return
    end

    vehicleData.removed[key] = true

    local amount = GarageRobbery.RandomAmount(partConf.rewardMin, partConf.rewardMax)
    GarageRobbery.AddItem(src, partConf.rewardItem, amount)
    GarageRobbery.Notify(src, Config.Locales.scrap_success:format(partConf.label), 'success')

    local garage = GarageRobbery.GetGarageById(garageId)
    if garage then
        GarageRobbery.MaybeDropEvidence(src, garage)
    end

    TriggerClientEvent('garagerobbery:client:ScrapResult', src, netId, partType, partIndex, true)
end)

-- ---------------------------------------------------------------
-- Direct selling
-- ---------------------------------------------------------------
RegisterNetEvent('garagerobbery:server:SellItem', function(item, amount)
    local src = source
    if not GarageRobbery.RateLimitOk(src, 'sellItem') then return end

    amount = math.max(1, math.min(tonumber(amount) or 0, 50))
    local priceConf = Config.SellPrices[item]
    if not priceConf then return end

    local instance = GarageRobbery.GetPlayerInstance(src)
    if not instance then return end

    if Config.Selling.SellAtExit then
        local shell = Config.Shells[instance.tier]
        if not GarageRobbery.IsNearCoords(src, shell.exitPoint, Config.AntiAbuse.MaxInteractDistance) then
            GarageRobbery.Notify(src, Config.Locales.too_far, 'error')
            return
        end
    end

    if not GarageRobbery.HasItem(src, item, amount) then return end

    local multiplier = Config.Tiers[instance.tier].rewardMultiplier
    local total = 0
    for _ = 1, amount do
        total = total + GarageRobbery.RandomAmount(priceConf.min, priceConf.max)
    end
    total = math.floor(total * multiplier)

    if not GarageRobbery.RemoveItem(src, item, amount) then return end
    GarageRobbery.AddMoney(src, total, Config.Selling.PaymentType)
    GarageRobbery.Notify(src, Config.Locales.sold_items:format(total), 'success')
end)

-- ---------------------------------------------------------------
-- Scrap parts into raw crafting materials
-- ---------------------------------------------------------------
RegisterNetEvent('garagerobbery:server:ScrapToMaterials', function(item, amount)
    local src = source
    if not GarageRobbery.RateLimitOk(src, 'scrapToMaterials') then return end

    amount = math.max(1, math.min(tonumber(amount) or 0, 50))
    local recipe = Config.ScrapRewards[item]
    if not recipe then return end

    local instance = GarageRobbery.GetPlayerInstance(src)
    if not instance then return end

    if not GarageRobbery.HasItem(src, item, amount) then return end
    if not GarageRobbery.RemoveItem(src, item, amount) then return end

    for _, reward in ipairs(recipe) do
        local total = 0
        for _ = 1, amount do
            total = total + GarageRobbery.RandomAmount(reward.min, reward.max)
        end
        if total > 0 then
            GarageRobbery.AddItem(src, reward.item, total)
        end
    end
end)
