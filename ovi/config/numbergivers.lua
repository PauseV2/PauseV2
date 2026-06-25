Config = Config or {}

-- ============================================================
-- NPCs that approach the player wanting to exchange numbers. Accepting
-- requires a phone with OVI fully installed - the NPC won't deal with
-- anything else, see server/numbergivers.lua.
-- ============================================================

Config.NumberGivers = {
    {
        label    = 'Twitchy Regular',
        model    = 'a_m_y_hipster_01',
        coords   = vector4(-1098.5, -1255.0, 5.0, 130.0),
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        declineLine = 'Please use a different phone, I will only talk on a private connection.',
        target = {
            icon = 'fas fa-phone',
            label = 'They want to exchange numbers',
            distance = 2.0,
        },
    },
}
