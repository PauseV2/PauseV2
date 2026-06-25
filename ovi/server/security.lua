-- ============================================================
-- PIN verification, lockouts and self-wipe / GPS beacon / police ping.
-- ============================================================

if not Config.Toggle.Security then return end

local Security = Config.Security

local function isLocked(phoneRow)
    return phoneRow.locked_until and phoneRow.locked_until > os.time()
end

local function triggerWipe(imei, src)
    if not OVI.Chance(Config.Phones[OVI.DB.GetPhone(imei).phone_type].wipeChance) then
        return false
    end

    OVI.DB.WipePhone(imei)

    if Security.gpsBeaconOnWipe then
        TriggerClientEvent('ovi:client:reportWipeBeacon', src, imei)
    end

    return true
end
OVI.TriggerWipe = triggerWipe

RegisterNetEvent('ovi:server:verifyPin', function(slot, enteredPin)
    local src = source
    local Player = OVI.GetPlayer(src)
    if not Player then return end

    local item = Player.Functions.GetItemBySlot(slot)
    if not item or not item.info or not item.info.imei then return end
    local imei = item.info.imei

    local phoneRow = OVI.DB.GetPhone(imei)
    if not phoneRow then return end

    if isLocked(phoneRow) then
        local remaining = phoneRow.locked_until - os.time()
        TriggerClientEvent('QBCore:Notify', src, ('Device locked. Try again in %ds.'):format(remaining), 'error')
        TriggerClientEvent('ovi:client:pinResult', src, false, slot)
        return
    end

    if tostring(phoneRow.pin) == tostring(enteredPin) then
        OVI.DB.SetPinAttempts(imei, 0, 0)
        TriggerClientEvent('ovi:client:pinResult', src, true, slot)
        return
    end

    -- wrong pin
    local attempts = (phoneRow.pin_attempts or 0) + 1
    OVI.Log(('wrong pin attempt %d/%d on imei %s'):format(attempts, Security.maxPinAttempts, imei))

    if OVI.Chance(Security.policePingChance) then
        TriggerEvent('ovi:server:policePing', imei, src, 'wrong pin attempt')
    end

    if attempts >= Security.maxPinAttempts then
        local lockedUntil = os.time() + Security.lockoutTime
        OVI.DB.SetPinAttempts(imei, 0, lockedUntil)

        TriggerClientEvent('QBCore:Notify', src, 'Too many wrong attempts. Device locked.', 'error')

        if Security.selfWipeOnLockout then
            local wiped = triggerWipe(imei, src)
            if wiped then
                TriggerClientEvent('QBCore:Notify', src, 'SELF-WIPE TRIGGERED. Data destroyed.', 'error')
            end
        end
    else
        OVI.DB.SetPinAttempts(imei, attempts, 0)
        TriggerClientEvent('QBCore:Notify', src, ('Wrong PIN (%d/%d).'):format(attempts, Security.maxPinAttempts), 'error')
    end

    TriggerClientEvent('ovi:client:pinResult', src, false, slot)
end)

--- Manual self-destruct from the OVI app's "Burn Device" tab - unlike the
--- lockout self-wipe this is unconditional, the player is choosing it.
RegisterNetEvent('ovi:server:burnDevice', function()
    local src = source
    local imei = OVI.GetOpenImei(src)
    if not imei then return end

    OVI.DB.WipePhone(imei)
    OVI.SetOpenImei(src, nil)

    if Security.gpsBeaconOnWipe then
        TriggerClientEvent('ovi:client:reportWipeBeacon', src, imei)
    end

    TriggerClientEvent('QBCore:Notify', src, 'Device burned. All data destroyed.', 'success')
    TriggerClientEvent('ovi:client:deviceBurned', src)
end)

-- Hook point for police scripts / heat system. Defined here so it always
-- exists even if server/police.lua's toggle is off.
RegisterNetEvent('ovi:server:policePing', function(imei, src, reason)
    OVI.Log(('police ping for imei %s (%s)'):format(imei, reason))
    if Config.Toggle.Heat then
        TriggerEvent('ovi:server:addHeat', imei, Config.Heat.increments.policeSighting, reason)
    end
    TriggerEvent('ovi:server:notifyPolice', src, reason)
end)
