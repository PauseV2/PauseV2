-- Money mutations are guarded by a per-character mutex. Without it, two
-- concurrent calls (e.g. a payout firing while a shop purchase is mid-flight)
-- can both read the same starting balance and one of the writes is lost -
-- the classic dupe/loss bug class in QBCore-style frameworks.

local locks = {}

local function AcquireLock(citizenid)
    while locks[citizenid] do
        Wait(0)
    end
    locks[citizenid] = true
end

local function ReleaseLock(citizenid)
    locks[citizenid] = nil
end

function OxPlayer:GetMoney(account)
    return self.money[account]
end

function OxPlayer:AddMoney(account, amount, reason)
    if type(amount) ~= 'number' or amount <= 0 then return false, 'invalid amount' end
    if self.money[account] == nil then return false, 'invalid account' end

    AcquireLock(self.citizenid)

    local allowed, hookReason = OxHooks.RunHooks('beforeAddMoney', self, account, amount, reason)
    local success, errorReason = true, nil

    if not allowed then
        success, errorReason = false, hookReason or 'denied'
    else
        self.money[account] = self.money[account] + amount
        Player(self.source).state:set('money', self.money, false)
        TriggerClientEvent('ox:client:syncMoney', self.source, self.money)
        TriggerEvent('ox:server:moneyChanged', self.source, account, amount, self.money[account], reason)
    end

    ReleaseLock(self.citizenid)
    return success, errorReason
end

function OxPlayer:RemoveMoney(account, amount, reason)
    if type(amount) ~= 'number' or amount <= 0 then return false, 'invalid amount' end
    if self.money[account] == nil then return false, 'invalid account' end

    AcquireLock(self.citizenid)

    local success, errorReason = true, nil

    if self.money[account] < amount then
        success, errorReason = false, 'insufficient funds'
    else
        local allowed, hookReason = OxHooks.RunHooks('beforeRemoveMoney', self, account, amount, reason)

        if not allowed then
            success, errorReason = false, hookReason or 'denied'
        else
            self.money[account] = self.money[account] - amount
            Player(self.source).state:set('money', self.money, false)
            TriggerClientEvent('ox:client:syncMoney', self.source, self.money)
            TriggerEvent('ox:server:moneyChanged', self.source, account, -amount, self.money[account], reason)
        end
    end

    ReleaseLock(self.citizenid)
    return success, errorReason
end

function OxPlayer:SetMoney(account, amount, reason)
    if type(amount) ~= 'number' or amount < 0 then return false, 'invalid amount' end
    if self.money[account] == nil then return false, 'invalid account' end

    AcquireLock(self.citizenid)

    self.money[account] = amount
    Player(self.source).state:set('money', self.money, false)
    TriggerClientEvent('ox:client:syncMoney', self.source, self.money)
    TriggerEvent('ox:server:moneyChanged', self.source, account, nil, self.money[account], reason)

    ReleaseLock(self.citizenid)
    return true
end
