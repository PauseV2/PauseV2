--[[
    Banking bridge
    --------------
    Reads/writes balances directly on the QBCore player object
    (PlayerData.money.bank / crypto) which is what qb-management,
    qb-banking and most money scripts read from. Freeze/hide state is
    kept in its own overlay table (gt_account_freezes) so it survives
    independently of whatever banking script you run.

    Cash on hand is deliberately not tracked here - government staff
    have no realistic way to see physical cash a citizen is carrying,
    so it's excluded from Config.MoneyTypes entirely.

    Other resources should call:
        exports['pv-govtablet']:IsAccountFrozen(citizenid, 'bank')
    before allowing a deposit/withdraw/transfer so frozen accounts can't
    be used. See README.md for a qb-banking integration snippet.
]]

local QBCore = exports['qb-core']:GetCoreObject()

Banking = {}

-- citizenid -> { bank = {frozen,hidden}, crypto = {...} }
local freezeCache = {}

local function loadFreezeState(citizenid)
    local rows = MySQL.query.await('SELECT account_type, frozen, hidden FROM gt_account_freezes WHERE citizenid = ?', { citizenid })
    local state = { bank = { frozen = false, hidden = false }, crypto = { frozen = false, hidden = false } }
    if rows then
        for _, row in ipairs(rows) do
            state[row.account_type] = { frozen = row.frozen == 1, hidden = row.hidden == 1 }
        end
    end
    freezeCache[citizenid] = state
    return state
end

function Banking.GetFreezeState(citizenid)
    return freezeCache[citizenid] or loadFreezeState(citizenid)
end

function Banking.IsFrozen(citizenid, accountType)
    if not Utils.IsValidMoneyType(accountType) then return false end
    local state = Banking.GetFreezeState(citizenid)
    return state[accountType] and state[accountType].frozen or false
end

function Banking.IsHidden(citizenid, accountType)
    if not Utils.IsValidMoneyType(accountType) then return false end
    local state = Banking.GetFreezeState(citizenid)
    return state[accountType] and state[accountType].hidden or false
end

function Banking.GetBalances(citizenid)
    local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    local money

    if Player then
        money = Player.PlayerData.money
    else
        local row = MySQL.single.await('SELECT money FROM players WHERE citizenid = ?', { citizenid })
        if row and row.money then
            local ok, decoded = pcall(json.decode, row.money)
            money = ok and decoded or {}
        end
    end

    money = money or {}
    local state = Banking.GetFreezeState(citizenid)

    local balances = {}
    for _, accountType in ipairs(Config.MoneyTypes) do
        balances[accountType] = {
            amount = tonumber(money[accountType]) or 0,
            frozen = state[accountType] and state[accountType].frozen or false,
            hidden = state[accountType] and state[accountType].hidden or false,
        }
    end
    return balances
end

function Banking.SetFrozen(citizenid, accountType, frozen, reason, staffName)
    if not Utils.IsValidMoneyType(accountType) then return false end

    MySQL.query.await([[
        INSERT INTO gt_account_freezes (citizenid, account_type, frozen, reason, updated_by)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE frozen = ?, reason = ?, updated_by = ?, updated_at = CURRENT_TIMESTAMP
    ]], { citizenid, accountType, frozen and 1 or 0, reason, staffName, frozen and 1 or 0, reason, staffName })

    loadFreezeState(citizenid)
    return true
end

function Banking.SetHidden(citizenid, accountType, hidden, staffName)
    if not Utils.IsValidMoneyType(accountType) then return false end

    MySQL.query.await([[
        INSERT INTO gt_account_freezes (citizenid, account_type, hidden, updated_by)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE hidden = ?, updated_by = ?, updated_at = CURRENT_TIMESTAMP
    ]], { citizenid, accountType, hidden and 1 or 0, staffName, hidden and 1 or 0, staffName })

    loadFreezeState(citizenid)
    return true
end

-- Removes `amount` from the citizen's account, online or offline,
-- and records the seizure for audit purposes. Returns false if the
-- citizen does not have sufficient funds.
function Banking.SeizeFunds(citizenid, accountType, amount, reason, staffName)
    if not Utils.IsValidMoneyType(accountType) or not Utils.IsPositiveNumber(amount) then
        return false, 'invalid_input'
    end

    amount = Utils.Round(amount)
    local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)

    if Player then
        local current = Player.PlayerData.money[accountType] or 0
        if current < amount then return false, 'insufficient_funds' end
        Player.Functions.RemoveMoney(accountType, amount, 'gov-tablet-seizure')
    else
        local row = MySQL.single.await('SELECT money FROM players WHERE citizenid = ?', { citizenid })
        if not row or not row.money then return false, 'not_found' end
        local ok, money = pcall(json.decode, row.money)
        if not ok then return false, 'corrupt_data' end
        local current = tonumber(money[accountType]) or 0
        if current < amount then return false, 'insufficient_funds' end
        money[accountType] = current - amount
        MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), citizenid })
    end

    MySQL.insert.await([[
        INSERT INTO gt_fund_seizures (citizenid, account_type, amount, reason, seized_by)
        VALUES (?, ?, ?, ?, ?)
    ]], { citizenid, accountType, amount, reason, staffName })

    return true
end

exports('IsAccountFrozen', Banking.IsFrozen)
exports('IsAccountHidden', Banking.IsHidden)
exports('GetBalances', Banking.GetBalances)
