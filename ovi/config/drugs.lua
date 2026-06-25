Config = Config or {}

-- ============================================================
-- Drug catalogue. `item` must match the actual qb-inventory item name used
-- by your drug script - OVI never creates drug items itself, it only
-- reads/removes them from the player's inventory at delivery time.
-- Adjust `item` per drug to match your server's existing item names.
-- ============================================================

Config.Drugs = {
    weed = {
        label       = 'Weed',
        item        = 'weed',
        basePrice   = 25,
        demand      = 70,     -- 0-100, used as a weight when clients pick what to request
        marketMultiplier = 1.0,
    },
    coke = {
        label       = 'Coke',
        item        = 'coke',
        basePrice   = 90,
        demand      = 55,
        marketMultiplier = 1.0,
    },
    meth = {
        label       = 'Meth',
        item        = 'meth',
        basePrice   = 70,
        demand      = 45,
        marketMultiplier = 1.0,
    },
    heroin = {
        label       = 'Heroin',
        item        = 'heroin',
        basePrice   = 110,
        demand      = 30,
        marketMultiplier = 1.0,
    },
    pills = {
        label       = 'Pills',
        item        = 'pills',
        basePrice   = 40,
        demand      = 50,
        marketMultiplier = 1.0,
    },
}

-- Global market drift applied on top of marketMultiplier, recalculated
-- periodically server side (server/heat.lua / server/clients.lua can hook this)
Config.MarketDriftIntervalMinutes = 60
Config.MarketDriftRange = {-0.1, 0.1} -- +/- 10%
