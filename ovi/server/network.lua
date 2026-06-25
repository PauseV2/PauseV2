-- ============================================================
-- Global OVI network status. A single switch, not per-phone - when staff
-- flip it, every currently open OVI dashboard updates live.
-- ============================================================

if not Config.Toggle.NetworkStatus then return end

local NetCfg = Config.NetworkStatus
OVI.Cache.networkRaided = OVI.Cache.networkRaided or false

function OVI.IsNetworkRaided()
    return OVI.Cache.networkRaided
end

local function setNetworkStatus(raided)
    OVI.Cache.networkRaided = raided
    TriggerClientEvent('ovi:client:pushUpdate', -1, { type = 'networkStatus', raided = raided })
end

RegisterCommand(NetCfg.command, function(source, args)
    local state = args[1]
    if state ~= 'stable' and state ~= 'raided' then
        local usage = ('Usage: /%s stable|raided'):format(NetCfg.command)
        if source == 0 then
            print(usage)
        else
            TriggerClientEvent('QBCore:Notify', source, usage, 'error')
        end
        return
    end
    setNetworkStatus(state == 'raided')
end, true)
