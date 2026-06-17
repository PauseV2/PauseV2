--[[
    Garage bridge
    -------------
    Default implementation targets the `player_vehicles` table shipped
    by qb-core / used by qb-garages and most forks (qs-advancedgarages,
    cd_garage, etc. all keep a compatible table). Adjust Config.Bridge.Garage
    if your resource differs.

    Seizures are tracked in an overlay table (gt_vehicle_seizures) so we
    never destructively alter rows owned by the garage resource - we only
    flip the `state` column to move a vehicle in/out of impound, which is
    a normal, expected garage operation.
]]

Garage = {}

local cfg = Config.Bridge.Garage

local tableExistsCache = {}
local function tableExists(tableName)
    if tableExistsCache[tableName] ~= nil then return tableExistsCache[tableName] end
    local row = MySQL.single.await('SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ? LIMIT 1', { tableName })
    tableExistsCache[tableName] = row ~= nil
    return tableExistsCache[tableName]
end

function Garage.GetOwnerCitizenId(plate)
    if not tableExists(cfg.VehicleTable) then return nil end
    local row = MySQL.single.await(('SELECT `%s` as citizenid FROM `%s` WHERE `%s` = ?'):format(cfg.CitizenField, cfg.VehicleTable, cfg.PlateField), { plate })
    return row and row.citizenid or nil
end

function Garage.GetVehicles(citizenid)
    local vehicles = {}
    if not tableExists(cfg.VehicleTable) then return vehicles end

    local rows = MySQL.query.await(('SELECT * FROM `%s` WHERE `%s` = ?'):format(cfg.VehicleTable, cfg.CitizenField), { citizenid })
    if not rows then return vehicles end

    local seizureRows = MySQL.query.await('SELECT * FROM gt_vehicle_seizures WHERE citizenid = ?', { citizenid })
    local seizureByPlate = {}
    if seizureRows then
        for _, s in ipairs(seizureRows) do seizureByPlate[s.plate] = s end
    end

    for _, row in ipairs(rows) do
        local plate = row[cfg.PlateField]
        local state = tonumber(row[cfg.StateField]) or 0
        local seizure = seizureByPlate[plate]

        vehicles[#vehicles + 1] = {
            plate = plate,
            model = row[cfg.ModelField],
            stored = state == 1,
            outOfGarage = state == 0,
            impounded = state == 2 or (seizure and seizure.impounded == 1) or false,
            seized = seizure and seizure.seized == 1 or false,
        }
    end

    return vehicles
end

local function upsertSeizureRow(plate, citizenid, fields, staffName)
    fields.updated_by = staffName
    MySQL.query.await([[
        INSERT INTO gt_vehicle_seizures (plate, citizenid, seized, impounded, reason, updated_by)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE seized = ?, impounded = ?, reason = ?, updated_by = ?, updated_at = CURRENT_TIMESTAMP
    ]], {
        plate, citizenid,
        fields.seized and 1 or 0, fields.impounded and 1 or 0, fields.reason, staffName,
        fields.seized and 1 or 0, fields.impounded and 1 or 0, fields.reason, staffName,
    })
end

function Garage.SeizeVehicle(plate, reason, staffName)
    if not tableExists(cfg.VehicleTable) then return false, 'no_garage_resource' end

    local row = MySQL.single.await(('SELECT `%s` as citizenid FROM `%s` WHERE `%s` = ?'):format(cfg.CitizenField, cfg.VehicleTable, cfg.PlateField), { plate })
    if not row then return false, 'not_found' end

    MySQL.update.await(('UPDATE `%s` SET `%s` = 2 WHERE `%s` = ?'):format(cfg.VehicleTable, cfg.StateField, cfg.PlateField), { plate })
    upsertSeizureRow(plate, row.citizenid, { seized = true, impounded = true, reason = reason }, staffName)

    return true
end

function Garage.ReleaseVehicle(plate, staffName)
    if not tableExists(cfg.VehicleTable) then return false, 'no_garage_resource' end

    local row = MySQL.single.await(('SELECT `%s` as citizenid FROM `%s` WHERE `%s` = ?'):format(cfg.CitizenField, cfg.VehicleTable, cfg.PlateField), { plate })
    if not row then return false, 'not_found' end

    MySQL.update.await(('UPDATE `%s` SET `%s` = 1 WHERE `%s` = ?'):format(cfg.VehicleTable, cfg.StateField, cfg.PlateField), { plate })
    upsertSeizureRow(plate, row.citizenid, { seized = false, impounded = false, reason = nil }, staffName)

    return true
end

function Garage.ImpoundVehicle(plate, reason, staffName)
    if not tableExists(cfg.VehicleTable) then return false, 'no_garage_resource' end

    local owner = MySQL.single.await(('SELECT `%s` as citizenid FROM `%s` WHERE `%s` = ?'):format(cfg.CitizenField, cfg.VehicleTable, cfg.PlateField), { plate })
    if not owner then return false, 'not_found' end

    local existing = MySQL.single.await('SELECT seized FROM gt_vehicle_seizures WHERE plate = ?', { plate })

    MySQL.update.await(('UPDATE `%s` SET `%s` = 2 WHERE `%s` = ?'):format(cfg.VehicleTable, cfg.StateField, cfg.PlateField), { plate })
    upsertSeizureRow(plate, owner.citizenid, { seized = existing and existing.seized == 1 or false, impounded = true, reason = reason }, staffName)

    return true
end

function Garage.ReleaseImpound(plate, staffName)
    if not tableExists(cfg.VehicleTable) then return false, 'no_garage_resource' end

    local owner = MySQL.single.await(('SELECT `%s` as citizenid FROM `%s` WHERE `%s` = ?'):format(cfg.CitizenField, cfg.VehicleTable, cfg.PlateField), { plate })
    if not owner then return false, 'not_found' end

    local existing = MySQL.single.await('SELECT seized FROM gt_vehicle_seizures WHERE plate = ?', { plate })
    local stillSeized = existing and existing.seized == 1 or false

    -- Releasing the impound only lifts the impound hold; a separate asset
    -- seizure (if any) is left untouched and must be released on its own.
    MySQL.update.await(('UPDATE `%s` SET `%s` = ? WHERE `%s` = ?'):format(cfg.VehicleTable, cfg.StateField, cfg.PlateField), { stillSeized and 2 or 1, plate })
    upsertSeizureRow(plate, owner.citizenid, { seized = stillSeized, impounded = stillSeized, reason = nil }, staffName)

    return true
end
