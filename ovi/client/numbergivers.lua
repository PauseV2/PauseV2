-- ============================================================
-- Spawns the number-giver NPCs (config/numbergivers.lua) and offers
-- Accept/Decline as two independent qb-target options on the same ped.
-- Eligibility (a phone with OVI installed) is checked server side.
-- ============================================================

if not Config.Toggle.NumberGivers then return end

local function respond(npcIndex, accept)
    if not OVI.State.lastPhoneSlot then
        QBCore.Functions.Notify('You need a phone in hand first.', 'error')
        return
    end
    TriggerServerEvent('ovi:server:numberGiverResponse', OVI.State.lastPhoneSlot, npcIndex, accept)
end

CreateThread(function()
    for index, cfg in ipairs(Config.NumberGivers) do
        local model = joaat(cfg.model)
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end

        local ped = CreatePed(4, model, cfg.coords.x, cfg.coords.y, cfg.coords.z - 1.0, cfg.coords.w, false, true)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        if cfg.scenario then
            TaskStartScenarioInPlace(ped, cfg.scenario, 0, true)
        end

        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    type = 'client',
                    icon = 'fas fa-check',
                    label = 'Accept',
                    action = function() respond(index, true) end,
                },
                {
                    type = 'client',
                    icon = 'fas fa-xmark',
                    label = 'Decline',
                    action = function() respond(index, false) end,
                },
            },
            distance = cfg.target.distance,
        })
    end
end)

RegisterNetEvent('ovi:client:numberGiverDeclined', function(reason)
    QBCore.Functions.Notify(reason, 'primary')
end)
