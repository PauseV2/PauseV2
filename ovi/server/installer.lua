-- ============================================================
-- OVI installation flow. PIN + alias are collected client side via
-- qb-input and sent here for validation + persistence.
-- ============================================================

if not Config.Toggle.OVIInstaller then return end

OVI.Cache.installerCooldown = OVI.Cache.installerCooldown or {}

local function cooldownKey(citizenid, installerIndex)
    return citizenid .. '_' .. installerIndex
end

RegisterNetEvent('ovi:server:installOVI', function(slot, installerIndex, pin, alias)
    local src = source
    local Player = OVI.GetPlayer(src)
    if not Player then return end

    local installerCfg = Config.Installers[installerIndex]
    if not installerCfg then return end

    local ped = GetPlayerPed(src)
    local dist = #(GetEntityCoords(ped) - vector3(installerCfg.coords.x, installerCfg.coords.y, installerCfg.coords.z))
    if dist > 5.0 then return end

    local key = cooldownKey(Player.PlayerData.citizenid, installerIndex)
    if OVI.Cache.installerCooldown[key] and OVI.Cache.installerCooldown[key] > os.time() then
        local remaining = math.ceil((OVI.Cache.installerCooldown[key] - os.time()) / 60)
        TriggerClientEvent('QBCore:Notify', src, ('This contact is laying low. Try again in %d min.'):format(remaining), 'error')
        return
    end

    local item = Player.Functions.GetItemBySlot(slot)
    if not item or not item.info or not item.info.imei then
        TriggerClientEvent('QBCore:Notify', src, 'You need a phone in hand for this.', 'error')
        return
    end

    local phoneCfg = Config.Phones[item.info.phoneType]
    if not phoneCfg or not phoneCfg.oviSupport then
        TriggerClientEvent('QBCore:Notify', src, 'This phone cannot run OVI.', 'error')
        return
    end

    if item.info.oviInstalled then
        TriggerClientEvent('QBCore:Notify', src, 'OVI is already installed on this device.', 'error')
        return
    end

    if installerCfg.requiredItem and not Player.Functions.GetItemByName(installerCfg.requiredItem) then
        TriggerClientEvent('QBCore:Notify', src, 'You are missing something this contact wants to see first.', 'error')
        return
    end

    pin = tostring(pin or '')
    if #pin ~= Config.Security.pinLength or not pin:match('^%d+$') then
        TriggerClientEvent('QBCore:Notify', src, ('PIN must be exactly %d digits.'):format(Config.Security.pinLength), 'error')
        return
    end

    alias = tostring(alias or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #alias < 2 or #alias > 24 then
        TriggerClientEvent('QBCore:Notify', src, 'Alias must be 2-24 characters.', 'error')
        return
    end

    if not Player.Functions.RemoveMoney('cash', installerCfg.price) then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough cash.', 'error')
        return
    end

    OVI.DB.InstallOVI(item.info.imei, pin, alias)

    local newInfo = item.info
    newInfo.pin = pin
    newInfo.alias = alias
    newInfo.oviInstalled = true
    OVI.PersistMetadata(src, slot, newInfo)

    OVI.Cache.installerCooldown[key] = os.time() + (installerCfg.cooldown * 60)

    TriggerClientEvent('QBCore:Notify', src, 'OVI installed. Welcome to the network.', 'success')
    TriggerClientEvent('ovi:client:installComplete', src, slot, newInfo)
end)
