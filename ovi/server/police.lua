-- ============================================================
-- Police evidence integration. Exposes exports for any police/MDT script
-- to call after a phone item has been physically seized from a player.
-- ============================================================

if not Config.Toggle.PoliceEvidence then return end

local Police = Config.Police

local function isAllowedJob(jobName)
    for _, allowed in ipairs(Police.allowedJobs) do
        if allowed == jobName then return true end
    end
    return false
end
exports('IsAllowedJob', isAllowedJob)

--- Seconds required to "decrypt" a given phone before evidence can be read.
--- export('ovi', 'GetDecryptTime')
local function getDecryptTime(imei)
    local row = OVI.DB.GetPhone(imei)
    if not row then return 0 end
    local phoneCfg = Config.Phones[row.phone_type]
    local level = phoneCfg and phoneCfg.encryption or 1
    return Police.decryptSeconds[level] or 30
end
exports('GetDecryptTime', getDecryptTime)

--- Full evidence dump for a seized phone. Call only after respecting
--- GetDecryptTime() if Config.Police.requireEncryptionBreak is true.
--- export('ovi', 'GetPhoneEvidence')
local function getPhoneEvidence(imei)
    local row = OVI.DB.GetPhone(imei)
    if not row then return nil end

    local evidence = { imei = imei, phoneNumber = row.phone_number, phoneType = row.phone_type }

    if Police.exposedData.alias then
        evidence.alias = row.alias
    end
    if Police.exposedData.contacts then
        evidence.contacts = OVI.DB.GetContactsForPhone(imei)
    end
    if Police.exposedData.messages then
        evidence.messages = OVI.DB.GetMessages(imei, 500)
    end
    if Police.exposedData.deliveries then
        evidence.deliveries = OVI.DB.GetDeliveries(imei, 200)
    end
    if Police.exposedData.gpsLogs then
        evidence.gpsLogs = OVI.DB.GetGPSLogs(imei, 100)
    end

    return evidence
end
exports('GetPhoneEvidence', getPhoneEvidence)

-- ----------------------------------------------------------- alert hook --
-- Generic best-effort dispatch hook. Wire this into your dispatch script
-- (ps-dispatch, cd_dispatch, qs-dispatch, etc.) by editing this handler.
RegisterNetEvent('ovi:server:notifyPolice', function(src, reason)
    local coords = GetEntityCoords(GetPlayerPed(src))
    local players = QBCore.Functions.GetQBPlayers()
    for _, Player in pairs(players) do
        if isAllowedJob(Player.PlayerData.job.name) and Player.PlayerData.job.onduty then
            TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, ('Suspicious activity reported (%s)'):format(reason), 'primary')
            TriggerClientEvent('ovi:client:policeBlip', Player.PlayerData.source, coords)
        end
    end
end)
