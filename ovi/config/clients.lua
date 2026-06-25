Config = Config or {}

-- ============================================================
-- NPC client personalities. Every generated contact rolls one of these
-- personalities, which drives negotiation, patience, trust and complaint
-- behaviour. Numbers are base values - config/negotiation.lua,
-- config/trust.lua and config/timers.lua apply further modifiers on top.
-- ============================================================

Config.Personalities = {
    CheapBuyer = {
        label             = 'Cheap Buyer',
        priceTolerance    = -15,   -- % below base price they expect
        patienceMult      = 1.0,
        aggressionBase    = 10,
        reliability       = 60,
        insultChanceMult  = 1.0,
        walkAwayMult      = 1.2,
        quantityRange     = {1, 4},
        riskLevel         = 'low',
    },
    Addict = {
        label             = 'Addict',
        priceTolerance    = 5,
        patienceMult      = 0.6,    -- impatient
        aggressionBase    = 35,
        reliability       = 40,
        insultChanceMult  = 1.4,
        walkAwayMult      = 0.7,
        quantityRange     = {1, 3},
        riskLevel         = 'medium',
    },
    Dealer = {
        label             = 'Dealer',
        priceTolerance    = -5,
        patienceMult      = 1.1,
        aggressionBase    = 20,
        reliability       = 75,
        insultChanceMult  = 0.8,
        walkAwayMult      = 1.0,
        quantityRange     = {5, 15},
        riskLevel         = 'medium',
    },
    RichClient = {
        label             = 'Rich Client',
        priceTolerance    = 25,
        patienceMult      = 1.4,
        aggressionBase    = 5,
        reliability       = 85,
        insultChanceMult  = 0.5,
        walkAwayMult      = 0.8,
        quantityRange     = {2, 8},
        riskLevel         = 'low',
    },
    ParanoidClient = {
        label             = 'Paranoid Client',
        priceTolerance    = 0,
        patienceMult      = 0.8,
        aggressionBase    = 25,
        reliability       = 55,
        insultChanceMult  = 1.1,
        walkAwayMult      = 1.6,       -- bails easily if anything feels off
        quantityRange     = {1, 5},
        riskLevel         = 'high',
    },
}

-- Name pools used when generating a brand new NPC contact
Config.ClientNames = {
    first = {
        'Marcus', 'Dante', 'Lena', 'Jaylen', 'Priya', 'Carlos', 'Whitney', 'Boon',
        'Stevie', 'Nadia', 'Rocco', 'Tash', 'Eli', 'Sierra', 'Kenji', 'Marisol',
    },
    last = {
        'Vance', 'Reyes', 'Okafor', 'Bishop', 'Calloway', 'Trinh', 'Marsh',
        'Delgado', 'Hux', 'Petrov', 'Lindqvist', 'Sato', 'Nakamura', 'Cole',
    },
}

Config.ClientGeneration = {
    minTrustStart   = 0,
    maxTrustStart   = 10,
    minLoyaltyStart = 0,
    maxLoyaltyStart = 5,

    -- how often (minutes) each active contact rolls a chance to send a new delivery request
    requestIntervalMinutes = 12,
    requestChance          = 20, -- %
}
