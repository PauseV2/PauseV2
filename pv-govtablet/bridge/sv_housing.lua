--[[
    Housing bridge
    --------------
    Default implementation targets qb-houses' `player_houses` table
    (columns: citizenid, house[, garage]). If your server runs a
    different housing resource (loaf-housing, ps-housing, qb-apartments,
    ...) adjust the table/column names in Config.Bridge.Housing and the
    queries below - the rest of the resource only talks to this file.

    Seizing a property never deletes data destructively: the original
    ownership row is snapshotted into gt_property_seizures before being
    removed, so `RestoreProperty` can put it back exactly as it was.
]]

Housing = {}

local cfg = Config.Bridge.Housing

local tableExistsCache = {}
local function tableExists(tableName)
    if tableExistsCache[tableName] ~= nil then return tableExistsCache[tableName] end
    local row = MySQL.single.await('SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ? LIMIT 1', { tableName })
    tableExistsCache[tableName] = row ~= nil
    return tableExistsCache[tableName]
end

function Housing.GetProperties(citizenid)
    local properties = {}
    if not tableExists(cfg.HousesTable) then return properties end

    local rows = MySQL.query.await(('SELECT * FROM `%s` WHERE `%s` = ?'):format(cfg.HousesTable, cfg.CitizenField), { citizenid })
    if not rows or #rows == 0 then return properties end

    local houseKeys = {}
    for _, row in ipairs(rows) do houseKeys[#houseKeys + 1] = row[cfg.HouseField] end

    local placeholders = string.rep('?,', #houseKeys):sub(1, -2)
    local catalogRows = MySQL.query.await(('SELECT * FROM gt_properties WHERE house IN (%s)'):format(placeholders), houseKeys)
    local catalogByHouse = {}
    for _, c in ipairs(catalogRows or {}) do catalogByHouse[c.house] = c end

    for _, row in ipairs(rows) do
        local houseKey = row[cfg.HouseField]
        local catalog = catalogByHouse[houseKey]

        properties[#properties + 1] = {
            house = houseKey,
            type = catalog and catalog.type or 'house',
            label = (catalog and catalog.label) or houseKey,
            location = (catalog and catalog.location) or 'Unknown',
            price = catalog and catalog.price or 0,
            seized = false,
        }
    end

    -- mark active seizures
    local seizures = MySQL.query.await('SELECT house FROM gt_property_seizures WHERE citizenid = ? AND seized = 1', { citizenid })
    if seizures then
        for _, s in ipairs(seizures) do
            for _, p in ipairs(properties) do
                if p.house == s.house then p.seized = true end
            end
        end
    end

    return properties
end

-- Removes the ownership row (if present) and snapshots it for restore.
function Housing.SeizeProperty(citizenid, house, reason, staffName)
    if not tableExists(cfg.HousesTable) then return false, 'no_housing_resource' end

    local row = MySQL.single.await(('SELECT * FROM `%s` WHERE `%s` = ? AND `%s` = ?'):format(cfg.HousesTable, cfg.CitizenField, cfg.HouseField), { citizenid, house })
    if not row then return false, 'not_owned' end

    MySQL.insert.await([[
        INSERT INTO gt_property_seizures (house, citizenid, snapshot, seized, reason, seized_by)
        VALUES (?, ?, ?, 1, ?, ?)
    ]], { house, citizenid, json.encode(row), reason, staffName })

    MySQL.query.await(('DELETE FROM `%s` WHERE `%s` = ? AND `%s` = ?'):format(cfg.HousesTable, cfg.CitizenField, cfg.HouseField), { citizenid, house })

    return true
end

-- Restores the most recent active seizure snapshot for this house/citizen.
function Housing.RestoreProperty(citizenid, house, staffName)
    local seizure = MySQL.single.await([[
        SELECT * FROM gt_property_seizures
        WHERE house = ? AND citizenid = ? AND seized = 1
        ORDER BY id DESC LIMIT 1
    ]], { house, citizenid })

    if not seizure then return false, 'no_seizure_found' end

    local ok, snapshot = pcall(json.decode, seizure.snapshot)
    if not ok or not snapshot then return false, 'corrupt_snapshot' end

    -- Skip the original primary key so MySQL assigns a fresh one - the
    -- old id may have been reused by an unrelated row while this house
    -- was seized.
    local columns, placeholders, values = {}, {}, {}
    for col, val in pairs(snapshot) do
        if col ~= 'id' then
            columns[#columns + 1] = ('`%s`'):format(col)
            placeholders[#placeholders + 1] = '?'
            values[#values + 1] = val
        end
    end

    MySQL.insert.await(('INSERT INTO `%s` (%s) VALUES (%s)'):format(cfg.HousesTable, table.concat(columns, ', '), table.concat(placeholders, ', ')), values)

    MySQL.update.await('UPDATE gt_property_seizures SET seized = 0, restored_at = CURRENT_TIMESTAMP, resolved_by = ? WHERE id = ?', { staffName, seizure.id })

    return true
end
