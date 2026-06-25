Config = Config or {}

-- ============================================================
-- Unsolicited "got your number from someone" texts to OVI-enabled phones.
-- ============================================================

Config.RandomContacts = {
    enabled         = true,
    intervalMinutes = 35,  -- how often each OVI phone rolls for one of these
    chance          = 8,   -- % chance per roll

    openingLine = 'Got your number from someone. Need work.',

    outcomes = {
        -- relative weights
        legitClient   = 55,
        robberySetup  = 15,
        policeSting   = 15,
        rivalGangTrap = 15,
    },
}
