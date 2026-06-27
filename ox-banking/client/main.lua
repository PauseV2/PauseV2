local requestId = 0
local pending = {}

RegisterNetEvent('ox_banking:client:callbackResponse', function(reqId, ok, ...)
    local p = pending[reqId]
    if not p then return end

    pending[reqId] = nil
    p:resolve({ ok = ok, args = table.pack(...) })
end)

local function TriggerCallback(name, ...)
    requestId = requestId + 1
    local id = requestId
    local p = promise.new()
    pending[id] = p

    TriggerServerEvent('ox_banking:server:triggerCallback', name, id, ...)

    local result = Citizen.Await(p)

    if not result.ok then
        return false, result.args[1]
    end

    return true, table.unpack(result.args, 1, result.args.n)
end

local atmHashes = {}
for _, model in ipairs(Config.AtmModels) do
    atmHashes[#atmHashes + 1] = GetHashKey(model)
end

local isOpen = false

local function OpenBanking()
    local ok, money = TriggerCallback('ox_banking:getBalances')
    if not ok then return end

    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', money = money })
end

local function CloseBanking()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    CloseBanking()
    cb({ ok = true })
end)

RegisterNUICallback('deposit', function(data, cb)
    local ok, result = TriggerCallback('ox_banking:deposit', data.amount)
    cb({ ok = ok, money = ok and result or nil, error = not ok and result or nil })
end)

RegisterNUICallback('withdraw', function(data, cb)
    local ok, result = TriggerCallback('ox_banking:withdraw', data.amount)
    cb({ ok = ok, money = ok and result or nil, error = not ok and result or nil })
end)

CreateThread(function()
    while true do
        Wait(500)

        if not isOpen then
            local coords = GetEntityCoords(PlayerPedId())
            local closest, closestDist = nil, Config.InteractDistance

            for _, hash in ipairs(atmHashes) do
                local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, Config.InteractDistance, hash, false, false, false)

                if obj ~= 0 then
                    local dist = #(coords - GetEntityCoords(obj))
                    if dist <= closestDist then
                        closest, closestDist = obj, dist
                    end
                end
            end

            if closest then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('[E] Use ATM')
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustReleased(0, 38) then
                    OpenBanking()
                end
            end
        end
    end
end)
