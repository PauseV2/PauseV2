Config = Config or {}

-- ============================================================
-- Coded slang clients use instead of saying drug names outright.
-- server/codes.lua randomly substitutes these into generated request
-- messages and also detects them when parsing a player's reply.
-- ============================================================

Config.Codes = {
    coke = {'white shirts', 'snow', 'flour', 'the white stuff'},
    weed = {'green', 'bud', 'plants', 'the loud'},
    meth = {'ice', 'glass', 'clear'},
    heroin = {'brown sugar', 'tar', 'the brown'},
    pills = {'beans', 'candy', 'skittles'},
}

Config.CodeLanguageChance = 55 -- % chance a generated request uses a code word instead of the real name
