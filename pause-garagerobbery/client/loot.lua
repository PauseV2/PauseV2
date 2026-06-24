--[[
    client/loot.lua
    Spawns the searchable props (toolboxes/cabinets/shelves/parts
    bins/workbenches) for the active instance, drives the search
    progressbar, and exposes the "sell" / "scrap into materials"
    actions used at the exit point. All rewards are rolled
    server-side - this file only requests actions and reacts to
    the server's confirmation.
]]

GarageRobbery.LootProps = {}
GarageRobbery.LootedSpots = {}

local function searchSpot(index, spot)
    if GarageRobbery.LootedSpots[index] then return end
    if not GarageRobbery.CurrentInstance then return end

    local tierConf = Config.Tiers[GarageRobbery.CurrentInstance.tier]
    GarageRobbery.Progressbar(Config.Locales.searching, tierConf.searchTimeMs, function()
        TriggerServerEvent('garagerobbery:server:SearchSpot', index)
    end)
end

function GarageRobbery.SetupLootSpots(shell)
    GarageRobbery.LootProps = {}
    GarageRobbery.LootedSpots = {}

    for index, spot in ipairs(shell.lootSpots) do
        local hash = GetHashKey(spot.model)
        RequestModel(hash)
        local timeout = 0
        while not HasModelLoaded(hash) and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end

        local obj = CreateObject(hash, spot.coords.x, spot.coords.y, spot.coords.z, false, false, false)
        SetEntityHeading(obj, spot.coords.w or 0.0)
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        SetEntityAsMissionEntity(obj, true, true)

        GarageRobbery.LootProps[index] = obj
        GarageRobbery.AddTargetEntity(obj, {
            {
                icon = 'fas fa-magnifying-glass',
                label = 'Search ' .. spot.label,
                action = function() searchSpot(index, spot) end,
            },
        })
    end
end

function GarageRobbery.CleanupLootSpots()
    for _, obj in pairs(GarageRobbery.LootProps) do
        GarageRobbery.RemoveTargetEntity(obj)
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
    GarageRobbery.LootProps = {}
    GarageRobbery.LootedSpots = {}
end

RegisterNetEvent('garagerobbery:client:SpotLooted', function(index)
    GarageRobbery.LootedSpots[index] = true
    local obj = GarageRobbery.LootProps[index]
    if obj then
        GarageRobbery.RemoveTargetEntity(obj)
    end
end)

-- ---------------------------------------------------------------
-- Selling / material processing (triggered from the exit zone)
-- ---------------------------------------------------------------
local function getOwnedAmount(item)
    local Player = GarageRobbery.QBCore.Functions.GetPlayerData()
    local total = 0
    for _, slot in pairs(Player.items or {}) do
        if slot and slot.name == item then
            total = total + slot.amount
        end
    end
    return total
end

function GarageRobbery.OpenSellMenu()
    local soldAny = false
    for item in pairs(Config.SellPrices) do
        local amount = getOwnedAmount(item)
        if amount > 0 then
            soldAny = true
            TriggerServerEvent('garagerobbery:server:SellItem', item, amount)
        end
    end
    if not soldAny then
        GarageRobbery.Notify('You have nothing to sell.', 'error')
    end
end

function GarageRobbery.OpenScrapMenu()
    local scrappedAny = false
    for item in pairs(Config.ScrapRewards) do
        local amount = getOwnedAmount(item)
        if amount > 0 then
            scrappedAny = true
            TriggerServerEvent('garagerobbery:server:ScrapToMaterials', item, amount)
        end
    end
    if not scrappedAny then
        GarageRobbery.Notify('You have nothing to scrap.', 'error')
    end
end
