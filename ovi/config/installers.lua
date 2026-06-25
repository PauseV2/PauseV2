Config = Config or {}

-- ============================================================
-- OVI Installer NPCs. OVI is never pre-installed - a player must visit
-- one of these locations, pay, set a PIN + alias (qb-input) and the
-- app is then flagged on that specific phone's IMEI.
-- ============================================================

Config.Installers = {
    {
        label       = 'Sketchy Hacker',
        model       = 'a_m_y_skater_01',
        coords      = vector4(-1148.78, -1505.49, 4.38, 210.0),
        price       = 500,
        cooldown    = 30,   -- minutes before this NPC will deal with the same player again
        animDict    = 'mp_common_m_anims', -- example anim, swap for your own
        animName    = 'givetake1_a',
        requiredItem = nil, -- e.g. 'cryptophone_chip' if you want a gating item
        scenario    = 'WORLD_HUMAN_STAND_IMPATIENT',
        target = {
            icon = 'fas fa-laptop-code',
            label = 'Talk about a "private install"',
            distance = 2.0,
        },
    },
    {
        label       = 'Repair Shop Backroom',
        model       = 'a_m_m_mexlabor_01',
        coords      = vector4(715.42, -966.13, 30.4, 160.0),
        price       = 650,
        cooldown    = 30,
        animDict    = 'mp_common_m_anims',
        animName    = 'givetake1_a',
        requiredItem = nil,
        scenario    = 'WORLD_HUMAN_LEAN_MALE_POSE',
        target = {
            icon = 'fas fa-screwdriver-wrench',
            label = 'Ask about "phone work"',
            distance = 2.0,
        },
    },
    {
        label       = 'Dock Contact',
        model       = 'g_m_m_armgoon_02',
        coords      = vector4(1183.0, -3134.0, 5.9, 40.0),
        price       = 800,
        cooldown    = 45,
        animDict    = 'mp_common_m_anims',
        animName    = 'givetake1_a',
        requiredItem = nil,
        scenario    = 'WORLD_HUMAN_SMOKING',
        target = {
            icon = 'fas fa-anchor',
            label = 'Ask about "imports"',
            distance = 2.0,
        },
    },
    {
        label       = 'Hidden Internet Cafe',
        model       = 'a_m_y_business_03',
        coords      = vector4(-587.0, -1685.0, 32.5, 300.0),
        price       = 450,
        cooldown    = 30,
        animDict    = 'mp_common_m_anims',
        animName    = 'givetake1_a',
        requiredItem = nil,
        scenario    = 'WORLD_HUMAN_STAND_MOBILE',
        target = {
            icon = 'fas fa-wifi',
            label = 'Whisper about OVI',
            distance = 2.0,
        },
    },
}

-- Required phone item type(s) the player must be holding for an installer
-- to even offer the service. Leave empty to allow any OVI-capable phone.
Config.InstallerRequiresPhone = true
