Config = {}

Config.StartingMoney = {
    cash = 500,
    bank = 2500,
}

-- how many character slots a single license gets
Config.MaxCharacterSlots = 3

Config.CitizenIdPrefix = 'OX'
Config.CitizenIdLength = 6 -- random chars appended after the prefix

-- delete = remove the row entirely, soft = flag as deleted but keep the row
Config.CharacterDeleteMode = 'soft'

Config.DefaultSpawn = { x = 215.6, y = -810.4, z = 30.7, w = 205.0 }

Config.AutoSaveIntervalMs = 5 * 60 * 1000

Config.DefaultMetadata = {
    health = 200,
    armor = 0,
    hunger = 100,
    thirst = 100,
    stress = 0,
    isdead = false,
}
