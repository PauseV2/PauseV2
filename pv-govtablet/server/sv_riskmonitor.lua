--[[
    High-risk payment monitor
    -------------------------
    Hooks QBCore:Server:OnMoneyChange - the single event every
    Player.Functions.AddMoney/RemoveMoney/SetMoney call already fires -
    so every bank/crypto change on any player, anywhere (boss menus,
    drug sales, vehicle shops, paychecks, ATMs, whatever), is recorded
    to the citizen's ledger (gt_transactions, via bridge/sv_accounts.lua)
    with zero extra integration work, and screened in real time against
    Config.HighRiskPayments.

    A flag is raised when:
      - an OUTGOING change >= VehicleThreshold whose `reason` matches one
        of VehicleReasonKeywords (a vehicle purchase), or
      - an INCOMING change >= DepositThreshold whose `reason` does NOT
        match any IgnoreReasonKeywords (an unexplained large deposit -
        this is what catches "drug money" without needing to know what
        drug money looks like; anything large and unrecognized gets
        surfaced for a human to judge).

    Flags are pushed live to every online official with the
    `viewHighRisk` permission, the same way the judge-approval queue
    notifies judges in server/sv_main.lua.

    Other resources can also raise a flag explicitly regardless of
    amount/keywords via:
        exports['pv-govtablet']:FlagHighRiskTransaction(citizenid, 'manual', 50000, 'bank', 'Reported by qb-drugs')
]]

local QBCore = exports['qb-core']:GetCoreObject()

RiskMonitor = {}

local validCategories = { large_deposit = true, vehicle_purchase = true, manual = true }

local function getCitizenInfo(citizenid)
    local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if Player then
        return Player.PlayerData.charinfo
    end
    local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
    if not row or not row.charinfo then return nil end
    local ok, charinfo = pcall(json.decode, row.charinfo)
    return ok and charinfo or nil
end

local function matchesAny(haystack, keywords)
    if not haystack or haystack == '' then return false end
    haystack = haystack:lower()
    for _, kw in ipairs(keywords) do
        if haystack:find(kw:lower(), 1, true) then return true end
    end
    return false
end

local function notifyOfficials(flagRow)
    local players = QBCore.Functions.GetQBPlayers()
    for _, Player in pairs(players) do
        local jobCfg = Config.Jobs[Player.PlayerData.job.name]
        if jobCfg and jobCfg.permissions.viewHighRisk then
            local src = Player.PlayerData.source
            TriggerClientEvent('QBCore:Notify', src, ('High-risk payment flagged: %s ($%d)'):format(flagRow.category, flagRow.amount), 'error')
            TriggerClientEvent('pv-govtablet:client:highRiskFlag', src, flagRow)
        end
    end
end

-- Inserts a flag row and notifies officials. `accountNumber` may be nil if the
-- caller doesn't have one handy - the citizen's account is resolved either way.
function RiskMonitor.Flag(citizenid, category, amount, accountType, reason, accountNumber, details)
    if not Utils.IsValidCitizenId(citizenid) then return false, 'invalid_citizenid' end
    if not validCategories[category] then return false, 'invalid_category' end
    if not Utils.IsPositiveNumber(amount) then return false, 'invalid_amount' end

    amount = Utils.Round(amount)
    reason = Utils.SanitizeString(reason, 255)
    details = Utils.SanitizeString(details, 255)

    if not accountNumber then
        local charinfo = getCitizenInfo(citizenid)
        accountNumber = Accounts.GetOrCreateForCitizen(citizenid, charinfo)
    end

    local id = MySQL.insert.await([[
        INSERT INTO gt_high_risk_flags (citizenid, account_number, category, amount, account_type, reason, details)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { citizenid, accountNumber, category, amount, accountType, reason, details })

    local flagRow = {
        id = id,
        citizenid = citizenid,
        account_number = accountNumber,
        category = category,
        amount = amount,
        account_type = accountType,
        reason = reason,
        details = details,
        status = 'open',
    }
    notifyOfficials(flagRow)
    return true
end

function RiskMonitor.GetFlags(statusFilter)
    if statusFilter and statusFilter ~= 'all' then
        return MySQL.query.await('SELECT * FROM gt_high_risk_flags WHERE status = ? ORDER BY created_at DESC LIMIT 200', { statusFilter }) or {}
    end
    return MySQL.query.await('SELECT * FROM gt_high_risk_flags ORDER BY created_at DESC LIMIT 200') or {}
end

function RiskMonitor.ResolveFlag(flagId, status, officialName)
    if status ~= 'reviewed' and status ~= 'dismissed' then return false, 'invalid_status' end

    local existing = MySQL.single.await("SELECT id FROM gt_high_risk_flags WHERE id = ? AND status = 'open'", { flagId })
    if not existing then return false, 'not_found' end

    MySQL.update.await('UPDATE gt_high_risk_flags SET status = ?, reviewed_by = ? WHERE id = ?', { status, officialName, flagId })
    return true
end

-- ============================================================
-- Automatic detection on every bank/crypto change
-- ============================================================

AddEventHandler('QBCore:Server:OnMoneyChange', function(src, moneyType, amount, operation, reason)
    if not Utils.IsValidMoneyType(moneyType) then return end
    if operation ~= 'add' and operation ~= 'remove' then return end
    if not Utils.IsPositiveNumber(amount) then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local accountNumber = Accounts.GetOrCreateForCitizen(citizenid, Player.PlayerData.charinfo)
    local direction = operation == 'add' and 'in' or 'out'
    local balanceAfter = tonumber(Player.PlayerData.money[moneyType]) or 0
    local cleanReason = Utils.SanitizeString(reason, 255) or 'unspecified'

    local category = 'other'
    local shouldFlag, flagCategory = false, nil

    if direction == 'out' then
        if matchesAny(cleanReason, Config.HighRiskPayments.VehicleReasonKeywords) then
            category = 'vehicle_purchase'
            if Config.HighRiskPayments.Enabled and amount >= Config.HighRiskPayments.VehicleThreshold then
                shouldFlag, flagCategory = true, 'vehicle_purchase'
            end
        end
    else
        if matchesAny(cleanReason, { 'paycheck', 'salary' }) then category = 'salary' end
        if Config.HighRiskPayments.Enabled
            and amount >= Config.HighRiskPayments.DepositThreshold
            and not matchesAny(cleanReason, Config.HighRiskPayments.IgnoreReasonKeywords) then
            shouldFlag, flagCategory = true, 'large_deposit'
        end
    end

    Accounts.Record(accountNumber, direction, Utils.Round(amount), moneyType, category, cleanReason, balanceAfter)

    if shouldFlag then
        RiskMonitor.Flag(citizenid, flagCategory, amount, moneyType, cleanReason, accountNumber)
    end
end)

exports('FlagHighRiskTransaction', function(citizenid, category, amount, accountType, reason, details)
    return RiskMonitor.Flag(citizenid, category, amount, accountType, reason, nil, details)
end)
