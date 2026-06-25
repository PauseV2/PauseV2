-- ============================================================
-- Complaint network. A bad experience can spread through a contact's
-- referral graph, making negotiation harder with related contacts too.
-- ============================================================

if not Config.Toggle.Complaints then return end

local Complaints = Config.Complaints

--- BFS over ovi_referrals (treated as an undirected graph) to find every
--- contact within `radius` hops of `contactId`.
local function findNetwork(contactId, radius)
    local visited = { [contactId] = 0 }
    local frontier = { contactId }

    for hop = 1, radius do
        local nextFrontier = {}
        for _, id in ipairs(frontier) do
            local rows = MySQL.query.await(
                'SELECT parent_contact_id, new_contact_id FROM ovi_referrals WHERE parent_contact_id = ? OR new_contact_id = ?',
                { id, id }
            ) or {}
            for _, row in ipairs(rows) do
                local other = row.parent_contact_id == id and row.new_contact_id or row.parent_contact_id
                if visited[other] == nil then
                    visited[other] = hop
                    nextFrontier[#nextFrontier + 1] = other
                end
            end
        end
        frontier = nextFrontier
        if #frontier == 0 then break end
    end

    return visited
end

function OVI.FileComplaint(imei, contactId, severityKey)
    severityKey = severityKey or 'minor'
    if not OVI.Chance(Complaints.chance) then return end

    local expiresAt = os.time() + (Complaints.durationHours * 3600)
    OVI.DB.AddComplaint(imei, contactId, severityKey, expiresAt)

    if Complaints.spreadRadius > 0 then
        local network = findNetwork(contactId, Complaints.spreadRadius)
        for relatedId, hop in pairs(network) do
            if relatedId ~= contactId and hop > 0 then
                -- propagated complaints are always treated as minor regardless of source severity
                OVI.DB.AddComplaint(imei, relatedId, 'minor', expiresAt)
            end
        end
    end
end

RegisterNetEvent('ovi:server:fileComplaint', function(imei, contactId, severityKey)
    OVI.FileComplaint(imei, contactId, severityKey)
end)

--- Total negotiation penalty percent currently active against a given
--- phone<->contact pair (used by negotiation.lua to shrink tolerance).
function OVI.GetComplaintPenalty(imei, contactId)
    local rows = OVI.DB.GetActiveComplaints(imei, contactId, os.time())
    local total = 0
    for _, row in ipairs(rows) do
        local levelCfg = Complaints.severityLevels[row.severity]
        if levelCfg then
            total = total + levelCfg.negotiationPenaltyPercent
        end
    end
    return total
end
