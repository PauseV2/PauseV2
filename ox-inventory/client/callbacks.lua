-- Mirrors ox-core's client/callbacks.lua but on its own namespaced events -
-- see server/callbacks.lua for why this isn't shared between resources.

local requestId = 0
local pending = {}

RegisterNetEvent('ox_inventory:client:callbackResponse', function(reqId, ok, ...)
    local p = pending[reqId]
    if not p then return end

    pending[reqId] = nil
    p:resolve({ ok = ok, args = table.pack(...) })
end)

function OxInvTriggerCallback(name, ...)
    requestId = requestId + 1
    local id = requestId
    local p = promise.new()
    pending[id] = p

    TriggerServerEvent('ox_inventory:server:triggerCallback', name, id, ...)

    local result = Citizen.Await(p)

    if not result.ok then
        return false, result.args[1]
    end

    return true, table.unpack(result.args, 1, result.args.n)
end
