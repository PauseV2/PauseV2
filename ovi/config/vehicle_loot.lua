Config = Config or {}

-- ============================================================
-- Loot tables rolled when a player searches a trap vehicle after winning
-- an ambush. `item` names must exist in your inventory; OVI's own loot
-- items (ovi_installkey, ovi_cryptowallet, ovi_fakeid) are defined in
-- shared/items.lua.
-- ============================================================

Config.VehicleLoot = {
    rolls = {2, 4}, -- min/max number of items rolled per trap vehicle

    table = {
        { item = 'cash',              min = 200, max = 1500, weight = 35, rarity = 'common' },
        { item = 'ovi_burner',        min = 1,   max = 2,    weight = 25, rarity = 'common' },
        { item = 'weapon_parts',     min = 1,   max = 3,    weight = 15, rarity = 'uncommon' },
        { item = 'ovi_fakeid',        min = 1,   max = 1,    weight = 12, rarity = 'uncommon' },
        { item = 'ovi_stashkey',      min = 1,   max = 1,    weight = 8,  rarity = 'rare' },
        { item = 'ovi_cryptowallet',  min = 1,   max = 1,    weight = 6,  rarity = 'rare' },
        { item = 'ovi_installkey',    min = 1,   max = 1,    weight = 3,  rarity = 'legendary' },
    },
}
