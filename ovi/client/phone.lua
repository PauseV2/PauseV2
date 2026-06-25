-- ============================================================
-- Dashboard NUI actions (negotiate, accept shared offers, head to a meet)
-- and the face-to-face meet hand-off itself.
-- ============================================================

local activeMeet = nil -- { deliveryId, blip, zoneName }

local function clearActiveMeet()
    if not activeMeet then return end
    if activeMeet.blip then RemoveBlip(activeMeet.blip) end
    if activeMeet.zoneName and exports['qb-target'] then
        exports['qb-target']:RemoveZone(activeMeet.zoneName)
    end
    activeMeet = nil
end

RegisterNUICallback('negotiate', function(data, cb)
    TriggerServerEvent('ovi:server:negotiate', data.deliveryId, data.contactId, data.text)
    cb('ok')
end)

RegisterNUICallback('claimSharedOffer', function(data, cb)
    TriggerServerEvent('ovi:server:claimSharedOffer', data.offerId)
    cb('ok')
end)

RegisterNUICallback('initiateMeet', function(data, cb)
    TriggerServerEvent('ovi:server:initiateMeet', data.deliveryId)
    cb('ok')
end)

RegisterNUICallback('fileComplaintAck', function(_, cb) cb('ok') end)

RegisterNetEvent('ovi:client:startMeet', function(deliveryId, coords, isDeadDrop)
    clearActiveMeet()

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('OVI Meet')
    EndTextCommandSetBlipName(blip)

    local zoneName = ('ovi_meet_%d'):format(deliveryId)
    activeMeet = { deliveryId = deliveryId, blip = blip, zoneName = zoneName }

    exports['qb-target']:AddBoxZone(zoneName, coords, 2.0, 2.0, {
        name = zoneName,
        heading = 0,
        debugPoly = false,
        minZ = coords.z - 1.5,
        maxZ = coords.z + 1.5,
    }, {
        options = {
            {
                type = 'client',
                icon = 'fas fa-handshake',
                label = 'Hand Off Package',
                action = function()
                    TriggerServerEvent('ovi:server:completeDelivery', deliveryId)
                    clearActiveMeet()
                end,
            },
        },
        distance = 2.0,
    })

    QBCore.Functions.Notify('Meet location marked on GPS.', 'primary')
end)

RegisterNetEvent('ovi:client:dealHandled', function()
    clearActiveMeet()
end)
