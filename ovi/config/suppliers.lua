Config = Config or {}

-- ============================================================
-- Unlockable drug suppliers. Restocking buys drug items into the player's
-- inventory at the configured price (config-only - wire `item` to match
-- your drug script's item names, same as config/drugs.lua).
-- ============================================================

Config.Suppliers = {
    weed = {
        label       = 'Weed Supplier',
        item        = 'weed',
        npcModel    = 'g_m_y_mexgoon_01',
        coords      = vector4(1965.0, 3742.0, 32.3, 120.0),
        pricePerUnit = 12,
        maxStock     = 250,
        restockPerHour = 50,
        unlock = { type = 'reputation', amount = 50 },
        cooldownMinutes = 20,
    },
    coke = {
        label       = 'Coke Supplier',
        item        = 'coke',
        npcModel    = 'g_m_y_korlieut_01',
        coords      = vector4(-1380.0, -2710.0, 13.9, 30.0),
        pricePerUnit = 45,
        maxStock     = 150,
        restockPerHour = 25,
        unlock = { type = 'reputation', amount = 150 },
        cooldownMinutes = 30,
    },
    meth = {
        label       = 'Meth Supplier',
        item        = 'meth',
        npcModel    = 'g_m_y_lost_03',
        coords      = vector4(2196.0, 5575.0, 53.5, 70.0),
        pricePerUnit = 35,
        maxStock     = 180,
        restockPerHour = 30,
        unlock = { type = 'reputation', amount = 100 },
        cooldownMinutes = 25,
    },
}
