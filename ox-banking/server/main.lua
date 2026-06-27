-- Own multiplexed callback pair, namespaced separately from ox-core's and
-- ox-inventory's - same reasoning as ox-inventory/server/callbacks.lua.

local handlers = {}

local function Register(name, fn)
    handlers[name] = fn
end

RegisterNetEvent('ox_banking:server:triggerCallback', function(name, requestId, ...)
    local src = source
    local handler = handlers[name]

    if not handler then
        TriggerClientEvent('ox_banking:client:callbackResponse', src, requestId, false, 'unknown callback: ' .. tostring(name))
        return
    end

    local args = { ... }

    CreateThread(function()
        local results = table.pack(pcall(handler, src, table.unpack(args)))
        local ok = results[1]

        if not ok then
            TriggerClientEvent('ox_banking:client:callbackResponse', src, requestId, false, results[2])
            return
        end

        local response = { true }
        for i = 2, results.n do
            response[#response + 1] = results[i]
        end

        TriggerClientEvent('ox_banking:client:callbackResponse', src, requestId, table.unpack(response))
    end)
end)

Register('ox_banking:getBalances', function(source)
    local playerData = exports['ox-core']:GetPlayer(source)
    if not playerData then return false, 'character not loaded' end
    return true, playerData.money
end)

Register('ox_banking:deposit', function(source, amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false, 'invalid amount' end

    local removed, removeErr = exports['ox-core']:RemoveMoney(source, 'cash', amount, 'atm:deposit')
    if not removed then return false, removeErr or 'insufficient cash' end

    local added, addErr = exports['ox-core']:AddMoney(source, 'bank', amount, 'atm:deposit')
    if not added then
        exports['ox-core']:AddMoney(source, 'cash', amount, 'atm:deposit refund')
        return false, addErr or 'deposit failed'
    end

    local playerData = exports['ox-core']:GetPlayer(source)
    return true, playerData.money
end)

Register('ox_banking:withdraw', function(source, amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false, 'invalid amount' end

    local removed, removeErr = exports['ox-core']:RemoveMoney(source, 'bank', amount, 'atm:withdraw')
    if not removed then return false, removeErr or 'insufficient funds' end

    local added, addErr = exports['ox-core']:AddMoney(source, 'cash', amount, 'atm:withdraw')
    if not added then
        exports['ox-core']:AddMoney(source, 'bank', amount, 'atm:withdraw refund')
        return false, addErr or 'withdraw failed'
    end

    local playerData = exports['ox-core']:GetPlayer(source)
    return true, playerData.money
end)
