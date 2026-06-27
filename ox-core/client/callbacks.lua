-- Client side of the multiplexed callback system: every call goes through
-- one net event tagged with a request id and resolves a promise, so calling
-- code reads top-to-bottom instead of nesting callbacks.

local requestId = 0
local pending = {}

RegisterNetEvent('ox:client:callbackResponse', function(reqId, ok, ...)
    local p = pending[reqId]
    if not p then return end

    pending[reqId] = nil
    p:resolve({ ok = ok, args = table.pack(...) })
end)

function OxTriggerCallback(name, ...)
    requestId = requestId + 1
    local id = requestId
    local p = promise.new()
    pending[id] = p

    TriggerServerEvent('ox:server:triggerCallback', name, id, ...)

    local result = Citizen.Await(p)

    if not result.ok then
        return false, result.args[1]
    end

    return true, table.unpack(result.args, 1, result.args.n)
end
