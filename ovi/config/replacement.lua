Config = Config or {}

-- ============================================================
-- Client replacement: if a seller fails a deal (timeout/no-show/bad product)
-- the NPC can automatically look for another eligible seller instead of
-- just disappearing.
-- ============================================================

Config.Replacement = {
    enabled        = true,
    priority       = 'trust',  -- 'trust' | 'distance' | 'longest_relationship'
    cooldownSeconds = 120,     -- delay before the client starts looking for a replacement
    maxAttempts    = 3,        -- how many replacement sellers it will try before giving up entirely
}
