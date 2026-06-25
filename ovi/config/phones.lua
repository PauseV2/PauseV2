Config = Config or {}

-- ============================================================
-- Phone types. item must already exist in qb-core/shared/items.lua
-- (see shared/items.lua in this resource for the exact snippet to paste in).
-- Every phone is a unique physical item: data is keyed by IMEI, never by
-- citizenid, so dropping/stealing/trading a phone carries its identity with it.
-- ============================================================

Config.Phones = {
    ['ovi_burner'] = {
        label              = 'Cheap Burner',
        price              = 75,
        shopItem           = 'ovi_burner',
        durability         = 35,        -- % lost per "risky" event (wrong pin, trap, police seize attempt)
        maxContacts        = 8,
        maxMessages        = 60,
        encryption         = 1,         -- 1 = weak .. 3 = strong, affects police/heat odds
        oviSupport         = true,
        wipeChance         = 35,        -- % chance to fully wipe on destruction trigger
        gpsAccuracy        = 'low',
        canBeCloned        = true,
    },
    ['ovi_midburner'] = {
        label              = 'Mid-Tier Encrypted Burner',
        price              = 350,
        shopItem           = 'ovi_midburner',
        durability         = 65,
        maxContacts        = 20,
        maxMessages        = 150,
        encryption         = 2,
        oviSupport         = true,
        wipeChance         = 15,
        gpsAccuracy        = 'medium',
        canBeCloned        = true,
    },
    ['ovi_ghostphone'] = {
        label              = 'Premium Ghost Phone',
        price              = 1200,
        shopItem           = 'ovi_ghostphone',
        durability         = 100,
        maxContacts        = 60,
        maxMessages        = 400,
        encryption         = 3,
        oviSupport         = true,
        wipeChance         = 5,
        gpsAccuracy        = 'spoofed', -- GPS logs report fake coordinates to anyone but the owner
        canBeCloned        = true,
    },
}

-- Number generation used when a phone is first created / OVI installed
Config.PhoneNumberFormat = {
    prefix = {'555', '666', '777'},
    length = 7, -- digits after the prefix
}
