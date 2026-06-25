-- ============================================================
-- Dead drop deliveries: no face-to-face meet, player interacts with a
-- prop via qb-target instead.
-- ============================================================

if not Config.Toggle.DeadDrops then return end

local DeadDrops = Config.DeadDrops

RegisterNetEvent('ovi:server:setupDeadDrop', function(src, deliveryId)
    local delivery = OVI.DB.GetDelivery(deliveryId)
    if not delivery then return end

    local spot = OVI.RandomFrom(DeadDrops.locations)
    if not spot then return end

    MySQL.update.await('UPDATE ovi_deliveries SET location = ?, dead_drop = 1 WHERE id = ?', {
        ('%.2f,%.2f,%.2f'):format(spot.coords.x, spot.coords.y, spot.coords.z), deliveryId,
    })

    -- trap roll is never told to the client - they only find out by walking into it
    TriggerClientEvent('ovi:client:startDeadDrop', src, deliveryId, spot)
end)

RegisterNetEvent('ovi:server:collectDeadDrop', function(deliveryId)
    local src = source
    local delivery = OVI.DB.GetDelivery(deliveryId)
    if not delivery or delivery.status ~= 'accepted' then return end

    if Config.Toggle.Traps and OVI.Chance(Config.Traps.baseChance * DeadDrops.riskMultiplier) then
        local x, y, z = delivery.location:match('([^,]+),([^,]+),([^,]+)')
        local coords = x and vector3(tonumber(x), tonumber(y), tonumber(z)) or GetEntityCoords(GetPlayerPed(src))
        TriggerEvent('ovi:server:setupTrap', src, deliveryId, coords)
        return
    end

    OVI.FulfillDelivery(src, deliveryId, DeadDrops.payoutMultiplier)
end)
