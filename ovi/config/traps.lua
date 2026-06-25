Config = Config or {}

-- ============================================================
-- Ambush meetings. A delivery can turn into a trap; if the player survives
-- they can loot the trap vehicle (see config/vehicle_loot.lua).
-- ============================================================

Config.Traps = {
    baseChance        = 12,  -- % base chance any face-to-face meet is a trap (heat adds on top, see config/heat.lua)
    ambushNpcCount    = {2, 4},
    npcWeapons        = {'WEAPON_PISTOL', 'WEAPON_MICROSMG'},
    npcAccuracy       = 35,    -- 0-100 passed to SET_PED_ACCURACY
    npcCombatAbility  = 1,     -- 0=Poor 1=Average 2=Professional
    vehicleModels     = {'sentinel', 'primo', 'asea'},
    vehicleSpawnDistance = 25.0,

    winRewardMultiplier = 1.0, -- multiplies the original delivery payout if the player wins the trap

    fleeRadius = 80.0,    -- if the player gets this far away, ambush NPCs despawn instead of chasing forever
}
