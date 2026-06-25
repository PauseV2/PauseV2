Config = Config or {}

-- ============================================================
-- Complaint network: bad experiences spread between a client's other
-- contacts/referrals, making future negotiation harder for the seller.
-- ============================================================

Config.Complaints = {
    chance        = 30,    -- % chance a negative event generates a complaint at all
    spreadRadius  = 2,     -- how many "hops" through referral/shared links a complaint propagates
    durationHours = 48,    -- complaint impact decays after this long
    severityLevels = {
        minor  = { trustPenalty = -3,  negotiationPenaltyPercent = 5 },
        major  = { trustPenalty = -8,  negotiationPenaltyPercent = 15 },
        severe = { trustPenalty = -20, negotiationPenaltyPercent = 30 },
    },
}
