-- ============================================================
-- Clients periodically go offline / hide / get arrested / die instead of
-- always being reachable.
-- ============================================================

if not Config.Toggle.Ghosting then return end

local Ghosting = Config.Ghosting

local function rollStatus()
    local pool = {}
    for status, cfg in pairs(Ghosting.statuses) do
        pool[#pool + 1] = { key = status, weight = cfg.weight }
    end
    local picked = OVI.WeightedRandom(pool)
    return picked and picked.key or nil
end

CreateThread(function()
    while true do
        Wait(Ghosting.checkIntervalMinutes * 60 * 1000)

        local activeClients = MySQL.query.await("SELECT contact_id FROM ovi_clients_global WHERE status = 'active'") or {}
        for _, row in ipairs(activeClients) do
            if OVI.Chance(Ghosting.chance) then
                local status = rollStatus()
                if status then
                    local cfg = Ghosting.statuses[status]
                    local ghostUntil = cfg.durationMinutes and (os.time() + OVI.RandomRange(cfg.durationMinutes[1], cfg.durationMinutes[2]) * 60) or 0
                    OVI.DB.SetClientStatus(row.contact_id, status, ghostUntil)
                end
            end
        end

        local expired = MySQL.query.await(
            "SELECT contact_id FROM ovi_clients_global WHERE status != 'active' AND status != 'dead' AND ghost_until > 0 AND ghost_until <= ?",
            { os.time() }
        ) or {}
        for _, row in ipairs(expired) do
            if OVI.Chance(Ghosting.permanentLossChance) then
                OVI.DB.SetClientStatus(row.contact_id, 'lost', 0)
            else
                OVI.DB.SetClientStatus(row.contact_id, 'active', 0)
            end
        end
    end
end)
