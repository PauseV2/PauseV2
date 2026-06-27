-- Middleware engine. Other resources can hook into core decisions
-- (e.g. 'beforePay', 'beforeJobSet', 'canCreateCharacter') and veto them
-- by returning false, without ever needing to fork/edit ox-core itself.

OxHooks = {
    handlers = {},
}

function OxHooks.RegisterHook(name, fn, priority)
    priority = priority or 100

    OxHooks.handlers[name] = OxHooks.handlers[name] or {}
    table.insert(OxHooks.handlers[name], { fn = fn, priority = priority })
    table.sort(OxHooks.handlers[name], function(a, b) return a.priority < b.priority end)
end

-- Runs every registered hook for `name` in priority order.
-- Returns true if the action is allowed, or false + a reason if a hook vetoed it.
function OxHooks.RunHooks(name, ...)
    local list = OxHooks.handlers[name]
    if not list then return true end

    for _, hook in ipairs(list) do
        local ok, result, reason = pcall(hook.fn, ...)

        if not ok then
            print(('[ox-core] hook "%s" errored: %s'):format(name, tostring(result)))
        elseif result == false then
            return false, reason
        end
    end

    return true
end
