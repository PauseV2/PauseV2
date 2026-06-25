Config = Config or {}

-- ============================================================
-- Clients can periodically disappear instead of always being available.
-- ============================================================

Config.Ghosting = {
    enabled               = true,
    checkIntervalMinutes  = 60,
    chance                = 6,    -- % chance per check a contact's status changes
    statuses = {
        offline = { weight = 50, durationMinutes = {30, 180} },
        hiding  = { weight = 25, durationMinutes = {60, 360} },
        arrested = { weight = 15, durationMinutes = {120, 720} },
        dead    = { weight = 10, durationMinutes = nil }, -- permanent
    },
    permanentLossChance = 10, -- % chance, when a temporary status expires, the contact is permanently lost instead of returning
}
