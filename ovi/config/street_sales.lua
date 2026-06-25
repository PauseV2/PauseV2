Config = Config or {}

-- ============================================================
-- Selling drugs to random street NPCs (not OVI contacts).
-- ============================================================

Config.StreetSales = {
    enabled         = true,
    cooldown        = 25,    -- seconds between street sale attempts per player
    sellDistance    = 3.0,
    npcModels       = {
        'a_m_y_hipster_01', 'a_m_y_genstreet_01', 'a_m_y_skater_02',
        'a_f_y_genstreet_01', 'a_f_y_hipster_02', 'a_m_m_skidrow_01',
    },

    -- outcome weights, total doesn't need to be 100, they're relative weights
    outcomes = {
        success       = 55,
        reject        = 20,
        robbery       = 10,
        policeSetup   = 8,
        contactOffer  = 7,
    },

    robbery = {
        weaponChance     = 40, -- % chance the robber pulls a weapon (purely cosmetic scene flag for your animation/combat hook)
        lossPercent      = 100, -- % of the drugs taken on robbery
    },

    policeSetup = {
        alertPolice      = true,
        dispatchMessage  = 'Suspicious hand-to-hand exchange reported',
    },

    contactOffer = {
        chance          = 100, -- % chance once contactOffer outcome is rolled that it actually creates a contact (kept separate so you can layer additional checks)
        requiresOVI      = true,
    },
}
