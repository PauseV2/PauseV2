OxInvDB = {}

function OxInvDB.Load(id)
    return MySQL.single.await('SELECT data FROM ox_inventories WHERE id = ?', { id })
end

function OxInvDB.Save(id, invType, data)
    local encoded = json.encode(data)

    return MySQL.update.await([[
        INSERT INTO ox_inventories (id, type, data) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE data = ?, updated = CURRENT_TIMESTAMP
    ]], { id, invType, encoded, encoded })
end
