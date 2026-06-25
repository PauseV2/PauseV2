-- ============================================================
-- Physical phone item lifecycle. The item's qb-inventory metadata only
-- ever holds small identity fields (imei, number, pin, alias, oviInstalled,
-- phoneType, durability) - everything else lives in the DB keyed by imei.
-- Dropping/picking up a phone is handled entirely by qb-inventory's native
-- ground item system, which already preserves metadata; we never touch it.
-- ============================================================

if not Config.Toggle.Phones then return end

--- Builds a brand new, DB-backed identity and returns the metadata table
--- that should be written onto the item when it's added to an inventory.
function OVI.CreatePhoneIdentity(phoneType, citizenid)
    local imei, number

    repeat
        imei = OVI.GenerateIMEI()
    until not OVI.DB.GetPhone(imei)

    repeat
        number = OVI.GeneratePhoneNumber()
    until not OVI.DB.GetPhoneByNumber(number)

    OVI.DB.CreatePhone(imei, number, phoneType, citizenid)

    return {
        imei        = imei,
        number      = number,
        phoneType   = phoneType,
        pin         = nil,
        alias       = nil,
        oviInstalled = false,
        durability  = 100,
    }
end

--- Adds a phone item with a freshly generated identity straight to a
--- player's inventory. Call this from your shop / NPC vendor scripts.
--- export('ovi', 'GivePhoneItem')
local function GivePhoneItem(source, phoneType)
    local phoneCfg = Config.Phones[phoneType]
    if not phoneCfg then return false, 'invalid phone type' end

    local Player = OVI.GetPlayer(source)
    if not Player then return false end

    local metadata = OVI.CreatePhoneIdentity(phoneType, Player.PlayerData.citizenid)
    local added = Player.Functions.AddItem(phoneCfg.shopItem, 1, false, metadata)
    if added then
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[phoneCfg.shopItem], 'add')
    end
    return added
end
exports('GivePhoneItem', GivePhoneItem)

--- Persists updated identity fields back onto the physical item.
--- qb-inventory exposes SetItemMetadata in modern builds; we fall back
--- silently if a particular fork doesn't have it - the DB row (source of
--- truth for everything except the small identity fields) is unaffected.
function OVI.PersistMetadata(source, slot, metadata)
    local ok = pcall(function()
        exports['qb-inventory']:SetItemMetadata(source, slot, metadata)
    end)
    if not ok then
        TriggerClientEvent('ovi:client:syncSlotMetadata', source, slot, metadata)
    end
end

local function findPhoneItemBySlot(source, slot)
    local Player = OVI.GetPlayer(source)
    if not Player then return nil end
    return Player.Functions.GetItemBySlot(slot)
end

-- ---------------------------------------------------------- useable items --

local function onUsePhone(source, item)
    local Player = OVI.GetPlayer(source)
    if not Player then return end

    local info = item.info or {}
    if not info.imei then
        -- lazily back-fill identity for phones that existed before metadata was set
        info = OVI.CreatePhoneIdentity(item.name, Player.PlayerData.citizenid)
        OVI.PersistMetadata(source, item.slot, info)
    end

    local phoneRow = OVI.DB.GetPhone(info.imei)
    if not phoneRow or phoneRow.wiped == 1 then
        TriggerClientEvent('QBCore:Notify', source, 'This phone is dead.', 'error')
        return
    end

    OVI.Cache.imeiOwner[info.imei] = source

    TriggerClientEvent('ovi:client:onUsePhone', source, item.slot, info, phoneRow)
end

CreateThread(function()
    for itemName in pairs(Config.Phones) do
        QBCore.Functions.CreateUseableItem(itemName, onUsePhone)
    end
end)

-- ------------------------------------------------------- dashboard fetch --

--- Called by the client once a PIN check (or no-PIN-needed) succeeds, to
--- pull everything the NUI app needs for its tabs in one shot.
RegisterNetEvent('ovi:server:requestDashboard', function(slot)
    local src = source
    local Player = OVI.GetPlayer(src)
    if not Player then return end

    local item = Player.Functions.GetItemBySlot(slot)
    if not item or not item.info or not item.info.imei then return end
    local imei = item.info.imei

    local phoneRow = OVI.DB.GetPhone(imei)
    if not phoneRow or not phoneRow.ovi_installed or phoneRow.ovi_installed == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'OVI is not installed on this device.', 'error')
        return
    end

    OVI.SetOpenImei(src, imei)

    local contacts = OVI.DB.GetContactsForPhone(imei)
    local messages = OVI.DB.GetMessages(imei, 200)
    local deliveries = OVI.DB.GetDeliveries(imei, 100)
    local notes = OVI.DB.GetNotes(imei)
    local gpsLogs = OVI.DB.GetGPSLogs(imei, 50)

    TriggerClientEvent('ovi:client:openDashboard', src, {
        phone = phoneRow,
        contacts = contacts,
        messages = messages,
        deliveries = deliveries,
        notes = notes,
        gpsLogs = gpsLogs,
        networkRaided = Config.Toggle.NetworkStatus and OVI.IsNetworkRaided() or false,
        config = {
            ui = Config.UI,
            phoneCfg = Config.Phones[phoneRow.phone_type],
            network = Config.NetworkStatus,
        },
    })
end)

-- ------------------------------------------------------------------ notes --

RegisterNetEvent('ovi:server:addNote', function(text)
    local src = source
    local imei = OVI.GetOpenImei(src)
    if not imei then return end

    text = tostring(text or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #text < 1 or #text > 280 then return end

    OVI.DB.AddNote(imei, text)
    TriggerClientEvent('ovi:client:pushUpdate', src, { type = 'noteAdded', text = text })
end)

OVI.GivePhoneItem = GivePhoneItem
OVI.FindPhoneItemBySlot = findPhoneItemBySlot
