--[[
    Accounts bridge
    ---------------
    The tablet's own canonical account registry + transaction ledger.
    QBCore has no universal concept of a "bank account number" - personal
    money just lives on PlayerData.money, keyed by citizenid - so this
    module mints a stable account number for every citizen and every
    configured business (Config.Businesses) the first time it's needed,
    and logs every balance change against it.

    Citizen ledger entries are recorded automatically (see
    server/sv_riskmonitor.lua, which hooks QBCore:Server:OnMoneyChange).
    Business ledger entries only appear once your boss-menu/society script
    calls the RecordBusinessTransaction export - see README.md.

    This is what powers the Account Lookup tab (search any account number,
    see its full transaction history) and what the Businesses tab links
    each company's account number out to.
]]

Accounts = {}

local function generateAccountNumber()
    for _ = 1, 20 do
        local candidate = tostring(math.random(100000000, 999999999))
        local existing = MySQL.single.await('SELECT 1 FROM gt_bank_accounts WHERE account_number = ?', { candidate })
        if not existing then return candidate end
    end
    -- Astronomically unlikely fallback if 20 random draws all collided.
    return tostring(os.time()) .. tostring(math.random(100, 999))
end

local function getOrCreate(ownerType, ownerId, label)
    local row = MySQL.single.await('SELECT account_number FROM gt_bank_accounts WHERE owner_type = ? AND owner_id = ?', { ownerType, ownerId })
    if row then
        if label then
            MySQL.update.await('UPDATE gt_bank_accounts SET label = ? WHERE account_number = ?', { label, row.account_number })
        end
        return row.account_number
    end

    local accountNumber = generateAccountNumber()
    MySQL.insert.await('INSERT INTO gt_bank_accounts (account_number, owner_type, owner_id, label) VALUES (?, ?, ?, ?)',
        { accountNumber, ownerType, ownerId, label })
    return accountNumber
end

function Accounts.GetOrCreateForCitizen(citizenid, charinfo)
    local label = charinfo and ('%s %s'):format(charinfo.firstname or '?', charinfo.lastname or '?') or nil
    return getOrCreate('citizen', citizenid, label)
end

function Accounts.GetOrCreateForBusiness(jobKey, label)
    return getOrCreate('business', jobKey, label)
end

function Accounts.Record(accountNumber, direction, amount, accountType, category, reason, balanceAfter)
    MySQL.insert.await([[
        INSERT INTO gt_transactions (account_number, direction, amount, balance_after, account_type, category, reason)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { accountNumber, direction, amount, balanceAfter, accountType, category, reason })
end

function Accounts.GetTransactions(accountNumber, limit)
    limit = tonumber(limit) or 100
    if limit > 200 then limit = 200 end
    return MySQL.query.await('SELECT * FROM gt_transactions WHERE account_number = ? ORDER BY created_at DESC LIMIT ?', { accountNumber, limit }) or {}
end

-- Looks up an account by number regardless of whether it belongs to a
-- citizen or a business, resolving a display label live (citizen name /
-- business label) rather than trusting the possibly-stale cached label.
function Accounts.Lookup(accountNumber)
    local row = MySQL.single.await('SELECT * FROM gt_bank_accounts WHERE account_number = ?', { accountNumber })
    if not row then return nil end

    local result = {
        accountNumber = row.account_number,
        ownerType = row.owner_type,
        ownerId = row.owner_id,
        label = row.label,
        transactions = Accounts.GetTransactions(row.account_number, 50),
    }

    if row.owner_type == 'citizen' then
        local prow = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { row.owner_id })
        if prow and prow.charinfo then
            local ok, charinfo = pcall(json.decode, prow.charinfo)
            if ok then result.label = ('%s %s'):format(charinfo.firstname or '?', charinfo.lastname or '?') end
        end
        result.citizenid = row.owner_id
        result.balances = Banking.GetBalances(row.owner_id)
    else
        result.job = row.owner_id
        local bizCfg = Config.Businesses[row.owner_id]
        if bizCfg then result.label = bizCfg.label end
        result.balance = Business.GetLiveBalance(row.owner_id)
    end

    return result
end

exports('GetAccountForCitizen', Accounts.GetOrCreateForCitizen)
exports('RecordTransaction', Accounts.Record)
exports('LookupAccount', Accounts.Lookup)
