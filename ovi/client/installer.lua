-- ============================================================
-- OVI installer NPCs. Spawns each entry from config/installers.lua and
-- hands out a one-time access code for the player's phone (distance,
-- price, cooldown are all re-checked server side). The player finishes
-- setup - access code, alias, PIN - on the phone itself, see html/app.js
-- and server/setup.lua.
-- ============================================================

if not Config.Toggle.OVIInstaller then return end

local function promptInstall(installerIndex, installerCfg)
    if not OVI.State.lastPhoneSlot then
        QBCore.Functions.Notify('You need an OVI-capable phone in hand first.', 'error')
        return
    end

    TriggerServerEvent('ovi:server:installOVI', OVI.State.lastPhoneSlot, installerIndex)
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

RegisterNetEvent('ovi:client:accessCodeIssued', function(code)
    TriggerEvent('chat:addMessage', {
        color = { 39, 174, 96 },
        multiline = true,
        args = { 'Unknown Number', ('Access code: %s'):format(code) },
    })
end)
