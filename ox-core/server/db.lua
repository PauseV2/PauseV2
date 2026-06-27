-- Thin oxmysql wrapper. Every query here is a prepared statement (no string
-- concatenation of user input) and every call is the synchronous-looking
-- `.await` form so callers can be written top-to-bottom without callbacks.

OxDB = {}

function OxDB.UpsertPlayer(license, license2, discord, name)
    return MySQL.update.await([[
        INSERT INTO ox_players (license, license2, discord, name, first_seen, last_seen)
        VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE license2 = ?, discord = ?, name = ?, last_seen = CURRENT_TIMESTAMP
    ]], { license, license2, discord, name, license2, discord, name })
end

function OxDB.GetCharactersByLicense(license)
    return MySQL.query.await(
        'SELECT citizenid, slot, charinfo, job FROM ox_characters WHERE license = ? AND deleted = 0 ORDER BY slot ASC',
        { license }
    )
end

function OxDB.GetCharacter(citizenid)
    return MySQL.single.await(
        'SELECT * FROM ox_characters WHERE citizenid = ? AND deleted = 0',
        { citizenid }
    )
end

function OxDB.CountCharacterSlots(license)
    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM ox_characters WHERE license = ? AND deleted = 0',
        { license }
    )
    return count or 0
end

function OxDB.CitizenIdExists(citizenid)
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM ox_characters WHERE citizenid = ?', { citizenid })
    return (count or 0) > 0
end

function OxDB.CreateCharacter(data)
    return MySQL.insert.await([[
        INSERT INTO ox_characters
            (citizenid, license, slot, charinfo, job, gang, money, metadata, position)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.citizenid,
        data.license,
        data.slot,
        json.encode(data.charinfo),
        json.encode(data.job),
        json.encode(data.gang),
        json.encode(data.money),
        json.encode(data.metadata),
        json.encode(data.position),
    })
end

function OxDB.SaveCharacter(citizenid, data)
    return MySQL.update.await([[
        UPDATE ox_characters
        SET job = ?, gang = ?, money = ?, metadata = ?, position = ?, last_updated = CURRENT_TIMESTAMP
        WHERE citizenid = ?
    ]], {
        json.encode(data.job),
        json.encode(data.gang),
        json.encode(data.money),
        json.encode(data.metadata),
        json.encode(data.position),
        citizenid,
    })
end

function OxDB.DeleteCharacter(citizenid, hardDelete)
    if hardDelete then
        return MySQL.update.await('DELETE FROM ox_characters WHERE citizenid = ?', { citizenid })
    end

    return MySQL.update.await('UPDATE ox_characters SET deleted = 1 WHERE citizenid = ?', { citizenid })
end
