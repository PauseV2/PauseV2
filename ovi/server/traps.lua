-- ============================================================
-- Ambush meetings. Combat itself plays out client side (peds/weapons);
-- this file decides whether a meet becomes a trap, and resolves the
-- aftermath (loot, trust, heat) once the client reports back.
-- ============================================================

if not Config.Toggle.Traps then return end

local Traps = Config.Traps

RegisterNetEvent('ovi:server:setupTrap', function(src, deliveryId, coords)
    local delivery = OVI.DB.GetDelivery(deliveryId)
    if not delivery then return end

    TriggerClientEvent('ovi:client:spawnAmbush', src, deliveryId, coords, {
        npcCount = OVI.RandomRange(Traps.ambushNpcCount[1], Traps.ambushNpcCount[2]),
        weapons = Traps.npcWeapons,
        accuracy = Traps.npcAccuracy,
        combatAbility = Traps.npcCombatAbility,
        vehicleModel = OVI.RandomFrom(Traps.vehicleModels),
    })

    if Config.Toggle.Heat then
        OVI.AddHeat(delivery.phone_imei, Config.Heat.increments.failedTrap, 'trap_meet')
    end

    OVI.DB.SetDeliveryStatus(deliveryId, 'trap')
end)

local function rollVehicleLoot()
    local VL = Config.VehicleLoot
    local rolls = OVI.RandomRange(VL.rolls[1], VL.rolls[2])
    local loot = {}

    for _ = 1, rolls do
        local entry = OVI.WeightedRandom(VL.table)
        if entry then
            loot[#loot + 1] = {
                item = entry.item,
                amount = OVI.RandomRange(entry.min, entry.max),
                rarity = entry.rarity,
            }
        end
    end

    return loot
end

RegisterNetEvent('ovi:server:trapResult', function(deliveryId, result)
    local src = source
    local Player = OVI.GetPlayer(src)
    if not Player then return end

    local delivery = OVI.DB.GetDelivery(deliveryId)
    local imei = delivery and delivery.phone_imei or OVI.GetOpenImei(src)

    if result == 'won' then
        local loot = rollVehicleLoot()
        for _, drop in ipairs(loot) do
            Player.Functions.AddItem(drop.item, drop.amount)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[drop.item], 'add')
        end
        OVI.DB.AddTrapResult(Player.PlayerData.citizenid, imei, 'won', json.encode(loot))
        TriggerClientEvent('QBCore:Notify', src, 'You searched the trap vehicle.', 'success')
    else
        OVI.DB.AddTrapResult(Player.PlayerData.citizenid, imei, result, nil)
    end
end)
