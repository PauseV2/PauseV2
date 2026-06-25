Config = Config or {}

-- ============================================================
-- Dead drop deliveries (no face-to-face contact). Uses qb-target on props.
-- ============================================================

Config.DeadDrops = {
    chance            = 30,  -- % chance a delivery is offered as a dead drop instead of meet
    payoutMultiplier  = 1.15,
    riskMultiplier    = 1.3,  -- multiplies trap/police chance for that delivery

    locations = {
        { label = 'Trash Bin', coords = vector3(126.85, -1290.0, 29.27), prop = 'prop_bin_03a' },
        { label = 'Storage Locker', coords = vector3(-185.0, -1495.0, 32.0), prop = 'prop_lockers_01a' },
        { label = 'Alley Bag', coords = vector3(-1170.0, -905.0, 13.0), prop = 'prop_cs_bin_pile_01' },
        { label = 'Dumpster', coords = vector3(338.0, -1006.0, 28.5), prop = 'prop_dumpster_01a' },
    },

    target = {
        icon = 'fas fa-box',
        label = 'Check Dead Drop',
        distance = 1.5,
    },
}
