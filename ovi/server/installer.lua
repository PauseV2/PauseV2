-- ============================================================
-- OVI installation flow. The NPC no longer collects a PIN/alias directly -
-- it hands out a one-time access code which the player then enters on the
-- phone itself, followed by alias + PIN creation (see server/setup.lua).
-- ============================================================

if not Config.Toggle.OVIInstaller then return end

OVI.Cache.installerCooldown = OVI.Cache.installerCooldown or {}

local function cooldownKey(citizenid, installerIndex)
    return citizenid .. '_' .. installerIndex
end

RegisterNetEvent('ovi:server:installOVI', function(slot, installerIndex)
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

    if not Player.Functions.RemoveMoney('cash', installerCfg.price) then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough cash.', 'error')
        return
    end

    local code = OVI.GenerateAccessCode(Config.Security.accessCodeLength)
    OVI.DB.GiveAccessCode(item.info.imei, code)

    OVI.Cache.installerCooldown[key] = os.time() + (installerCfg.cooldown * 60)

    TriggerClientEvent('QBCore:Notify', src, 'Access code sent. Use your phone to finish setup.', 'success')
    TriggerClientEvent('ovi:client:accessCodeIssued', src, code)
end)
