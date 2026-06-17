--[[
    Police / MDT bridge
    --------------------
    Maintains the canonical criminal record table (gt_criminal_records).
    Existing MDT resources (qb-policejob, rcore_invoice, custom MDTs, ...)
    can feed records into the tablet without any direct dependency by
    calling the export below whenever an officer books a suspect:

        exports['pv-govtablet']:AddCriminalRecord(citizenid, {
            officerName = 'John Doe',
            officerCitizenId = Player.PlayerData.citizenid,
            charges = 'Murder, Grand Theft Auto',
            fine = 25000,
            sentenceMonths = 20,
            status = 'served',
            notes = 'Booked at Mission Row PD'
        })

    See README.md for a full qb-policejob hook example.
]]

Police = {}

function Police.GetRecords(citizenid)
    local rows = MySQL.query.await('SELECT * FROM gt_criminal_records WHERE citizenid = ? ORDER BY created_at DESC', { citizenid })
    return rows or {}
end

function Police.AddRecord(citizenid, data)
    if not Utils.IsValidCitizenId(citizenid) then return false, 'invalid_citizenid' end

    local officerName = Utils.SanitizeString(data.officerName, 100) or 'Unknown'
    local charges = Utils.SanitizeString(data.charges, 1000)
    if not charges then return false, 'invalid_charges' end

    local fine = tonumber(data.fine) or 0
    local sentenceMonths = tonumber(data.sentenceMonths) or 0
    local status = data.status
    local validStatuses = { active = true, served = true, warrant = true, fined = true, dismissed = true }
    if not validStatuses[status] then status = 'active' end

    local notes = Utils.SanitizeString(data.notes or '', 1000)

    local insertId = MySQL.insert.await([[
        INSERT INTO gt_criminal_records
            (citizenid, officer_name, officer_citizenid, charges, fine, sentence_months, status, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        citizenid, officerName, data.officerCitizenId, charges,
        math.max(0, fine), math.max(0, sentenceMonths), status, notes,
    })

    return insertId ~= nil and insertId > 0
end

function Police.UpdateRecordStatus(recordId, status)
    local validStatuses = { active = true, served = true, warrant = true, fined = true, dismissed = true }
    if not validStatuses[status] then return false end

    MySQL.update.await('UPDATE gt_criminal_records SET status = ? WHERE id = ?', { status, recordId })
    return true
end

exports('AddCriminalRecord', function(citizenid, data)
    return Police.AddRecord(citizenid, data or {})
end)

exports('GetCriminalRecords', Police.GetRecords)
