-- Multiplexed callback system: a single net event carries every callback
-- request (tagged with a request id), instead of registering a new net
-- event per callback like QBCore/ESX do.

OxCallbacks = {
    handlers = {},
}

function OxCallbacks.Register(name, fn)
    OxCallbacks.handlers[name] = fn
end

RegisterNetEvent('ox:server:triggerCallback', function(name, requestId, ...)
    local src = source
    local handler = OxCallbacks.handlers[name]

    if not handler then
        TriggerClientEvent('ox:client:callbackResponse', src, requestId, false, 'unknown callback: ' .. tostring(name))
        return
    end

    local args = { ... }

    CreateThread(function()
        local results = table.pack(pcall(handler, src, table.unpack(args)))
        local ok = results[1]

        if not ok then
            TriggerClientEvent('ox:client:callbackResponse', src, requestId, false, results[2])
            return
        end

        local response = { true }
        for i = 2, results.n do
            response[#response + 1] = results[i]
        end

        TriggerClientEvent('ox:client:callbackResponse', src, requestId, table.unpack(response))
    end)
end)
