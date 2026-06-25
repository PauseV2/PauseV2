-- ============================================================
-- Phone cloning: backup a phone's data, recover it, or migrate it onto
-- a new physical phone.
-- ============================================================

if not Config.Toggle.Cloning then return end

local Cloning = Config.Cloning
OVI.Cache.cloneCooldown = OVI.Cache.cloneCooldown or {}

local function onCooldown(citizenid)
    local until_ = OVI.Cache.cloneCooldown[citizenid]
    return until_ and until_ > os.time()
end

local function setCooldown(citizenid)
    OVI.Cache.cloneCooldown[citizenid] = os.time() + (Cloning.cooldownMinutes * 60)
end

local function getPhoneFromSlot(Player, slot)
    local item = Player.Functions.GetItemBySlot(slot)
    if not item or not item.info or not item.info.imei then return nil end
    return item, item.info.imei
end

RegisterNetEvent('ovi:server:cloneBackup', function(slot)
    local src = source
    local Player = OVI.GetPlayer(src)
    if not Player or onCooldown(Player.PlayerData.citizenid) then return end

    local _, imei = getPhoneFromSlot(Player, slot)
    if not imei then return end

    if OVI.DB.CountClonesForPhone(imei) >= Cloning.maxBackupsPerPhone then
        TriggerClientEvent('QBCore:Notify', src, 'This phone already has the maximum number of backups.', 'error')
        return
    end

    if not Player.Functions.RemoveMoney('cash', Cloning.backupPrice) then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough cash.', 'error')
        return
    end

    local snapshot = {
        contacts = OVI.DB.GetContactsForPhone(imei),
        messages = OVI.DB.GetMessages(imei, 1000),
        deliveries = OVI.DB.GetDeliveries(imei, 500),
        notes = OVI.DB.GetNotes(imei),
        gpsLogs = OVI.DB.GetGPSLogs(imei, 200),
    }

    OVI.DB.AddClone(imei, json.encode(snapshot), Player.PlayerData.citizenid)
    setCooldown(Player.PlayerData.citizenid)
    TriggerClientEvent('QBCore:Notify', src, 'Backup created.', 'success')
end)

RegisterNetEvent('ovi:server:cloneRecover', function(slot)
    local src = source
    local Player = OVI.GetPlayer(src)
    if not Player or onCooldown(Player.PlayerData.citizenid) then return end

    local _, imei = getPhoneFromSlot(Player, slot)
    if not imei then return end

    local clones = OVI.DB.GetClonesForPhone(imei)
    if #clones == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'No backups found for this device.', 'error')
        return
    end

    if not Player.Functions.RemoveMoney('cash', Cloning.recoveryPrice) then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough cash.', 'error')
        return
    end

    local snapshot = json.decode(clones[1].backup_data)

    for _, contact in ipairs(snapshot.contacts) do
        if not OVI.DB.GetPhoneContact(imei, contact.contact_id) then
            OVI.DB.AddPhoneContact(imei, contact.contact_id, contact.trust, contact.loyalty)
        end
    end
    for _, message in ipairs(snapshot.messages) do
        OVI.DB.AddMessage(imei, message.contact_id, message.sender, message.message, message.hidden == 1)
    end
    for _, note in ipairs(snapshot.notes) do
        OVI.DB.AddNote(imei, note.text)
    end

    setCooldown(Player.PlayerData.citizenid)
    TriggerClientEvent('QBCore:Notify', src, 'Backup restored.', 'success')
end)

RegisterNetEvent('ovi:server:cloneMigrate', function(sourceSlot, targetSlot)
    local src = source
    local Player = OVI.GetPlayer(src)
    if not Player or onCooldown(Player.PlayerData.citizenid) then return end

    local sourceItem, sourceImei = getPhoneFromSlot(Player, sourceSlot)
    local targetItem, targetImei = getPhoneFromSlot(Player, targetSlot)
    if not sourceImei or not targetImei or sourceImei == targetImei then return end

    local sourceRow = OVI.DB.GetPhone(sourceImei)
    if not sourceRow or sourceRow.ovi_installed == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Source device has no OVI install to migrate.', 'error')
        return
    end

    if not Player.Functions.RemoveMoney('cash', Cloning.migratePrice) then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough cash.', 'error')
        return
    end

    OVI.DB.MigratePhoneData(sourceImei, targetImei)
    OVI.DB.InstallOVI(targetImei, sourceRow.pin, sourceRow.alias)
    OVI.DB.WipePhone(sourceImei)

    local newTargetInfo = {
        imei = targetImei,
        number = targetItem.info.number,
        phoneType = targetItem.info.phoneType,
        pin = sourceRow.pin,
        alias = sourceRow.alias,
        oviInstalled = true,
        durability = targetItem.info.durability or 100,
    }
    OVI.PersistMetadata(src, targetSlot, newTargetInfo)

    TriggerClientEvent('QBCore:Notify', src, 'Identity migrated to new device.', 'success')
end)
