Config = Config or {}

-- ============================================================
-- OVI - Onderworld Connection Interface
-- Master toggle file. Flip any system on/off without touching
-- core code. All other config/*.lua files hold the detailed
-- settings for the system they're named after.
-- ============================================================

Config.Debug = false -- print debug info to server console

Config.Toggle = {
    Phones            = true,  -- physical burner phone items (required for everything else)
    OVIInstaller      = true,  -- NPCs that install OVI onto a phone
    Security          = true,  -- PIN lockouts / self wipe / GPS beacon
    StreetSales       = true,  -- selling drugs to random street NPCs
    Negotiation       = true,  -- free-type negotiation parser
    Trust              = true, -- trust/loyalty system
    Timers            = true,  -- delivery patience timers
    Complaints        = true,  -- complaint network
    Referrals         = true,  -- referral system
    SharedClients     = true,  -- multiple players can own the same contact
    ClientReplacement = true,  -- auto replace a seller who fails a deal
    Heat              = true,  -- hidden heat/suspicion system
    DeadDrops         = true,  -- qb-target dead drop deliveries
    RandomContacts    = true,  -- unsolicited "got your number" texts
    Traps             = true,  -- ambush meetings
    Suppliers         = true,  -- unlockable drug suppliers
    Ghosting          = true,  -- clients going offline/arrested/hiding/dead
    NetworkStatus     = true,  -- global "connection stable/raided" status, flip live with /oviraid
    PoliceEvidence    = true,  -- exports for police scripts to read seized phones
    Cloning           = true,  -- phone backup/clone NPC
    CodeLanguage      = true,  -- coded slang for drugs in client messages
    NumberGivers      = true,  -- qb-target NPCs that hand out their number to a player's OVI phone
}

-- Command used as a manual fallback to open OVI on the phone currently held
-- (in addition to using the physical item / qb-phone app icon)
Config.OpenCommand = 'ovi'

-- citizenid-based identifiers are never used to store phone data.
-- Everything criminal lives on the phone's IMEI - see server/phones.lua
Config.IdentifierPrefix = 'OVI'
