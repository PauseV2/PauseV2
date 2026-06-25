-- ============================================================
-- NUI plumbing + the physical phone item's PIN/boot/dashboard flow.
-- Every other client file reaches into OVI.State for the slot/imei of
-- whichever phone the player last interacted with (used by the installer,
-- cloning and street sale flows so they don't need their own item picker).
-- ============================================================

QBCore = exports['qb-core']:GetCoreObject()

OVI = OVI or {}
OVI.State = {
    open = false,
    slot = nil,
    imei = nil,
    lastPhoneSlot = nil,
    lastPhoneImei = nil,
}

local function openNui()
    OVI.State.open = true
    SetNuiFocus(true, true)
end

local function closeNui()
    if not OVI.State.open then return end
    OVI.State.open = false
    SetNuiFocus(false, false)
    TriggerServerEvent('ovi:server:closePhone')
end

RegisterCommand(Config.OpenCommand, function()
    if OVI.State.open then
        closeNui()
        return
    end
    if not OVI.State.lastPhoneSlot then
        QBCore.Functions.Notify('Use an OVI-capable phone first.', 'error')
        return
    end
    TriggerServerEvent('ovi:server:requestDashboard', OVI.State.lastPhoneSlot)
end, false)

RegisterNUICallback('close', function(_, cb)
    closeNui()
    cb('ok')
end)

RegisterNUICallback('submitPin', function(data, cb)
    if OVI.State.lastPhoneSlot then
        TriggerServerEvent('ovi:server:verifyPin', OVI.State.lastPhoneSlot, data.pin)
    end
    cb('ok')
end)

RegisterNUICallback('addNote', function(data, cb)
    TriggerServerEvent('ovi:server:addNote', data.text)
    cb('ok')
end)

RegisterNUICallback('requestRefresh', function(_, cb)
    if OVI.State.lastPhoneSlot then
        TriggerServerEvent('ovi:server:requestDashboard', OVI.State.lastPhoneSlot)
    end
    cb('ok')
end)

RegisterNUICallback('burnDevice', function(_, cb)
    TriggerServerEvent('ovi:server:burnDevice')
    cb('ok')
end)

RegisterNetEvent('ovi:client:deviceBurned', function()
    closeNui()
end)

RegisterNetEvent('ovi:client:onUsePhone', function(slot, info, phoneRow)
    OVI.State.lastPhoneSlot = slot
    OVI.State.lastPhoneImei = info.imei

    if phoneRow.ovi_installed ~= 1 then
        QBCore.Functions.Notify('No OVI install on this device. Find an installer.', 'primary')
        return
    end

    openNui()
    SendNUIMessage({
        action = 'showPin',
        config = Config.UI,
        pinLength = Config.Security.pinLength,
    })
end)

RegisterNetEvent('ovi:client:pinResult', function(success, slot)
    if slot ~= OVI.State.lastPhoneSlot then return end

    if success then
        TriggerServerEvent('ovi:server:requestDashboard', slot)
    else
        SendNUIMessage({ action = 'pinError' })
    end
end)

RegisterNetEvent('ovi:client:openDashboard', function(data)
    OVI.State.slot = OVI.State.lastPhoneSlot
    OVI.State.imei = data.phone.imei

    if not OVI.State.open then openNui() end

    SendNUIMessage({
        action = 'boot',
        bootLines = data.config.ui.bootLines,
        bootLoadingTimeMs = data.config.ui.bootLoadingTimeMs,
    })

    SetTimeout(data.config.ui.bootLoadingTimeMs, function()
        SendNUIMessage({ action = 'dashboard', data = data })
    end)
end)

RegisterNetEvent('ovi:client:pushUpdate', function(payload)
    SendNUIMessage({ action = 'pushUpdate', payload = payload })
end)

RegisterNetEvent('ovi:client:syncSlotMetadata', function(slot, metadata)
    -- best-effort fallback for qb-inventory forks without SetItemMetadata;
    -- the DB row is already the source of truth, this only keeps the
    -- client-rendered inventory slot from looking stale.
    TriggerEvent('inventory:client:UpdateSlotMetadata', slot, metadata)
end)

RegisterNetEvent('ovi:client:reportWipeBeacon', function(imei)
    QBCore.Functions.Notify('Device wiped. Last known location was just pinged.', 'error')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if OVI.State.open then closeNui() end
end)
