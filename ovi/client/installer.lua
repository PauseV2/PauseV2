-- ============================================================
-- OVI installer NPCs. Spawns each entry from config/installers.lua,
-- collects a PIN + alias via qb-input, and hands the rest to the server
-- for validation (distance, price, cooldown are all re-checked there).
-- ============================================================

if not Config.Toggle.OVIInstaller then return end

local function promptInstall(installerIndex, installerCfg)
    if not OVI.State.lastPhoneSlot then
        QBCore.Functions.Notify('You need an OVI-capable phone in hand first.', 'error')
        return
    end

    local input = exports['qb-input']:ShowInput({
        header = installerCfg.label,
        submitText = 'Install',
        inputs = {
            { type = 'number', name = 'pin', text = ('%d-digit PIN'):format(Config.Security.pinLength), isRequired = true },
            { type = 'text', name = 'alias', text = 'Alias (2-24 chars)', isRequired = true },
        },
    })
    if not input or not input.pin or not input.alias then return end

    TriggerServerEvent('ovi:server:installOVI', OVI.State.lastPhoneSlot, installerIndex, tostring(input.pin), input.alias)
end

CreateThread(function()
    for index, installerCfg in ipairs(Config.Installers) do
        local model = joaat(installerCfg.model)
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end

        local ped = CreatePed(4, model, installerCfg.coords.x, installerCfg.coords.y, installerCfg.coords.z - 1.0, installerCfg.coords.w, false, true)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        if installerCfg.scenario then
            TaskStartScenarioInPlace(ped, installerCfg.scenario, 0, true)
        end

        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    type = 'client',
                    icon = installerCfg.target.icon,
                    label = installerCfg.target.label,
                    action = function() promptInstall(index, installerCfg) end,
                },
            },
            distance = installerCfg.target.distance,
        })
    end
end)

RegisterNetEvent('ovi:client:installComplete', function(slot, newInfo)
    OVI.State.lastPhoneSlot = slot
    OVI.State.lastPhoneImei = newInfo.imei
end)
