Config = Config or {}

-- ============================================================
-- Free-type negotiation parser settings. Player types a chat-style message
-- into the OVI app; server/negotiation.lua tokenizes it looking for the
-- keyword groups below plus any number it can find for a counter offer.
-- ============================================================

Config.Negotiation = {
    maxPriceTolerancePercent = 20,  -- how far above their tolerance a client will still consider
    urgencyMultiplier         = 1.15, -- price/patience swing when urgency keywords are detected
    trustBonusPercent         = 0.5,  -- % extra tolerance per trust point
    loyaltyBonusPercent       = 0.3,  -- % extra tolerance per loyalty point
    insultChance              = 12,   -- % chance a bad offer triggers an insult instead of a plain reject
    walkAwayChance            = 18,   -- % chance a bad offer makes the client cancel outright

    keywords = {
        counterOffer = {
            'i want', 'need', 'minimum', 'min', 'can do', 'only pay', 'best i can do',
            'final offer', 'lowest', 'highest',
        },
        urgency = {
            'now', 'asap', 'quick', 'hurry', 'rush', 'urgent', 'fast', 'right now',
        },
        qualityClaim = {
            'premium', 'top shelf', 'pure', 'best quality', 'fire', 'clean', 'A grade', 'grade a',
        },
        quantityChange = {
            'only got', 'just have', 'can only bring', 'instead of', 'change it to',
        },
        rude = {
            'fuck', 'scam', 'rip off', 'ripoff', 'stupid', 'idiot',
        },
    },

    -- straight number pattern grabbed from the message is treated as the counter price
    -- unless preceded by a quantity keyword, in which case it's treated as quantity.
}
