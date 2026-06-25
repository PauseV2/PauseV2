Config = Config or {}

-- ============================================================
-- Police evidence integration. Exposes server exports (see server/police.lua)
-- that any police/MDT script can call after seizing a physical phone item.
-- ============================================================

Config.Police = {
    enabled         = true,
    allowedJobs     = {'police', 'sheriff', 'state'},
    requireEncryptionBreak = true,    -- higher encryption phones need a "decrypt" delay before evidence can be viewed
    decryptSeconds = {
        [1] = 15,  -- encryption level 1 (cheap burner)
        [2] = 45,  -- level 2
        [3] = 120, -- level 3 (ghost phone)
    },
    exposedData = {
        messages   = true,
        contacts   = true,
        gpsLogs    = true,
        deliveries = true,
        alias      = true,
    },
}
