local QBCore = exports['qb-core']:GetCoreObject()

local tabletOpen = false

local function openTablet(accessData)
    if tabletOpen then return end
    tabletOpen = true

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        job = accessData.job,
        label = accessData.label,
        permissions = accessData.permissions,
    })
end

local function closeTablet()
    if not tabletOpen then return end
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ============================================================
-- Open triggers
-- ============================================================

RegisterCommand(Config.Command, function()
    if tabletOpen then return end

    QBCore.Functions.TriggerCallback('pv-govtablet:server:hasAccess', function(hasAccess, data)
        if not hasAccess then
            QBCore.Functions.Notify('You are not authorized to use this device.', 'error')
            return
        end
        openTablet(data)
    end)
end, false)

RegisterNetEvent('pv-govtablet:client:open', function(accessData)
    openTablet(accessData)
end)

-- ============================================================
-- NUI <-> server bridge
-- A small generic forwarder keeps this file short: the NUI posts
-- { args = [...] } to https://<resource>/<eventName> and gets the
-- matching server callback's result straight back. All permission
-- and validation is enforced server side regardless of what the
-- client sends.
-- ============================================================

local forwardableEvents = {
    'search',
    'getProfile',
    'freezeAccount',
    'setAccountHidden',
    'seizeFunds',
    'seizeVehicle',
    'releaseVehicle',
    'impoundVehicle',
    'releaseImpound',
    'seizeProperty',
    'restoreProperty',
    'addCriminalRecord',
    'getPendingApprovals',
    'resolveApproval',
    'setPhoto',
    'getLogs',
}

for _, evt in ipairs(forwardableEvents) do
    RegisterNUICallback(evt, function(data, cb)
        local args = data and data.args or {}
        QBCore.Functions.TriggerCallback('pv-govtablet:server:' .. evt, function(success, payload)
            cb({ success = success, data = payload })
        end, table.unpack(args))
    end)
end

RegisterNUICallback('close', function(_, cb)
    closeTablet()
    cb({})
end)

