-- Own multiplexed callback pair, namespaced separately from ox-core's.
-- Two resources registering the same net event name would both fire on every
-- trigger and race each other's response to the client, so each resource
-- keeps a small local copy of this pattern rather than sharing one - if a
-- 3rd resource needs this, that's the point to extract a shared lib, not before.

OxInvCallbacks = {
    handlers = {},
}

function OxInvCallbacks.Register(name, fn)
    OxInvCallbacks.handlers[name] = fn
end

RegisterNetEvent('ox_inventory:server:triggerCallback', function(name, requestId, ...)
    local src = source
    local handler = OxInvCallbacks.handlers[name]

    if not handler then
        TriggerClientEvent('ox_inventory:client:callbackResponse', src, requestId, false, 'unknown callback: ' .. tostring(name))
        return
    end

    local args = { ... }

    CreateThread(function()
        local results = table.pack(pcall(handler, src, table.unpack(args)))
        local ok = results[1]

        if not ok then
            TriggerClientEvent('ox_inventory:client:callbackResponse', src, requestId, false, results[2])
            return
        end

        local response = { true }
        for i = 2, results.n do
            response[#response + 1] = results[i]
        end

        TriggerClientEvent('ox_inventory:client:callbackResponse', src, requestId, table.unpack(response))
    end)
end)
