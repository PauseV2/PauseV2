-- Example admin commands gated by ace permissions. Grant them in server.cfg, e.g.:
--   add_ace group.admin command.setjob allow
--   add_ace group.admin command.addmoney allow

local function HasPermission(source, ace)
    return source == 0 or IsPlayerAceAllowed(source, ace)
end

RegisterCommand('setjob', function(source, args)
    if not HasPermission(source, 'command.setjob') then return end

    local target = Ox.GetPlayer(tonumber(args[1]))
    if not target then
        print('[ox-core] setjob: target player not loaded')
        return
    end

    local ok, err = target:SetJob(args[2], tonumber(args[3]) or 0)
    if not ok then
        print('[ox-core] setjob failed: ' .. tostring(err))
    end
end, false)

RegisterCommand('addmoney', function(source, args)
    if not HasPermission(source, 'command.addmoney') then return end

    local target = Ox.GetPlayer(tonumber(args[1]))
    if not target then
        print('[ox-core] addmoney: target player not loaded')
        return
    end

    local ok, err = target:AddMoney(args[2], tonumber(args[3]), 'admin')
    if not ok then
        print('[ox-core] addmoney failed: ' .. tostring(err))
    end
end, false)
