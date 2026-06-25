-- ============================================================
-- Delivery lifecycle: meet setup (face-to-face vs dead drop) and the
-- actual hand-the-drugs-over / get-paid resolution.
-- ============================================================

local function pickMeetCoords()
    -- simple radius pick around a handful of busy spots; swap for your own
    -- city-wide point list if you want tighter control.
    local spots = {
        vector3(195.0, -933.5, 30.7),
        vector3(-547.0, -855.0, 29.0),
        vector3(811.0, -1290.0, 26.2),
        vector3(-1037.0, -1280.0, 5.6),
        vector3(1265.0, -1710.0, 53.2),
    }
    local base = OVI.RandomFrom(spots)
    return vector3(
        base.x + math.random(-20, 20) * 1.0,
        base.y + math.random(-20, 20) * 1.0,
        base.z
    )
end

RegisterNetEvent('ovi:server:initiateMeet', function(deliveryId)
    local src = source
    local imei = OVI.GetOpenImei(src)
    if not imei then return end

    local delivery = OVI.DB.GetDelivery(deliveryId)
    if not delivery or delivery.phone_imei ~= imei or delivery.status ~= 'accepted' then return end

    local special = Config.Toggle.RandomContacts and OVI.ConsumeSpecialEncounter(delivery.contact_id)

    if special == 'police' then
        local coords = pickMeetCoords()
        TriggerEvent('ovi:server:notifyPolice', src, 'tipped off meet location')
        if Config.Toggle.Heat then OVI.AddHeat(imei, Config.Heat.increments.policeSighting, 'sting') end
        TriggerClientEvent('ovi:client:startMeet', src, deliveryId, coords, false)
        return
    end

    if Config.Toggle.DeadDrops and OVI.Chance(Config.DeadDrops.chance) and not special then
        TriggerEvent('ovi:server:setupDeadDrop', src, deliveryId)
        return
    end

    local coords = pickMeetCoords()
    local isTrap = special == 'robbery' or special == 'rivalTrap'

    if not isTrap and Config.Toggle.Traps then
        local chance = Config.Traps.baseChance + OVI.GetTrapHeatBonus(imei)
        isTrap = OVI.Chance(chance)
    end

    MySQL.update.await('UPDATE ovi_deliveries SET location = ? WHERE id = ?', {
        ('%.2f,%.2f,%.2f'):format(coords.x, coords.y, coords.z), deliveryId,
    })
    OVI.DB.AddGPSLog(imei, coords.x, coords.y, coords.z, 'meet')

    if isTrap then
        TriggerEvent('ovi:server:setupTrap', src, deliveryId, coords)
    else
        TriggerClientEvent('ovi:client:startMeet', src, deliveryId, coords, false)
    end
end)

--- Shared resolution used by both face-to-face and dead drop hand-offs.
--- Returns true/false plus a reason on failure.
function OVI.FulfillDelivery(source, deliveryId, payoutMultiplier)
    local Player = OVI.GetPlayer(source)
    if not Player then return false, 'no player' end

    local delivery = OVI.DB.GetDelivery(deliveryId)
    if not delivery or delivery.status ~= 'accepted' then return false, 'invalid delivery' end

    local drugCfg = Config.Drugs[delivery.drug]
    if not drugCfg then return false, 'bad drug config' end

    local hasItem = Player.Functions.GetItemByName(drugCfg.item)
    if not hasItem or hasItem.amount < delivery.quantity then
        return false, 'not enough product'
    end

    Player.Functions.RemoveItem(drugCfg.item, delivery.quantity)
    local payout = math.floor(delivery.price * (payoutMultiplier or 1))
    Player.Functions.AddMoney('cash', payout)

    OVI.DB.SetDeliveryStatus(deliveryId, 'success')

    local imei = delivery.phone_imei
    OVI.DB.AddReputation(imei, 5)

    if Config.Toggle.Trust then
        OVI.AdjustTrust(imei, delivery.contact_id, 'onTime')
        OVI.AdjustTrust(imei, delivery.contact_id, 'rightProduct')
    end

    if Config.Toggle.Heat then
        OVI.AddHeat(imei, Config.Heat.increments.delivery, 'delivery')
    end

    local contactRow = OVI.DB.GetPhoneContact(imei, delivery.contact_id)
    if contactRow then
        OVI.DB.UpdatePhoneContact(imei, delivery.contact_id, { deliveries_done = contactRow.deliveries_done + 1 })
        if Config.Toggle.Referrals then
            TriggerEvent('ovi:server:checkReferral', imei, delivery.contact_id, contactRow.deliveries_done + 1)
        end
    end

    TriggerClientEvent('QBCore:Notify', source, ('Delivery complete. +$%d'):format(payout), 'success')
    OVI.NotifyPhoneHolder(imei, {
        type = 'deliveryComplete',
        deliveryId = deliveryId,
        notification = 'OVI: delivery confirmed',
    })

    return true
end

RegisterNetEvent('ovi:server:completeDelivery', function(deliveryId)
    OVI.FulfillDelivery(source, deliveryId, 1.0)
end)
