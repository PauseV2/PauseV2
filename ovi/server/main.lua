-- ============================================================
-- Bootstrap: framework handle, dynamic item registration, runtime caches.
-- ============================================================

QBCore = exports['qb-core']:GetCoreObject()

OVI = OVI or {}
OVI.Cache = {
    openPhone   = {},  -- [source] = imei (the phone a player currently has OVI open on)
    contacts    = {},  -- [imei] = { [contactId] = contactRow }  (hot cache, avoids re-querying every tab switch)
    deliveries  = {},  -- [imei] = { ... active deliveries }
    timers      = {},  -- [deliveryId] = { warned = {}, endsAt = number }
    pinLock     = {},  -- [imei] = lockedUntilEpoch
    imeiOwner   = {},  -- [imei] = source, best-effort index of who last used a given phone
    setupVerified = {}, -- [source] = true once the access code step passes, for the onboarding wizard
    setupAlias    = {}, -- [source] = alias chosen mid onboarding, persisted only once the PIN step completes
}

local function Log(msg)
    if Config.Debug then
        print(('[OVI] %s'):format(msg))
    end
end
OVI.Log = Log

-- ----------------------------------------------------- dynamic item reg --
-- Injects OVI items straight into QBCore.Shared.Items so a default qb-core
-- install does not need its shared/items.lua edited by hand.
CreateThread(function()
    for name, item in pairs(OVIItems) do
        if not QBCore.Shared.Items[name] then
            QBCore.Shared.Items[name] = item
            Log(('registered item %s into QBCore.Shared.Items'):format(name))
        end
    end
end)

-- ---------------------------------------------------------- player utils --

function OVI.GetPlayer(source)
    return QBCore.Functions.GetPlayer(source)
end

function OVI.GetOpenImei(source)
    return OVI.Cache.openPhone[source]
end

function OVI.SetOpenImei(source, imei)
    OVI.Cache.openPhone[source] = imei
end

AddEventHandler('playerDropped', function()
    local src = source
    OVI.Cache.openPhone[src] = nil
end)

RegisterNetEvent('ovi:server:closePhone', function()
    local src = source
    OVI.Cache.openPhone[src] = nil
end)
