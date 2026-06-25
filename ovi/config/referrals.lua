Config = Config or {}

-- ============================================================
-- Referral system: successful clients introduce new contacts over time.
-- ============================================================

Config.Referrals = {
    requiredDeliveries = 5,   -- successful deliveries to the same contact before a referral can roll
    chance             = 25, -- % chance checked after hitting requiredDeliveries (and each delivery after)
    maxReferrals       = 3,  -- max new contacts a single client can ever generate
    qualityWeights = {
        -- chance the referral is generated with each personality, relative weights
        CheapBuyer     = 25,
        Addict         = 20,
        Dealer         = 20,
        RichClient     = 15,
        ParanoidClient = 20,
    },
}
