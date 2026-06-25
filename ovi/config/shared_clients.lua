Config = Config or {}

-- ============================================================
-- Shared contacts: the same NPC client can be known by multiple players.
-- When that client wants drugs, all eligible owning players get the text;
-- first to accept wins, the rest get a "Already handled." reply.
-- ============================================================

Config.SharedClients = {
    enabled        = true,
    maxCompetitors = 4,       -- max players notified at once for the same request
    priorityLogic  = 'first_accept', -- 'first_accept' | 'highest_trust' | 'nearest'
    alreadyHandledMessage = 'Already handled.',
}
