Config = Config or {}

-- ============================================================
-- Trust / loyalty point economy.
-- ============================================================

Config.Trust = {
    gains = {
        onTime       = 4,
        fairPricing  = 3,
        rightProduct = 5,
        goodQuality  = 2,
    },
    losses = {
        overpricing      = -4,
        noShow           = -10,
        fakeProduct      = -15,
        ignoring         = -6,
        repeatedDeclines = -3,
    },
    loyaltyGainPerSuccess = 2,
    loyaltyLossPerFailure = 3,

    blacklistThreshold = -40,  -- trust at/below this = contact refuses to deal permanently
    burnThreshold       = -70, -- trust at/below this = contact actively complains/burns the seller
    minTrust            = -100,
    maxTrust            = 100,

    recoveryRatePerHour = 1,   -- passive trust drift back toward 0 over time
}
