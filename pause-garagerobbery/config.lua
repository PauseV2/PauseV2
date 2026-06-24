--[[
    pause-garagerobbery
    ---------------------------------------------------------------
    Garage / mechanic shop robbery system for QBCore.

    INSTALL NOTES
    - Add the items referenced below to your qb-core/shared/items.lua
      (engine_part, brake_part, turbo_part, transmission_part,
      suspension_part, car_battery, ecu_chip, nitro_bottle, crowbar,
      lockpick, advancedlockpick, weaponrepairkit -> repairkit,
      cuttingtorch, metalscrap, rubber, plastic, copper, steel,
      tirefixed/wheel/plate are treated as scrapped components, not
      items, so they do not need item defs).
    - All "shell" coordinates below are PLACEHOLDERS. They define a
      single physical location per tier that every garage of that
      tier is instanced into via routing buckets (see client/garage.lua
      + server/garage.lua). Point them at an interior shell you own
      (MLO, map-editor room, or a quiet patch of the map) before
      going live.
    ---------------------------------------------------------------
]]

Config = {}

-- ============================================================
--  GENERAL
-- ============================================================
Config.Debug = false

Config.Bridge = {
    Target          = 'qb-target',         -- qb-target / ox_target (ox_target API differs, adapt Bridge.AddTargetEntity / AddTargetZone in client/main.lua)
    Inventory       = 'qb-inventory',
    Minigames       = 'qb-minigames',
    Police          = 'qb-policejob',
    Progressbar     = 'progressbar',       -- 'progressbar' export resource, or 'qb' to use QBCore.Functions.Progressbar
    UseQBMinigames  = false,                -- false = use the built-in fallback hacking minigame in client/hacking.lua
}

Config.PoliceJobs = { 'police', 'sheriff' } -- job names treated as "police" for dispatch / camera access

-- ============================================================
--  COOLDOWNS / ANTI-ABUSE
-- ============================================================
Config.Cooldowns = {
    PerGarage          = 45 * 60,   -- seconds a single garage stays on cooldown after an attempt starts
    GlobalPerPlayer     = 4 * 60,   -- seconds a player must wait between starting ANY garage robbery
    StartCooldownOnEntry = true,    -- true = cooldown starts the moment the player breaches the garage, false = on exit/completion
    SearchSpotReuse     = false,    -- if true, a looted spot can be searched again after the garage resets (next attempt), otherwise spots never re-roll within the same instance (always true per-instance)
}

Config.AntiAbuse = {
    MaxInteractDistance   = 3.0,    -- max distance (m) allowed between player ped and a target point for any server validated action
    MaxVehicleDistance    = 4.0,    -- max distance (m) allowed between player and a vehicle for scrapping actions
    EventRateLimitMs      = 500,    -- minimum ms between repeated calls of the same server event per player
    MaxActiveInstances    = 1,      -- max concurrent garage instances a single player may be inside
    RequireServerOwnedVeh = true,   -- scrapping only allowed on vehicles spawned by this script for the instance
}

-- ============================================================
--  HACKING / ELECTRICAL BOX / CAMERAS
-- ============================================================
Config.HackSettings = {
    Difficulty            = 'medium',      -- 'easy' | 'medium' | 'hard' -> tunes the built-in minigame (rounds/time/tolerance)
    HackTimeLimit         = 20000,         -- ms allowed to complete the hack before it auto-fails
    HackCooldown          = 6 * 60,        -- seconds before the same electrical box can be hacked again
    CameraDisableDuration  = 8 * 60,       -- seconds cameras stay disabled after a successful hack
    MaxAttemptsBeforeLockout = 2,          -- failed hacks before the box temporarily locks out
    LockoutDuration        = 90,           -- seconds the box is locked out after too many failures
    PoliceAlertChanceOnFail = 65,          -- % chance police get alerted when a hack attempt FAILS
    PoliceAlertChanceNoHack = 100,         -- % chance police get alerted when a player skips hacking and breaches anyway
    RequiredItem            = nil,         -- e.g. 'electronickit' -- set to an item name to require a tool to even attempt the hack, nil = no item required
    ConsumeRequiredItem     = false,
}

-- ============================================================
--  POLICE INTEGRATION
-- ============================================================
Config.PoliceSettings = {
    RequiredOnlineToTriggerAlert = 0,      -- minimum on-duty police online before alerts are sent (0 = always send)
    DispatchEvent          = 'police:client:DispatchAlert', -- change to match your dispatch resource, leave nil to use built-in notify+blip fallback
    UseBuiltInFallback     = true,         -- if true, also runs the built-in blip/notify dispatch regardless of DispatchEvent
    BlipSprite             = 161,
    BlipColor              = 1,
    BlipScale              = 1.2,
    BlipDuration           = 90,           -- seconds the dispatch blip stays on police MDT/map
    AllowCameraViewWhenActive = true,      -- police can "view" live cameras (hook point for your camera resource) when not disabled
    CameraResource         = nil,          -- name of a camera resource to integrate with (hook in client/police.lua), nil = notify only
    EvidenceChance         = 35,           -- % chance a piece of evidence (fingerprint/blood) is left per loot/scrap action
    RaidSystem = {
        Enabled            = true,
        RequiredPoliceCount = 1,           -- minimum on-duty police needed before a raid can be called
        Cooldown           = 5 * 60,       -- seconds between raid calls on the same instance
    },
}

-- ============================================================
--  GARAGE SHELL TIERS
-- ============================================================
-- vehicleSpawns / lootSpots use coordinates RELATIVE TO NOTHING -- they
-- are absolute world coordinates inside the shell location for that tier.
Config.Tiers = {
    [1] = {
        label             = 'Small Garage',
        vehicleSpawnCount = 1,
        rewardMultiplier  = 1.0,
        lootTable         = 1,
        searchTimeMs      = 4000,
        minPolice         = 0,
    },
    [2] = {
        label             = 'Medium Workshop',
        vehicleSpawnCount = 2,
        rewardMultiplier  = 1.6,
        lootTable         = 2,
        searchTimeMs      = 5500,
        minPolice         = 1,
    },
    [3] = {
        label             = 'Large Mechanic Shop',
        vehicleSpawnCount = 3,
        rewardMultiplier  = 2.4,
        lootTable         = 3,
        searchTimeMs      = 7000,
        minPolice         = 2,
    },
}

-- Shell interiors. One physical location per tier, reused by every
-- garage of that tier and isolated per-attempt via routing buckets.
Config.Shells = {
    [1] = {
        playerSpawn = vector4(1138.0, -3199.0, -38.99, 250.0), -- TODO: point at your tier 1 interior
        exitPoint   = vector4(1140.5, -3199.0, -38.99, 70.0),
        lootSpots = {
            { coords = vector4(1135.2, -3196.4, -38.99, 0.0), model = 'prop_tool_box_01',  label = 'Toolbox' },
            { coords = vector4(1136.8, -3201.1, -38.99, 0.0), model = 'prop_cabinet_03',   label = 'Cabinet' },
            { coords = vector4(1139.9, -3203.4, -38.99, 0.0), model = 'prop_consolebox04', label = 'Parts Bin' },
        },
        vehicleSpawns = {
            vector4(1142.0, -3201.5, -38.99, 160.0),
        },
    },
    [2] = {
        playerSpawn = vector4(948.0, -2107.0, 30.45, 70.0), -- TODO: point at your tier 2 interior
        exitPoint   = vector4(951.0, -2106.0, 30.45, 250.0),
        lootSpots = {
            { coords = vector4(944.6, -2103.8, 30.45, 0.0), model = 'prop_tool_box_05',     label = 'Toolbox' },
            { coords = vector4(946.1, -2109.7, 30.45, 0.0), model = 'prop_cabinet_03',      label = 'Cabinet' },
            { coords = vector4(950.4, -2112.0, 30.45, 0.0), model = 'prop_shelves_03',      label = 'Storage Shelf' },
            { coords = vector4(953.7, -2104.6, 30.45, 0.0), model = 'prop_consolebox04',    label = 'Parts Bin' },
            { coords = vector4(940.9, -2108.9, 30.45, 0.0), model = 'prop_table_03',        label = 'Workbench' },
        },
        vehicleSpawns = {
            vector4(947.0, -2114.0, 30.45, 200.0),
            vector4(955.0, -2108.0, 30.45, 110.0),
        },
    },
    [3] = {
        playerSpawn = vector4(-206.0, -1313.0, 31.3, 230.0), -- TODO: point at your tier 3 interior (e.g. Benny's-style MLO)
        exitPoint   = vector4(-202.0, -1310.0, 31.3, 50.0),
        lootSpots = {
            { coords = vector4(-210.4, -1309.6, 31.3, 0.0), model = 'prop_tool_box_05',  label = 'Toolbox' },
            { coords = vector4(-213.8, -1314.2, 31.3, 0.0), model = 'prop_cabinet_03',   label = 'Cabinet' },
            { coords = vector4(-208.1, -1318.7, 31.3, 0.0), model = 'prop_shelves_03',   label = 'Storage Shelf' },
            { coords = vector4(-203.5, -1320.4, 31.3, 0.0), model = 'prop_consolebox04', label = 'Parts Bin' },
            { coords = vector4(-198.7, -1316.9, 31.3, 0.0), model = 'prop_table_03',     label = 'Workbench' },
            { coords = vector4(-200.2, -1308.3, 31.3, 0.0), model = 'prop_tool_chest_01',label = 'Tool Chest' },
        },
        vehicleSpawns = {
            vector4(-215.0, -1320.0, 31.3, 300.0),
            vector4(-205.0, -1323.0, 31.3, 30.0),
            vector4(-195.0, -1313.0, 31.3, 140.0),
        },
    },
}

-- ============================================================
--  GARAGE LOCATIONS (the actual map entrances / electrical boxes)
-- ============================================================
Config.Garages = {
    {
        id            = 'sandy_garage_01',
        label         = "Sandy Shores Garage",
        tier          = 1,
        entry         = vector4(1731.7, 3700.4, 34.16, 210.0),
        electricalBox = vector4(1727.9, 3704.1, 34.16, 130.0),
        blip          = { sprite = 446, color = 1, scale = 0.8 },
    },
    {
        id            = 'lsc_workshop_01',
        label         = "La Mesa Workshop",
        tier          = 2,
        entry         = vector4(896.9, -2110.3, 30.45, 0.0),
        electricalBox = vector4(901.4, -2106.6, 30.45, 300.0),
        blip          = { sprite = 446, color = 5, scale = 0.8 },
    },
    {
        id            = 'elmills_mechanic_01',
        label         = "El Burro Heights Mechanic Shop",
        tier          = 3,
        entry         = vector4(1187.9, -3137.8, 5.9, 50.0),
        electricalBox = vector4(1183.5, -3133.2, 5.9, 310.0),
        blip          = { sprite = 446, color = 2, scale = 0.9 },
    },
}

-- ============================================================
--  LOOT TABLES (tier indexed)
-- chance = % roll per search, min/max = quantity, rare = flagged for UI/notify only
-- ============================================================
Config.LootTables = {
    [1] = {
        { item = 'metalscrap',   min = 1, max = 3, chance = 60, rare = false },
        { item = 'rubber',       min = 1, max = 2, chance = 45, rare = false },
        { item = 'plastic',      min = 1, max = 2, chance = 45, rare = false },
        { item = 'lockpick',     min = 1, max = 1, chance = 30, rare = false },
        { item = 'crowbar',      min = 1, max = 1, chance = 20, rare = false },
        { item = 'wrench',       min = 1, max = 1, chance = 25, rare = false },
        { item = 'brake_part',   min = 1, max = 1, chance = 18, rare = false },
        { item = 'battery',      min = 1, max = 1, chance = 12, rare = false },
        { item = 'copper',       min = 1, max = 2, chance = 20, rare = false },
        { item = 'nitro_bottle', min = 1, max = 1, chance = 4,  rare = true  },
    },
    [2] = {
        { item = 'metalscrap',        min = 2, max = 4, chance = 55, rare = false },
        { item = 'steel',             min = 1, max = 3, chance = 40, rare = false },
        { item = 'copper',            min = 1, max = 3, chance = 40, rare = false },
        { item = 'rubber',            min = 1, max = 3, chance = 40, rare = false },
        { item = 'advancedlockpick',  min = 1, max = 1, chance = 22, rare = false },
        { item = 'repairkit',         min = 1, max = 1, chance = 20, rare = false },
        { item = 'cuttingtool',       min = 1, max = 1, chance = 18, rare = false },
        { item = 'turbo_part',        min = 1, max = 1, chance = 14, rare = false },
        { item = 'transmission_part', min = 1, max = 1, chance = 12, rare = false },
        { item = 'suspension_part',   min = 1, max = 1, chance = 14, rare = false },
        { item = 'ecu_chip',          min = 1, max = 1, chance = 8,  rare = true  },
        { item = 'nitro_bottle',      min = 1, max = 2, chance = 8,  rare = true  },
    },
    [3] = {
        { item = 'steel',             min = 2, max = 5, chance = 55, rare = false },
        { item = 'copper',            min = 2, max = 4, chance = 50, rare = false },
        { item = 'plastic',           min = 1, max = 3, chance = 35, rare = false },
        { item = 'advancedlockpick',  min = 1, max = 2, chance = 28, rare = false },
        { item = 'repairkit',         min = 1, max = 2, chance = 25, rare = false },
        { item = 'cuttingtool',       min = 1, max = 1, chance = 22, rare = false },
        { item = 'turbo_part',        min = 1, max = 1, chance = 20, rare = false },
        { item = 'transmission_part', min = 1, max = 1, chance = 18, rare = false },
        { item = 'engine_part',       min = 1, max = 1, chance = 18, rare = false },
        { item = 'ecu_chip',          min = 1, max = 1, chance = 14, rare = true  },
        { item = 'nitro_bottle',      min = 1, max = 2, chance = 14, rare = true  },
    },
}

-- ============================================================
--  VEHICLE SCRAPPING
-- ============================================================
-- boneFlag is only descriptive (kept for reference / future use),
-- removal is handled with dedicated natives per part type in
-- client/scrapping.lua (BreakOffVehicleWheel / SetVehicleDoorBroken).
Config.VehicleParts = {
    wheel = {
        label        = 'Wheels',
        type         = 'wheel',
        durationMs   = 6000,
        successChance = 85,
        requiredItem = 'wrench',
        consumeItem  = false,
        rewardItem   = 'tire',
        rewardMin    = 1,
        rewardMax    = 1,
        indices      = { 0, 1, 2, 3 }, -- wheel indices, 6/7 added automatically for big rigs in code
    },
    plate = {
        label        = 'License Plate',
        type         = 'plate',
        durationMs   = 3000,
        successChance = 95,
        requiredItem = 'crowbar',
        consumeItem  = false,
        rewardItem   = 'plate',
        rewardMin    = 1,
        rewardMax    = 1,
    },
    door = {
        label        = 'Doors',
        type         = 'door',
        durationMs   = 7000,
        successChance = 80,
        requiredItem = 'wrench',
        consumeItem  = false,
        rewardItem   = 'door_part',
        rewardMin    = 1,
        rewardMax    = 1,
        indices      = { 0, 1, 2, 3 },
    },
    hood = {
        label        = 'Hood',
        type         = 'hood',
        durationMs   = 6500,
        successChance = 80,
        requiredItem = 'crowbar',
        consumeItem  = false,
        rewardItem   = 'hood_part',
        rewardMin    = 1,
        rewardMax    = 1,
        boneIndex    = 4,
    },
    trunk = {
        label        = 'Trunk',
        type         = 'trunk',
        durationMs   = 6500,
        successChance = 80,
        requiredItem = 'crowbar',
        consumeItem  = false,
        rewardItem   = 'trunk_part',
        rewardMin    = 1,
        rewardMax    = 1,
        boneIndex    = 5,
    },
    engine = {
        label        = 'Engine Parts',
        type         = 'engine',
        durationMs   = 9000,
        successChance = 65,
        requiredItem = 'cuttingtool',
        consumeItem  = false,
        rewardItem   = 'engine_part',
        rewardMin    = 1,
        rewardMax    = 1,
        requiresHoodRemoved = true,
    },
}

-- Order parts are exposed in the scrap menu, and which vehicle this
-- part type can be removed from more than once (e.g. wheels x4)
Config.ScrapMenuOrder = { 'plate', 'hood', 'trunk', 'door', 'wheel', 'engine' }

-- ============================================================
--  MATERIAL PROCESSING / SELLING
-- ============================================================
-- Scrap a looted/removed component down into raw crafting materials.
Config.ScrapRewards = {
    tire       = { { item = 'rubber',     min = 1, max = 2 }, { item = 'metalscrap', min = 1, max = 1 } },
    plate      = { { item = 'metalscrap', min = 1, max = 1 } },
    door_part  = { { item = 'steel',      min = 1, max = 2 }, { item = 'plastic',    min = 1, max = 1 } },
    hood_part  = { { item = 'steel',      min = 1, max = 2 } },
    trunk_part = { { item = 'steel',      min = 1, max = 2 } },
    engine_part = { { item = 'steel',     min = 1, max = 2 }, { item = 'copper',     min = 1, max = 2 } },
}

-- Direct sale prices (per unit, before tier rewardMultiplier is applied)
Config.SellPrices = {
    tire        = { min = 40,  max = 70 },
    plate       = { min = 15,  max = 30 },
    door_part   = { min = 120, max = 220 },
    hood_part   = { min = 100, max = 180 },
    trunk_part  = { min = 90,  max = 160 },
    engine_part = { min = 250, max = 450 },
    turbo_part  = { min = 220, max = 380 },
    transmission_part = { min = 200, max = 360 },
    suspension_part   = { min = 140, max = 240 },
    brake_part  = { min = 80,  max = 140 },
    ecu_chip    = { min = 300, max = 520 },
    nitro_bottle = { min = 180, max = 320 },
    battery     = { min = 60,  max = 100 },
}

Config.Selling = {
    SellAtExit  = true,    -- adds a "Sell Stolen Parts" qb-target option at the shell exit point
    PaymentType = 'cash',  -- 'cash' or 'bank'
}

-- ============================================================
--  REQUIRED ITEMS (quick reference, also embedded above)
-- ============================================================
Config.RequiredItems = {
    hackbox        = Config.HackSettings.RequiredItem,
    wheel          = Config.VehicleParts.wheel.requiredItem,
    plate          = Config.VehicleParts.plate.requiredItem,
    door           = Config.VehicleParts.door.requiredItem,
    hood           = Config.VehicleParts.hood.requiredItem,
    trunk          = Config.VehicleParts.trunk.requiredItem,
    engine         = Config.VehicleParts.engine.requiredItem,
}

-- ============================================================
--  MISC / VEHICLE MODELS USED FOR SCRAP SPAWNS PER TIER
-- ============================================================
Config.ScrapVehicleModels = {
    [1] = { 'blista', 'asea', 'panto' },
    [2] = { 'sentinel', 'tailgater', 'fugitive', 'primo' },
    [3] = { 'sultan', 'schafter2', 'felon', 'jester', 'oracle' },
}

Config.Locales = {
    must_hack_first        = "You should disable the electrical box first.",
    hack_success           = "Cameras disabled for a while.",
    hack_failed            = "The hack failed!",
    hack_locked_out        = "The panel is locked, try again later.",
    garage_on_cooldown     = "This place was hit recently, come back later.",
    player_on_cooldown     = "You need to lay low before trying again.",
    entered_garage         = "You breached the garage.",
    not_enough_police      = "Not enough police online.",
    searching              = "Searching...",
    search_empty           = "Found nothing useful.",
    found_item             = "You found %sx %s",
    no_required_item       = "You don't have the required tool.",
    scrapping              = "Removing part...",
    scrap_success          = "Removed the %s.",
    scrap_failed           = "You failed to remove the %s.",
    sold_items             = "Sold parts for $%s",
    too_far                = "You're too far away.",
    instance_full          = "You're already inside another robbery.",
}
