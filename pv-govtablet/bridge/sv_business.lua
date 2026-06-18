--[[
    Business bridge
    ----------------
    Reads staff rosters and pay straight from QBCore.Shared.Jobs + the
    `players` table - that data already exists and is always live, so
    there's nothing to duplicate or fall out of sync.

    The live balance is read from Config.Bridge.Business (defaults to
    qb-management's `management_funds` table) - adjust the table/column
    names if your society-money resource differs. If the table isn't
    found, businesses just show a $0 balance instead of erroring.

    Deposit/withdrawal history is NOT something QBCore tracks anywhere by
    default for society accounts, so the tablet keeps its own ledger (see
    bridge/sv_accounts.lua) that only fills in once your boss-menu/society
    script calls the RecordBusinessTransaction export whenever money moves
    in or out - see README.md for a usage example.
]]

local QBCore = exports['qb-core']:GetCoreObject()

Business = {}

local cfg = Config.Bridge.Business

local tableExistsCache = {}
local function tableExists(tableName)
    if tableExistsCache[tableName] ~= nil then return tableExistsCache[tableName] end
    local row = MySQL.single.await('SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ? LIMIT 1', { tableName })
    tableExistsCache[tableName] = row ~= nil
    return tableExistsCache[tableName]
end

function Business.GetLiveBalance(jobKey)
    if not tableExists(cfg.FundsTable) then return 0 end
    local row = MySQL.single.await(('SELECT `%s` as amount FROM `%s` WHERE `%s` = ?'):format(cfg.AmountField, cfg.FundsTable, cfg.JobField), { jobKey })
    return row and tonumber(row.amount) or 0
end

function Business.GetRoster(jobKey)
    local jobShared = QBCore.Shared.Jobs[jobKey]
    if not jobShared then return {} end

    local rows = MySQL.query.await([[
        SELECT citizenid, charinfo, job FROM players
        WHERE JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ?
    ]], { jobKey }) or {}

    local roster = {}
    for _, row in ipairs(rows) do
        local okC, charinfo = pcall(json.decode, row.charinfo or '{}')
        local okJ, jobData = pcall(json.decode, row.job or '{}')
        charinfo = okC and charinfo or {}
        jobData = okJ and jobData or {}

        local gradeLevel = tostring((jobData.grade and jobData.grade.level) or 0)
        local gradeShared = jobShared.grades[gradeLevel]

        roster[#roster + 1] = {
            citizenid = row.citizenid,
            name = ('%s %s'):format(charinfo.firstname or '?', charinfo.lastname or '?'),
            gradeLabel = (gradeShared and gradeShared.name) or (jobData.grade and jobData.grade.name) or 'Unknown',
            gradeLevel = tonumber(gradeLevel) or 0,
            payment = gradeShared and gradeShared.payment or 0,
            onDuty = jobData.onduty == true,
        }
    end

    table.sort(roster, function(a, b) return a.gradeLevel > b.gradeLevel end)
    return roster
end

function Business.List()
    local list = {}
    for jobKey, bizCfg in pairs(Config.Businesses) do
        local accountNumber = Accounts.GetOrCreateForBusiness(jobKey, bizCfg.label)
        local roster = Business.GetRoster(jobKey)
        list[#list + 1] = {
            job = jobKey,
            label = bizCfg.label,
            accountNumber = accountNumber,
            balance = Business.GetLiveBalance(jobKey),
            staffCount = #roster,
        }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

function Business.GetProfile(jobKey)
    local bizCfg = Config.Businesses[jobKey]
    if not bizCfg then return nil end

    local accountNumber = Accounts.GetOrCreateForBusiness(jobKey, bizCfg.label)

    return {
        job = jobKey,
        label = bizCfg.label,
        accountNumber = accountNumber,
        balance = Business.GetLiveBalance(jobKey),
        roster = Business.GetRoster(jobKey),
        transactions = Accounts.GetTransactions(accountNumber, 50),
    }
end

-- Other resources (boss menus, society scripts) call this whenever money
-- actually moves in or out of a business account, e.g.:
--   exports['pv-govtablet']:RecordBusinessTransaction('mechanic', 'in', 2500, 'sale', 'Vehicle repair - Michael De Santa')
--   exports['pv-govtablet']:RecordBusinessTransaction('mechanic', 'out', 1200, 'payroll', 'Weekly payroll run')
function Business.RecordTransaction(jobKey, direction, amount, category, reason)
    if not Config.Businesses[jobKey] then return false, 'unknown_business' end
    if direction ~= 'in' and direction ~= 'out' then return false, 'invalid_direction' end
    if not Utils.IsPositiveNumber(amount) then return false, 'invalid_amount' end

    local accountNumber = Accounts.GetOrCreateForBusiness(jobKey, Config.Businesses[jobKey].label)
    local balanceAfter = Business.GetLiveBalance(jobKey)

    Accounts.Record(accountNumber, direction, Utils.Round(amount), 'business', Utils.SanitizeString(category, 50) or 'other', Utils.SanitizeString(reason, 255), balanceAfter)
    return true
end

exports('RecordBusinessTransaction', Business.RecordTransaction)
