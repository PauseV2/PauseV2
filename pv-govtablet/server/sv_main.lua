local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
-- Permission helpers - the ONLY source of truth for what an
-- action is allowed to do. The NUI/client may hide buttons for
-- UX, but every single mutation is re-checked here.
-- ============================================================

local actionRateLimit = {} -- src -> { count, resetAt }
local searchCooldown = {}  -- src -> last search timestamp

local function getOfficialContext(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end

    local jobName = Player.PlayerData.job.name
    local grade = Player.PlayerData.job.grade.level
    local jobCfg = Config.Jobs[jobName]
    if not jobCfg then return nil end
    if grade < jobCfg.minGrade then return nil end

    return {
        Player = Player,
        jobCfg = jobCfg,
        citizenid = Player.PlayerData.citizenid,
        name = ('%s %s'):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname),
        job = jobName,
    }
end

local function hasPermission(official, action)
    if not official then return false end
    return official.jobCfg.permissions[action] == true
end

-- Simple sliding-window rate limit to blunt event spam / exploit attempts.
local function isRateLimited(src)
    local now = GetGameTimer()
    local entry = actionRateLimit[src]

    if not entry or now > entry.resetAt then
        actionRateLimit[src] = { count = 1, resetAt = now + 60000 }
        return false
    end

    entry.count = entry.count + 1
    if entry.count > Config.MaxActionsPerMinute then
        return true
    end
    return false
end

AddEventHandler('playerDropped', function()
    local src = source
    actionRateLimit[src] = nil
    searchCooldown[src] = nil
end)

-- ============================================================
-- Access check
-- ============================================================

QBCore.Functions.CreateCallback('pv-govtablet:server:hasAccess', function(source, cb)
    local official = getOfficialContext(source)
    if not official then return cb(false) end

    cb(true, {
        job = official.job,
        label = official.jobCfg.label,
        permissions = official.jobCfg.permissions,
    })
end)

-- ============================================================
-- Search
-- ============================================================

local function buildProfileSummary(row)
    local charinfo = {}
    if row.charinfo then
        local ok, decoded = pcall(json.decode, row.charinfo)
        if ok then charinfo = decoded end
    end

    return {
        citizenid = row.citizenid,
        name = ('%s %s'):format(charinfo.firstname or '?', charinfo.lastname or '?'),
        phone = charinfo.phone or 'N/A',
    }
end

QBCore.Functions.CreateCallback('pv-govtablet:server:search', function(source, cb, query, searchType)
    local official = getOfficialContext(source)
    if not official or not hasPermission(official, 'search') then return cb(false, 'no_permission') end

    local now = GetGameTimer()
    if searchCooldown[source] and (now - searchCooldown[source]) < Config.SearchCooldown then
        return cb(false, 'rate_limited')
    end
    searchCooldown[source] = now

    query = Utils.SanitizeString(query, 60)
    if not query then return cb(false, 'invalid_query') end

    local validTypes = { name = true, citizenid = true, phone = true, plate = true }
    if not validTypes[searchType] then return cb(false, 'invalid_type') end

    local results = {}

    if searchType == 'citizenid' then
        local rows = MySQL.query.await('SELECT citizenid, charinfo FROM players WHERE citizenid LIKE ? LIMIT ?', { '%' .. query .. '%', Config.SearchResultLimit })
        for _, row in ipairs(rows or {}) do results[#results + 1] = buildProfileSummary(row) end

    elseif searchType == 'name' then
        local rows = MySQL.query.await([[
            SELECT citizenid, charinfo FROM players
            WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ?
               OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ?
            LIMIT ?
        ]], { '%' .. query .. '%', '%' .. query .. '%', Config.SearchResultLimit })
        for _, row in ipairs(rows or {}) do results[#results + 1] = buildProfileSummary(row) end

    elseif searchType == 'phone' then
        local rows = MySQL.query.await([[
            SELECT citizenid, charinfo FROM players
            WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.phone')) LIKE ?
            LIMIT ?
        ]], { '%' .. query .. '%', Config.SearchResultLimit })
        for _, row in ipairs(rows or {}) do results[#results + 1] = buildProfileSummary(row) end

    elseif searchType == 'plate' then
        if not Utils.IsValidPlate(query) then return cb(false, 'invalid_plate') end
        local cfg = Config.Bridge.Garage
        local rows = MySQL.query.await(('SELECT `%s` as citizenid FROM `%s` WHERE `%s` LIKE ? LIMIT ?')
            :format(cfg.CitizenField, cfg.VehicleTable, cfg.PlateField), { '%' .. query .. '%', Config.SearchResultLimit })

        for _, row in ipairs(rows or {}) do
            local prow = MySQL.single.await('SELECT citizenid, charinfo FROM players WHERE citizenid = ?', { row.citizenid })
            if prow then results[#results + 1] = buildProfileSummary(prow) end
        end
    end

    Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, 'search', nil, ('%s search: "%s"'):format(searchType, query))

    cb(true, results)
end)

-- ============================================================
-- Profile assembly
-- ============================================================

QBCore.Functions.CreateCallback('pv-govtablet:server:getProfile', function(source, cb, citizenid)
    local official = getOfficialContext(source)
    if not official or not hasPermission(official, 'viewProfile') then return cb(false, 'no_permission') end
    if not Utils.IsValidCitizenId(citizenid) then return cb(false, 'invalid_citizenid') end

    local row = MySQL.single.await('SELECT * FROM players WHERE citizenid = ?', { citizenid })
    if not row then return cb(false, 'not_found') end

    local ok, charinfo = pcall(json.decode, row.charinfo or '{}')
    charinfo = ok and charinfo or {}
    local jobOk, jobData = pcall(json.decode, row.job or '{}')
    jobData = jobOk and jobData or {}

    local photoRow = MySQL.single.await('SELECT photo_url FROM gt_citizen_photos WHERE citizenid = ?', { citizenid })

    local profile = {
        citizenid = citizenid,
        photo = photoRow and photoRow.photo_url or nil,
        name = ('%s %s'):format(charinfo.firstname or '?', charinfo.lastname or '?'),
        dob = charinfo.birthdate or 'Unknown',
        gender = charinfo.gender or 'Unknown',
        nationality = charinfo.nationality or 'Unknown',
        phone = charinfo.phone or 'N/A',
        job = jobData.label or jobData.name or 'Unemployed',
    }

    if hasPermission(official, 'viewFinance') then
        profile.finance = Banking.GetBalances(citizenid)
    end

    if hasPermission(official, 'viewAssets') then
        profile.properties = Housing.GetProperties(citizenid)
        profile.vehicles = Garage.GetVehicles(citizenid)
    end

    if hasPermission(official, 'viewCriminal') then
        profile.criminalRecords = Police.GetRecords(citizenid)
    end

    Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, 'view_profile', citizenid)

    cb(true, profile)
end)

-- ============================================================
-- Generic write-action wrapper: permission + rate-limit check,
-- then dispatch, log, and respond.
-- ============================================================

local function guardedAction(source, action, citizenid)
    local official = getOfficialContext(source)
    if not official then return nil, 'no_permission' end
    if not hasPermission(official, action) then return nil, 'no_permission' end
    if isRateLimited(source) then return nil, 'rate_limited' end
    if citizenid and not Utils.IsValidCitizenId(citizenid) then return nil, 'invalid_citizenid' end

    return official
end

-- ============================================================
-- Financial actions
-- ============================================================

QBCore.Functions.CreateCallback('pv-govtablet:server:freezeAccount', function(source, cb, citizenid, accountType, reason, freeze)
    local official, err = guardedAction(source, freeze and 'freeze' or 'unfreeze', citizenid)
    if not official then return cb(false, err) end
    if not Utils.IsValidMoneyType(accountType) then return cb(false, 'invalid_account') end

    reason = Utils.SanitizeString(reason, 255) or 'No reason provided'

    Banking.SetFrozen(citizenid, accountType, freeze, reason, official.name)
    Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, freeze and 'freeze' or 'unfreeze', citizenid, ('%s account: %s'):format(accountType, reason))

    cb(true)
end)

QBCore.Functions.CreateCallback('pv-govtablet:server:setAccountHidden', function(source, cb, citizenid, accountType, hidden)
    local official, err = guardedAction(source, hidden and 'hide' or 'reveal', citizenid)
    if not official then return cb(false, err) end
    if not Utils.IsValidMoneyType(accountType) then return cb(false, 'invalid_account') end

    Banking.SetHidden(citizenid, accountType, hidden, official.name)
    Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, hidden and 'hide' or 'reveal', citizenid, accountType .. ' account')

    cb(true)
end)

local function executeSeizeFunds(citizenid, accountType, amount, reason, official)
    amount = Utils.Round(amount)
    local success, err = Banking.SeizeFunds(citizenid, accountType, amount, reason, official.name)
    if success then
        Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, 'seize_funds', citizenid, ('Seized $%d from %s: %s'):format(amount, accountType, reason))
    end
    return success, err
end

local function executeSeizeVehicle(plate, reason, official)
    local success, err = Garage.SeizeVehicle(plate, reason, official.name)
    if success then
        Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, 'seize_vehicle', nil, ('Flagged vehicle %s for seizure: %s'):format(plate, reason))
    end
    return success, err
end

local function executeSeizeProperty(citizenid, house, reason, official)
    local success, err = Housing.SeizeProperty(citizenid, house, reason, official.name)
    if success then
        Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, 'seize_property', citizenid, ('Seized property %s: %s'):format(house, reason))
    end
    return success, err
end

-- ============================================================
-- Judge-approval queue
-- ============================================================

local function requiresApproval(official)
    return Config.RequireJudgeApproval and not hasPermission(official, 'approveSeizure')
end

local function queueApproval(official, requestType, citizenid, payload, reason)
    MySQL.insert.await([[
        INSERT INTO gt_seizure_requests (type, citizenid, payload, reason, requested_by, requested_by_name)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { requestType, citizenid, json.encode(payload), reason, official.citizenid, official.name })

    Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, 'request_seizure', citizenid, ('Requested %s seizure approval: %s'):format(requestType, reason))

    -- notify any online judge with approve permission
    local players = QBCore.Functions.GetQBPlayers()
    for _, Player in pairs(players) do
        local jobCfg = Config.Jobs[Player.PlayerData.job.name]
        if jobCfg and jobCfg.permissions.approveSeizure then
            TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, 'New seizure request pending approval', 'primary')
        end
    end
end

QBCore.Functions.CreateCallback('pv-govtablet:server:seizeFunds', function(source, cb, citizenid, accountType, amount, reason)
    local official, err = guardedAction(source, 'seizeFunds', citizenid)
    if not official then return cb(false, err) end
    if not Utils.IsValidMoneyType(accountType) then return cb(false, 'invalid_account') end
    if not Utils.IsPositiveNumber(amount) then return cb(false, 'invalid_amount') end
    reason = Utils.SanitizeString(reason, 255) or 'No reason provided'

    if requiresApproval(official) then
        queueApproval(official, 'funds', citizenid, { accountType = accountType, amount = Utils.Round(amount) }, reason)
        return cb(true, 'pending_approval')
    end

    local success, sErr = executeSeizeFunds(citizenid, accountType, amount, reason, official)
    cb(success, sErr)
end)

QBCore.Functions.CreateCallback('pv-govtablet:server:seizeVehicle', function(source, cb, plate, reason)
    local official, err = guardedAction(source, 'seizeVehicle')
    if not official then return cb(false, err) end
    if not Utils.IsValidPlate(plate) then return cb(false, 'invalid_plate') end
    reason = Utils.SanitizeString(reason, 255) or 'No reason provided'

    if requiresApproval(official) then
        local ownerCitizenId = Garage.GetOwnerCitizenId(plate) or official.citizenid
        queueApproval(official, 'vehicle', ownerCitizenId, { plate = plate }, reason)
        return cb(true, 'pending_approval')
    end

    local success, sErr = executeSeizeVehicle(plate, reason, official)
    cb(success, sErr)
end)

QBCore.Functions.CreateCallback('pv-govtablet:server:releaseVehicle', function(source, cb, plate)
    local official, err = guardedAction(source, 'releaseVehicle')
    if not official then return cb(false, err) end
    if not Utils.IsValidPlate(plate) then return cb(false, 'invalid_plate') end

    local success, sErr = Garage.ReleaseVehicle(plate, official.name)
    if success then
        Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, 'release_vehicle', nil, plate)
    end
    cb(success, sErr)
end)

QBCore.Functions.CreateCallback('pv-govtablet:server:impoundVehicle', function(source, cb, plate, reason)
    local official, err = guardedAction(source, 'impoundVehicle')
    if not official then return cb(false, err) end
    if not Utils.IsValidPlate(plate) then return cb(false, 'invalid_plate') end
    reason = Utils.SanitizeString(reason, 255) or 'No reason provided'

    local success, sErr = Garage.ImpoundVehicle(plate, reason, official.name)
    if success then
        Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, 'impound_vehicle', nil, ('%s: %s'):format(plate, reason))
    end
    cb(success, sErr)
end)

QBCore.Functions.CreateCallback('pv-govtablet:server:releaseImpound', function(source, cb, plate)
    local official, err = guardedAction(source, 'impoundVehicle')
    if not official then return cb(false, err) end
    if not Utils.IsValidPlate(plate) then return cb(false, 'invalid_plate') end

    local success, sErr = Garage.ReleaseImpound(plate, official.name)
    if success then
        Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, 'release_vehicle', nil, plate)
    end
    cb(success, sErr)
end)

QBCore.Functions.CreateCallback('pv-govtablet:server:seizeProperty', function(source, cb, citizenid, house, reason)
    local official, err = guardedAction(source, 'seizeProperty', citizenid)
    if not official then return cb(false, err) end
    house = Utils.SanitizeString(house, 100)
    if not house then return cb(false, 'invalid_house') end
    reason = Utils.SanitizeString(reason, 255) or 'No reason provided'

    if requiresApproval(official) then
        queueApproval(official, 'property', citizenid, { house = house }, reason)
        return cb(true, 'pending_approval')
    end

    local success, sErr = executeSeizeProperty(citizenid, house, reason, official)
    cb(success, sErr)
end)

QBCore.Functions.CreateCallback('pv-govtablet:server:restoreProperty', function(source, cb, citizenid, house)
    local official, err = guardedAction(source, 'restoreProperty', citizenid)
    if not official then return cb(false, err) end
    house = Utils.SanitizeString(house, 100)
    if not house then return cb(false, 'invalid_house') end

    local success, sErr = Housing.RestoreProperty(citizenid, house, official.name)
    if success then
        Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, 'restore_property', citizenid, house)
    end
    cb(success, sErr)
end)

-- ============================================================
-- Approval queue management
-- ============================================================

QBCore.Functions.CreateCallback('pv-govtablet:server:getPendingApprovals', function(source, cb)
    local official = getOfficialContext(source)
    if not official or not hasPermission(official, 'approveSeizure') then return cb(false, 'no_permission') end

    local rows = MySQL.query.await("SELECT * FROM gt_seizure_requests WHERE status = 'pending' ORDER BY created_at ASC") or {}
    cb(true, rows)
end)

QBCore.Functions.CreateCallback('pv-govtablet:server:resolveApproval', function(source, cb, requestId, approve)
    local official = getOfficialContext(source)
    if not official or not hasPermission(official, 'approveSeizure') then return cb(false, 'no_permission') end

    requestId = tonumber(requestId)
    if not requestId then return cb(false, 'invalid_id') end

    local request = MySQL.single.await("SELECT * FROM gt_seizure_requests WHERE id = ? AND status = 'pending'", { requestId })
    if not request then return cb(false, 'not_found') end

    local ok, payload = pcall(json.decode, request.payload)
    if not ok then return cb(false, 'corrupt_payload') end

    local success = true
    if approve then
        if request.type == 'funds' then
            success = executeSeizeFunds(request.citizenid, payload.accountType, payload.amount, request.reason, official)
        elseif request.type == 'vehicle' then
            success = executeSeizeVehicle(payload.plate, request.reason, official)
        elseif request.type == 'property' then
            success = executeSeizeProperty(request.citizenid, payload.house, request.reason, official)
        end
    end

    MySQL.update.await('UPDATE gt_seizure_requests SET status = ?, resolved_by = ?, resolved_at = CURRENT_TIMESTAMP WHERE id = ?',
        { approve and 'approved' or 'denied', official.name, requestId })

    Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, approve and 'approve_request' or 'deny_request', request.citizenid, ('Request #%d (%s)'):format(requestId, request.type))

    cb(success ~= false, nil)
end)

-- ============================================================
-- Criminal records
-- ============================================================

QBCore.Functions.CreateCallback('pv-govtablet:server:addCriminalRecord', function(source, cb, citizenid, data)
    local official, err = guardedAction(source, 'editCriminal', citizenid)
    if not official then return cb(false, err) end
    if type(data) ~= 'table' then return cb(false, 'invalid_payload') end

    data.officerName = official.name
    data.officerCitizenId = official.citizenid

    local success, sErr = Police.AddRecord(citizenid, data)
    if success then
        Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, 'add_record', citizenid, data.charges or '')
    end
    cb(success, sErr)
end)

-- ============================================================
-- Photo
-- ============================================================

QBCore.Functions.CreateCallback('pv-govtablet:server:setPhoto', function(source, cb, citizenid, photoUrl)
    local official, err = guardedAction(source, 'setPhoto', citizenid)
    if not official then return cb(false, err) end

    photoUrl = Utils.SanitizeString(photoUrl, 500)
    if not photoUrl or not (photoUrl:match('^https?://') ) then return cb(false, 'invalid_url') end

    MySQL.query.await([[
        INSERT INTO gt_citizen_photos (citizenid, photo_url, is_auto, updated_by)
        VALUES (?, ?, 0, ?)
        ON DUPLICATE KEY UPDATE photo_url = ?, is_auto = 0, updated_by = ?, updated_at = CURRENT_TIMESTAMP
    ]], { citizenid, photoUrl, official.name, photoUrl, official.name })

    Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, 'set_photo', citizenid)
    cb(true)
end)

-- ============================================================
-- Auto photo capture
-- Lets client/cl_photo.lua know whether it should bother taking and
-- uploading a screenshot at all, then stores the resulting URL. The
-- citizenid always comes from the player's own session server side -
-- never trusted from the client - so nobody can plant a photo on
-- another citizen's profile.
-- ============================================================

QBCore.Functions.CreateCallback('pv-govtablet:server:needsAutoPhoto', function(source, cb)
    if not Config.AutoPhoto.Enabled then return cb(false) end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end

    local row = MySQL.single.await('SELECT is_auto FROM gt_citizen_photos WHERE citizenid = ?', { Player.PlayerData.citizenid })
    if not row then return cb(true) end
    if Config.AutoPhoto.RetakeEveryLogin and row.is_auto == 1 then return cb(true) end

    cb(false)
end)

RegisterNetEvent('pv-govtablet:server:saveAutoPhoto', function(photoUrl)
    local src = source
    if not Config.AutoPhoto.Enabled then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    photoUrl = Utils.SanitizeString(photoUrl, 500)
    if not photoUrl or not photoUrl:match('^https?://') then return end

    local citizenid = Player.PlayerData.citizenid

    MySQL.query.await([[
        INSERT INTO gt_citizen_photos (citizenid, photo_url, is_auto, updated_by)
        VALUES (?, ?, 1, 'system')
        ON DUPLICATE KEY UPDATE photo_url = ?, is_auto = 1, updated_by = 'system', updated_at = CURRENT_TIMESTAMP
    ]], { citizenid, photoUrl, photoUrl })
end)

-- ============================================================
-- Logs viewer
-- ============================================================

QBCore.Functions.CreateCallback('pv-govtablet:server:getLogs', function(source, cb)
    local official = getOfficialContext(source)
    if not official or not hasPermission(official, 'viewLogs') then return cb(false, 'no_permission') end

    cb(true, Logger.GetRecent(100))
end)

-- ============================================================
-- High-risk payments
-- ============================================================

QBCore.Functions.CreateCallback('pv-govtablet:server:getHighRiskFlags', function(source, cb, statusFilter)
    local official = getOfficialContext(source)
    if not official or not hasPermission(official, 'viewHighRisk') then return cb(false, 'no_permission') end

    local validFilters = { open = true, reviewed = true, dismissed = true, all = true }
    if statusFilter and not validFilters[statusFilter] then statusFilter = 'open' end

    cb(true, RiskMonitor.GetFlags(statusFilter or 'open'))
end)

QBCore.Functions.CreateCallback('pv-govtablet:server:resolveHighRiskFlag', function(source, cb, flagId, status)
    local official = getOfficialContext(source)
    if not official or not hasPermission(official, 'viewHighRisk') then return cb(false, 'no_permission') end

    flagId = tonumber(flagId)
    if not flagId then return cb(false, 'invalid_id') end

    local success, err = RiskMonitor.ResolveFlag(flagId, status, official.name)
    if success then
        Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, status == 'dismissed' and 'dismiss_flag' or 'review_flag', nil, ('Flag #%d'):format(flagId))
    end
    cb(success, err)
end)

-- ============================================================
-- Businesses
-- ============================================================

QBCore.Functions.CreateCallback('pv-govtablet:server:getBusinesses', function(source, cb)
    local official = getOfficialContext(source)
    if not official or not hasPermission(official, 'viewBusinesses') then return cb(false, 'no_permission') end

    cb(true, Business.List())
end)

QBCore.Functions.CreateCallback('pv-govtablet:server:getBusinessProfile', function(source, cb, jobKey)
    local official = getOfficialContext(source)
    if not official or not hasPermission(official, 'viewBusinesses') then return cb(false, 'no_permission') end
    if not Config.Businesses[jobKey] then return cb(false, 'unknown_business') end

    local profile = Business.GetProfile(jobKey)
    if not profile then return cb(false, 'not_found') end

    Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, 'view_business', nil, jobKey)
    cb(true, profile)
end)

-- ============================================================
-- Account lookup
-- ============================================================

QBCore.Functions.CreateCallback('pv-govtablet:server:lookupAccount', function(source, cb, accountNumber)
    local official = getOfficialContext(source)
    if not official or not hasPermission(official, 'viewAccountLookup') then return cb(false, 'no_permission') end
    if isRateLimited(source) then return cb(false, 'rate_limited') end
    if not Utils.IsValidAccountNumber(accountNumber) then return cb(false, 'invalid_account_number') end

    local result = Accounts.Lookup(accountNumber)
    if not result then return cb(false, 'not_found') end

    Logger.Add({ citizenid = official.citizenid, name = official.name, job = official.job }, 'lookup_account', result.citizenid, accountNumber)
    cb(true, result)
end)

-- ============================================================
-- Tablet open trigger (item use)
-- ============================================================

if Config.UseItem then
    QBCore.Functions.CreateUseableItem(Config.Item, function(source)
        local official = getOfficialContext(source)
        if not official then
            TriggerClientEvent('QBCore:Notify', source, 'You are not authorized to use this device.', 'error')
            return
        end
        TriggerClientEvent('pv-govtablet:client:open', source, { job = official.job, label = official.jobCfg.label, permissions = official.jobCfg.permissions })
    end)
end
