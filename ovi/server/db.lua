-- ============================================================
-- oxmysql data access layer. All other server modules go through here -
-- nothing touches MySQL directly outside this file.
-- ============================================================

OVI = OVI or {}
OVI.DB = {}

-- ---------------------------------------------------------------- phones --

function OVI.DB.GetPhone(imei)
    return MySQL.single.await('SELECT * FROM ovi_phones WHERE imei = ?', { imei })
end

function OVI.DB.GetPhoneByNumber(number)
    return MySQL.single.await('SELECT * FROM ovi_phones WHERE phone_number = ?', { number })
end

function OVI.DB.CreatePhone(imei, number, phoneType, citizenid)
    MySQL.insert.await(
        'INSERT INTO ovi_phones (imei, phone_number, phone_type, owner_citizenid) VALUES (?, ?, ?, ?)',
        { imei, number, phoneType, citizenid }
    )
end

function OVI.DB.InstallOVI(imei, pin, alias)
    MySQL.update.await(
        'UPDATE ovi_phones SET ovi_installed = 1, pin = ?, alias = ?, access_code = NULL WHERE imei = ?',
        { pin, alias, imei }
    )
end

function OVI.DB.GiveAccessCode(imei, code)
    MySQL.update.await('UPDATE ovi_phones SET access_code = ? WHERE imei = ?', { code, imei })
end

function OVI.DB.SetRecoveryPhrase(imei, phrase)
    MySQL.update.await('UPDATE ovi_phones SET recovery_phrase = ? WHERE imei = ?', { phrase, imei })
end

function OVI.DB.GetPhoneByRecoveryPhrase(phrase)
    return MySQL.single.await('SELECT * FROM ovi_phones WHERE recovery_phrase = ?', { phrase })
end

function OVI.DB.SetOnlineStatus(imei, online)
    MySQL.update.await('UPDATE ovi_phones SET online = ? WHERE imei = ?', { online and 1 or 0, imei })
end

function OVI.DB.SetPin(imei, pin)
    MySQL.update.await('UPDATE ovi_phones SET pin = ? WHERE imei = ?', { pin, imei })
end

function OVI.DB.SetAlias(imei, alias)
    MySQL.update.await('UPDATE ovi_phones SET alias = ? WHERE imei = ?', { alias, imei })
end

function OVI.DB.SetPinAttempts(imei, attempts, lockedUntil)
    MySQL.update.await(
        'UPDATE ovi_phones SET pin_attempts = ?, locked_until = ? WHERE imei = ?',
        { attempts, lockedUntil or 0, imei }
    )
end

function OVI.DB.SetHeat(imei, heat)
    MySQL.update.await('UPDATE ovi_phones SET heat = ? WHERE imei = ?', { heat, imei })
end

function OVI.DB.AddReputation(imei, amount)
    MySQL.update.await('UPDATE ovi_phones SET reputation = reputation + ? WHERE imei = ?', { amount, imei })
end

function OVI.DB.WipePhone(imei)
    MySQL.update.await(
        'UPDATE ovi_phones SET wiped = 1, pin = NULL, alias = NULL, ovi_installed = 0, pin_attempts = 0 WHERE imei = ?',
        { imei }
    )
    MySQL.query.await('DELETE FROM ovi_contacts WHERE phone_imei = ?', { imei })
    MySQL.query.await('DELETE FROM ovi_messages WHERE phone_imei = ?', { imei })
end

-- ------------------------------------------------------------ global npc --

function OVI.DB.GetGlobalClient(contactId)
    return MySQL.single.await('SELECT * FROM ovi_clients_global WHERE contact_id = ?', { contactId })
end

function OVI.DB.CreateGlobalClient(data)
    MySQL.insert.await(
        [[INSERT INTO ovi_clients_global
            (contact_id, full_name, number, personality, preferred_drug, quantity_min, quantity_max, risk_level, shared)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            data.contactId, data.fullName, data.number, data.personality, data.preferredDrug,
            data.quantityMin, data.quantityMax, data.riskLevel, data.shared and 1 or 0,
        }
    )
end

function OVI.DB.SetClientStatus(contactId, status, ghostUntil)
    MySQL.update.await(
        'UPDATE ovi_clients_global SET status = ?, ghost_until = ? WHERE contact_id = ?',
        { status, ghostUntil or 0, contactId }
    )
end

function OVI.DB.IncrementReferralCount(contactId)
    MySQL.update.await('UPDATE ovi_clients_global SET referral_count = referral_count + 1 WHERE contact_id = ?', { contactId })
end

-- ------------------------------------------------------- phone <-> contact --

function OVI.DB.GetContactsForPhone(imei)
    return MySQL.query.await(
        [[SELECT oc.*, g.full_name, g.number, g.personality, g.preferred_drug, g.quantity_min,
                 g.quantity_max, g.risk_level, g.shared, g.status, g.ghost_until
          FROM ovi_contacts oc
          INNER JOIN ovi_clients_global g ON g.contact_id = oc.contact_id
          WHERE oc.phone_imei = ?]],
        { imei }
    ) or {}
end

function OVI.DB.GetPhoneContact(imei, contactId)
    return MySQL.single.await('SELECT * FROM ovi_contacts WHERE phone_imei = ? AND contact_id = ?', { imei, contactId })
end

function OVI.DB.AddPhoneContact(imei, contactId, trust, loyalty)
    MySQL.insert.await(
        'INSERT INTO ovi_contacts (phone_imei, contact_id, trust, loyalty) VALUES (?, ?, ?, ?)',
        { imei, contactId, trust or 0, loyalty or 0 }
    )
end

function OVI.DB.UpdatePhoneContact(imei, contactId, fields)
    local sets, params = {}, {}
    for key, value in pairs(fields) do
        sets[#sets + 1] = ('%s = ?'):format(key)
        params[#params + 1] = value
    end
    params[#params + 1] = imei
    params[#params + 1] = contactId
    MySQL.update.await(
        ('UPDATE ovi_contacts SET %s WHERE phone_imei = ? AND contact_id = ?'):format(table.concat(sets, ', ')),
        params
    )
end

function OVI.DB.GetOwnersOfContact(contactId)
    return MySQL.query.await('SELECT phone_imei FROM ovi_contacts WHERE contact_id = ? AND blacklisted = 0', { contactId }) or {}
end

-- ------------------------------------------------------------- messages --

function OVI.DB.AddMessage(imei, contactId, sender, message, hidden)
    MySQL.insert.await(
        'INSERT INTO ovi_messages (phone_imei, contact_id, sender, message, hidden, seen) VALUES (?, ?, ?, ?, ?, ?)',
        { imei, contactId, sender, message, hidden and 1 or 0, sender == 'player' and 1 or 0 }
    )
end

function OVI.DB.GetMessages(imei, limit)
    return MySQL.query.await(
        'SELECT * FROM ovi_messages WHERE phone_imei = ? ORDER BY created_at DESC LIMIT ?',
        { imei, limit or 200 }
    ) or {}
end

function OVI.DB.MarkContactMessagesSeen(imei, contactId)
    MySQL.update.await(
        'UPDATE ovi_messages SET seen = 1 WHERE phone_imei = ? AND contact_id = ? AND seen = 0',
        { imei, contactId }
    )
end

--- One row per contact with unread NPC messages on this phone, e.g.
--- { { contact_id = 'C123', unread = 3 }, ... }. Empty contacts are omitted.
function OVI.DB.GetUnreadCounts(imei)
    return MySQL.query.await(
        [[SELECT contact_id, COUNT(*) AS unread FROM ovi_messages
          WHERE phone_imei = ? AND sender = 'client' AND seen = 0
          GROUP BY contact_id]],
        { imei }
    ) or {}
end

-- ----------------------------------------------------------- deliveries --

function OVI.DB.CreateDelivery(imei, contactId, drug, quantity, price, location, deadDrop)
    return MySQL.insert.await(
        'INSERT INTO ovi_deliveries (phone_imei, contact_id, drug, quantity, price, location, dead_drop) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { imei, contactId, drug, quantity, price, location, deadDrop and 1 or 0 }
    )
end

function OVI.DB.SetDeliveryStatus(deliveryId, status)
    MySQL.update.await('UPDATE ovi_deliveries SET status = ? WHERE id = ?', { status, deliveryId })
end

function OVI.DB.UpdateDeliveryTerms(deliveryId, price, quantity)
    MySQL.update.await('UPDATE ovi_deliveries SET price = ?, quantity = ? WHERE id = ?', { price, quantity, deliveryId })
end

function OVI.DB.GetDelivery(deliveryId)
    return MySQL.single.await('SELECT * FROM ovi_deliveries WHERE id = ?', { deliveryId })
end

function OVI.DB.GetDeliveries(imei, limit)
    return MySQL.query.await(
        'SELECT * FROM ovi_deliveries WHERE phone_imei = ? ORDER BY created_at DESC LIMIT ?',
        { imei, limit or 100 }
    ) or {}
end

-- -------------------------------------------------------------- gps/notes --

function OVI.DB.AddGPSLog(imei, x, y, z, label)
    MySQL.insert.await('INSERT INTO ovi_gps_logs (phone_imei, x, y, z, label) VALUES (?, ?, ?, ?, ?)', { imei, x, y, z, label })
end

function OVI.DB.GetGPSLogs(imei, limit)
    return MySQL.query.await('SELECT * FROM ovi_gps_logs WHERE phone_imei = ? ORDER BY created_at DESC LIMIT ?', { imei, limit or 50 }) or {}
end

function OVI.DB.AddNote(imei, text)
    MySQL.insert.await('INSERT INTO ovi_notes (phone_imei, text) VALUES (?, ?)', { imei, text })
end

function OVI.DB.GetNotes(imei)
    return MySQL.query.await('SELECT * FROM ovi_notes WHERE phone_imei = ? ORDER BY created_at DESC', { imei }) or {}
end

-- ------------------------------------------------------------ complaints --

function OVI.DB.AddComplaint(imei, contactId, severity, expiresAt)
    MySQL.insert.await(
        'INSERT INTO ovi_complaints (phone_imei, contact_id, severity, expires_at) VALUES (?, ?, ?, ?)',
        { imei, contactId, severity, expiresAt }
    )
end

function OVI.DB.GetActiveComplaints(imei, contactId, now)
    return MySQL.query.await(
        'SELECT * FROM ovi_complaints WHERE phone_imei = ? AND contact_id = ? AND expires_at > ?',
        { imei, contactId, now }
    ) or {}
end

-- ------------------------------------------------------------- referrals --

function OVI.DB.AddReferral(parentContactId, newContactId, imei)
    MySQL.insert.await(
        'INSERT INTO ovi_referrals (parent_contact_id, new_contact_id, phone_imei) VALUES (?, ?, ?)',
        { parentContactId, newContactId, imei }
    )
end

function OVI.DB.CountReferrals(parentContactId)
    local row = MySQL.single.await('SELECT COUNT(*) AS total FROM ovi_referrals WHERE parent_contact_id = ?', { parentContactId })
    return row and row.total or 0
end

-- ----------------------------------------------------------------- traps --

function OVI.DB.AddTrapResult(citizenid, imei, result, lootJson)
    MySQL.insert.await(
        'INSERT INTO ovi_traps (citizenid, phone_imei, result, loot) VALUES (?, ?, ?, ?)',
        { citizenid, imei, result, lootJson }
    )
end

-- ---------------------------------------------------------------- clones --

function OVI.DB.AddClone(sourceImei, backupJson, citizenid)
    MySQL.insert.await('INSERT INTO ovi_clones (source_imei, backup_data, citizenid) VALUES (?, ?, ?)', { sourceImei, backupJson, citizenid })
end

function OVI.DB.GetClonesForPhone(sourceImei)
    return MySQL.query.await('SELECT * FROM ovi_clones WHERE source_imei = ? ORDER BY created_at DESC', { sourceImei }) or {}
end

function OVI.DB.CountClonesForPhone(sourceImei)
    local row = MySQL.single.await('SELECT COUNT(*) AS total FROM ovi_clones WHERE source_imei = ?', { sourceImei })
    return row and row.total or 0
end

--- Re-keys every relational row from one phone's imei to another - used
--- when migrating a criminal identity onto new hardware.
function OVI.DB.MigratePhoneData(sourceImei, targetImei)
    for _, tbl in ipairs({ 'ovi_contacts', 'ovi_messages', 'ovi_deliveries', 'ovi_gps_logs', 'ovi_notes' }) do
        MySQL.update.await(('UPDATE %s SET phone_imei = ? WHERE phone_imei = ?'):format(tbl), { targetImei, sourceImei })
    end
end

-- ------------------------------------------------------------- heat log --

function OVI.DB.AddHeatLog(imei, amount, reason)
    MySQL.insert.await('INSERT INTO ovi_heat_log (phone_imei, amount, reason) VALUES (?, ?, ?)', { imei, amount, reason })
end

-- ------------------------------------------------------------ suppliers --

function OVI.DB.GetSupplier(drug, citizenid)
    return MySQL.single.await('SELECT * FROM ovi_suppliers WHERE drug = ? AND citizenid = ?', { drug, citizenid })
end

function OVI.DB.UpsertSupplier(drug, citizenid, fields)
    local existing = OVI.DB.GetSupplier(drug, citizenid)
    if existing then
        local sets, params = {}, {}
        for key, value in pairs(fields) do
            sets[#sets + 1] = ('%s = ?'):format(key)
            params[#params + 1] = value
        end
        params[#params + 1] = drug
        params[#params + 1] = citizenid
        MySQL.update.await(('UPDATE ovi_suppliers SET %s WHERE drug = ? AND citizenid = ?'):format(table.concat(sets, ', ')), params)
    else
        MySQL.insert.await(
            'INSERT INTO ovi_suppliers (drug, citizenid, stock, unlocked, last_restock, cooldown_until) VALUES (?, ?, ?, ?, ?, ?)',
            { drug, citizenid, fields.stock or 0, fields.unlocked or 0, fields.last_restock or 0, fields.cooldown_until or 0 }
        )
    end
end
