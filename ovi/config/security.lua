Config = Config or {}

-- ============================================================
-- PIN / lockout / self-destruct security settings.
-- ============================================================

Config.Security = {
    maxPinAttempts      = 3,     -- wrong PIN entries before lockout
    lockoutTime         = 300,   -- seconds the phone is locked after max attempts
    selfWipeOnLockout   = true,  -- roll wipeChance (config/phones.lua) when locked out
    wipeWipesContacts   = true,
    wipeWipesMessages   = true,
    wipeWipesDeliveries = false, -- delivery history kept for trust/heat integrity
    gpsBeaconOnWipe     = true,  -- broadcasts a one-time GPS ping to police on wipe
    policePingChance    = 15,    -- % chance a wrong PIN attempt itself pings police
    pinLength           = 4,
    accessCodeLength    = 12,    -- length of the first-time setup code an installer NPC hands out
}
