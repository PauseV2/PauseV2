-- ============================================================
-- First-time phone setup wizard: access code (handed out by an installer
-- NPC) -> alias -> PIN. Nothing is written to ovi_phones until the PIN
-- step completes, mirroring the old single-shot OVI.DB.InstallOVI write.
-- ============================================================

if not Config.Toggle.OVIInstaller then return end

local function getOpenItem(src, slot)
    local Player = OVI.GetPlayer(src)
    if not Player then return nil end
    return Player.Functions.GetItemBySlot(slot)
end

RegisterNetEvent('ovi:server:submitAccessCode', function(slot, code)
    local src = source
    local item = getOpenItem(src, slot)
    if not item or not item.info or not item.info.imei then return end

    local phoneRow = OVI.DB.GetPhone(item.info.imei)
    if not phoneRow or not phoneRow.access_code then return end

    if tostring(phoneRow.access_code) ~= tostring(code) then
        TriggerClientEvent('ovi:client:setupStepResult', src, 'code', false)
        return
    end

    OVI.Cache.setupVerified[src] = true
    TriggerClientEvent('ovi:client:setupStepResult', src, 'code', true)
end)

RegisterNetEvent('ovi:server:submitAlias', function(slot, alias)
    local src = source
    if not OVI.Cache.setupVerified[src] then return end

    local item = getOpenItem(src, slot)
    if not item or not item.info or not item.info.imei then return end

    alias = tostring(alias or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #alias < 2 or #alias > 24 then
        TriggerClientEvent('ovi:client:setupStepResult', src, 'alias', false)
        return
    end

    OVI.Cache.setupAlias[src] = alias
    TriggerClientEvent('ovi:client:setupStepResult', src, 'alias', true)
end)

RegisterNetEvent('ovi:server:submitNewPin', function(slot, pin)
    local src = source
    if not OVI.Cache.setupVerified[src] then return end

    local alias = OVI.Cache.setupAlias[src]
    if not alias then return end

    local item = getOpenItem(src, slot)
    if not item or not item.info or not item.info.imei then return end

    pin = tostring(pin or '')
    if #pin ~= Config.Security.pinLength or not pin:match('^%d+$') then return end

    OVI.DB.InstallOVI(item.info.imei, pin, alias)

    local newInfo = item.info
    newInfo.pin = pin
    newInfo.alias = alias
    newInfo.oviInstalled = true
    OVI.PersistMetadata(src, slot, newInfo)

    OVI.Cache.setupVerified[src] = nil
    OVI.Cache.setupAlias[src] = nil

    TriggerClientEvent('QBCore:Notify', src, 'OVI installed. Welcome to the network.', 'success')
    TriggerClientEvent('ovi:client:pinResult', src, true, slot)
end)

AddEventHandler('playerDropped', function()
    local src = source
    OVI.Cache.setupVerified[src] = nil
    OVI.Cache.setupAlias[src] = nil
end)
