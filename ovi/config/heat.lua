Config = Config or {}

-- ============================================================
-- Hidden heat value, tracked per phone (IMEI). Drives undercover buyers,
-- tapped-phone risk, surveillance and trap odds.
-- ============================================================

Config.Heat = {
    increments = {
        delivery           = 2,
        policeSighting     = 8,
        failedTrap         = 15,
        complaint          = 6,
        aggressivePricing  = 4,
    },
    decayPerHour = 3,
    min = 0,
    max = 100,

    thresholds = {
        undercoverBuyerChance = { heat = 40, chance = 10 }, -- at heat>=40, 10% chance a "client" is actually undercover
        tappedPhoneChance     = { heat = 60, chance = 8 },
        surveillanceChance    = { heat = 75, chance = 12 },
        trapChanceBonus       = { heat = 50, bonusPercent = 15 }, -- adds to config/traps.lua base chance
    },
}
