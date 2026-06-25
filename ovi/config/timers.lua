Config = Config or {}

-- ============================================================
-- Delivery patience timers. After a deal is accepted the client waits a
-- random window before giving up.
-- ============================================================

Config.Timers = {
    minWaitMinutes = 4,
    maxWaitMinutes = 9,

    warnings = {
        { atPercent = 50, message = 'Where you at?' },
        { atPercent = 80, message = 'You got 2 minutes.' },
        { atPercent = 92, message = "Don't waste my time." },
    },

    timeoutMessage = 'You took too long. I found someone else.',

    timeoutConsequences = {
        cancelDeal        = true,
        trustLoss          = -10,
        complaintChance    = 35, -- %
        contactBurnChance  = 10, -- %
    },
}
