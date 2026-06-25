-- ============================================================
-- Dead drop hand-offs: a prop spawns at the location the server picked,
-- player interacts with it via qb-target instead of meeting anyone.
-- ============================================================

if not Config.Toggle.DeadDrops then return end

local activeDrop = nil -- { deliveryId, object, blip }

local function clearActiveDrop()
    if not activeDrop then return end
    if activeDrop.object and DoesEntityExist(activeDrop.object) then
        exports['qb-target']:RemoveTargetEntity(activeDrop.object)
        DeleteObject(activeDrop.object)
    end
    if activeDrop.blip then RemoveBlip(activeDrop.blip) end
    activeDrop = nil
end

RegisterNetEvent('ovi:client:startDeadDrop', function(deliveryId, spot)
    clearActiveDrop()

    local model = joaat(spot.prop)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    local obj = CreateObject(model, spot.coords.x, spot.coords.y, spot.coords.z, false, false, false)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)

    local blip = AddBlipForCoord(spot.coords.x, spot.coords.y, spot.coords.z)
    SetBlipSprite(blip, 478)
    SetBlipColour(blip, 2)
    SetBlipScale(blip, 0.7)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Dead Drop')
    EndTextCommandSetBlipName(blip)

    activeDrop = { deliveryId = deliveryId, object = obj, blip = blip }

    exports['qb-target']:AddTargetEntity(obj, {
        options = {
            {
                type = 'client',
                icon = Config.DeadDrops.target.icon,
                label = Config.DeadDrops.target.label,
                action = function()
                    TriggerServerEvent('ovi:server:collectDeadDrop', deliveryId)
                    clearActiveDrop()
                end,
            },
        },
        distance = Config.DeadDrops.target.distance,
    })

    QBCore.Functions.Notify('Dead drop marked on GPS.', 'primary')
end)
