Config = {}

Config.MaxWeight = 30000 -- grams
Config.MaxSlots = 30

Config.Stashes = {
    evidence_locker = {
        label = 'Evidence Locker',
        slots = 50,
        maxWeight = 100000,
        coords = { x = 462.59, y = -996.79, z = 30.69 },
    },
}

Config.StashRange = 2.0 -- meters, how close a player must be to open a stash
Config.GiveRange = 3.0 -- meters, how close another player must be to receive a give
Config.DropProp = 'prop_paper_bag_01' -- world prop used for every dropped item, regardless of item type

Config.TrunkRange = 2.5 -- meters, how close a player must be to a vehicle to open its trunk
Config.TrunkMaxWeight = 40000 -- grams
Config.TrunkSlots = 40
