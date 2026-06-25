-- ============================================================
-- Selling drugs to random street NPCs (not OVI contacts). Pure street
-- hustle - outcome is rolled here, never trusted to the client.
-- ============================================================

if not Config.Toggle.StreetSales then return end

local Street = Config.StreetSales
OVI.Cache.streetSaleCooldown = OVI.Cache.streetSaleCooldown or {}

local function rollOutcome()
    local pool = {
        { key = 'success',      weight = Street.outcomes.success },
        { key = 'reject',       weight = Street.outcomes.reject },
        { key = 'robbery',      weight = Street.outcomes.robbery },
        { key = 'policeSetup',  weight = Street.outcomes.policeSetup },
        { key = 'contactOffer', weight = Street.outcomes.contactOffer },
    }
    local picked = OVI.WeightedRandom(pool)
    return picked and picked.key or 'reject'
end

RegisterNetEvent('ovi:server:streetSale', function(drugKey, amount, npcCoords)
    local src = source
    local Player = OVI.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    if OVI.Cache.streetSaleCooldown[citizenid] and OVI.Cache.streetSaleCooldown[citizenid] > os.time() then
        return
    end

    local drugCfg = Config.Drugs[drugKey]
    amount = tonumber(amount)
    if not drugCfg or not amount or amount <= 0 then return end

    local ped = GetPlayerPed(src)
    if npcCoords then
        local dist = #(GetEntityCoords(ped) - vector3(npcCoords.x, npcCoords.y, npcCoords.z))
        if dist > Street.sellDistance + 2.0 then return end
    end

    local hasItem = Player.Functions.GetItemByName(drugCfg.item)
    if not hasItem or hasItem.amount < amount then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have enough product on you.', 'error')
        return
    end

    OVI.Cache.streetSaleCooldown[citizenid] = os.time() + Street.cooldown

    local outcome = rollOutcome()
    local price = math.floor(drugCfg.basePrice * drugCfg.marketMultiplier * amount)

    if outcome == 'success' then
        Player.Functions.RemoveItem(drugCfg.item, amount)
        Player.Functions.AddMoney('cash', price)
        TriggerClientEvent('QBCore:Notify', src, ('Sold %d %s for $%d.'):format(amount, drugCfg.label, price), 'success')
    elseif outcome == 'reject' then
        TriggerClientEvent('QBCore:Notify', src, "Nah, I'm good.", 'primary')
    elseif outcome == 'robbery' then
        local lossAmount = math.ceil(amount * (Street.robbery.lossPercent / 100))
        Player.Functions.RemoveItem(drugCfg.item, math.min(lossAmount, hasItem.amount))
        TriggerClientEvent('ovi:client:streetSaleRobbed', src, Street.robbery.weaponChance and OVI.Chance(Street.robbery.weaponChance) or false)
        TriggerClientEvent('QBCore:Notify', src, 'You got robbed!', 'error')
    elseif outcome == 'policeSetup' then
        if Street.policeSetup.alertPolice then
            TriggerEvent('ovi:server:notifyPolice', src, Street.policeSetup.dispatchMessage)
        end
        TriggerClientEvent('QBCore:Notify', src, 'That was a setup...', 'error')
    elseif outcome == 'contactOffer' then
        Player.Functions.RemoveItem(drugCfg.item, amount)
        Player.Functions.AddMoney('cash', price)
        TriggerClientEvent('QBCore:Notify', src, ('Sold %d %s for $%d.'):format(amount, drugCfg.label, price), 'success')

        if Street.contactOffer.requiresOVI and Config.Toggle.OVIInstaller then
            local imei = OVI.GetOpenImei(src)
            if imei and OVI.Chance(Street.contactOffer.chance) then
                local contactId = OVI.CreateNewContact(imei, nil, false)
                if contactId then
                    TriggerClientEvent('QBCore:Notify', src, 'That guy says he might have steady work for you. Check OVI.', 'primary')
                end
            end
        end
    end

    TriggerClientEvent('ovi:client:streetSaleResult', src, outcome)
end)
