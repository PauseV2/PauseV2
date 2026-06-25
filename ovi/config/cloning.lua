Config = Config or {}

-- ============================================================
-- Phone cloning NPC: backup a phone's data, recover it onto a new phone,
-- or migrate data from one physical phone to another.
-- ============================================================

Config.Cloning = {
    npc = {
        model  = 'a_m_y_business_01',
        coords = vector4(-148.0, -620.0, 168.8, 110.0),
        scenario = 'WORLD_HUMAN_STAND_MOBILE',
        target = {
            icon = 'fas fa-clone',
            label = 'Ask about phone cloning',
            distance = 2.0,
        },
    },
    backupPrice    = 250,
    recoveryPrice  = 400,
    migratePrice   = 600,
    cooldownMinutes = 60,
    maxBackupsPerPhone = 3,
}
