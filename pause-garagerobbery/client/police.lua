--[[
    client/police.lua
    Police-side presentation: dispatch alerts, evidence notifications
    and the raid call point. The actual disable/alert decisions are
    all made server-side (server/police.lua) - this file only reacts.
]]

local activeAlertZones = {}

RegisterNetEvent('garagerobbery:client:PoliceAlert', function(payload)
    GarageRobbery.Notify(('Garage breach reported: %s'):format(payload.label), 'error')

    local blip = AddBlipForCoord(payload.coords.x, payload.coords.y, payload.coords.z)
    SetBlipSprite(blip, Config.PoliceSettings.BlipSprite)
    SetBlipColour(blip, Config.PoliceSettings.BlipColor)
    SetBlipScale(blip, Config.PoliceSettings.BlipScale)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Garage Robbery - ' .. payload.label)
    EndTextCommandSetBlipName(blip)

    local zoneName = 'garagerobbery_raid_' .. payload.garageId
    if not activeAlertZones[zoneName] then
        activeAlertZones[zoneName] = true
        GarageRobbery.AddBoxZone(zoneName, payload.coords, 2.0, 2.0, payload.coords.w or 0.0, {
            {
                icon = 'fas fa-shield-halved',
                label = 'Call Raid',
                action = function() TriggerServerEvent('garagerobbery:server:CallRaid', payload.garageId) end,
            },
        })
    end

    SetTimeout(Config.PoliceSettings.BlipDuration * 1000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        GarageRobbery.RemoveZone(zoneName)
        activeAlertZones[zoneName] = nil
    end)
end)

RegisterNetEvent('garagerobbery:client:EvidenceFound', function(payload)
    GarageRobbery.Notify(('Evidence (%s) recovered near %s'):format(payload.kind, payload.label), 'primary')
end)

RegisterNetEvent('garagerobbery:client:RaidCalled', function(garage)
    GarageRobbery.Notify('Police have been dispatched to raid the garage!', 'error')
end)

RegisterNetEvent('garagerobbery:client:RaidConfirmed', function(garage, bucket)
    GarageRobbery.Notify(('Raid confirmed at %s'):format(garage.label), 'success')
    -- Hook point: if Config.PoliceSettings.CameraResource is set, trigger your
    -- camera resource's spectate/viewer here, e.g.:
    -- exports[Config.PoliceSettings.CameraResource]:ViewBucket(bucket)
end)
