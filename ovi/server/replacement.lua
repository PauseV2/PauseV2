-- ============================================================
-- Client replacement: when a deal fails/times out, look for another
-- eligible seller who also owns this contact instead of the NPC just
-- vanishing. Only relevant for contacts owned by more than one phone
-- (shared clients / cross-referral overlap) - exclusive contacts simply
-- have nowhere else to go, which is the intended behaviour.
-- ============================================================

if not Config.Toggle.ClientReplacement then return end

local Replacement = Config.Replacement
OVI.Cache.replacementAttempts = OVI.Cache.replacementAttempts or {}

local function pickReplacement(candidates, failedImei, lastLocation)
    local filtered = {}
    for _, row in ipairs(candidates) do
        if row.phone_imei ~= failedImei and OVI.Cache.imeiOwner[row.phone_imei] then
            filtered[#filtered + 1] = row
        end
    end
    if #filtered == 0 then return nil end

    if Replacement.priority == 'trust' then
        table.sort(filtered, function(a, b) return (a.trust or 0) > (b.trust or 0) end)
        return filtered[1]
    elseif Replacement.priority == 'longest_relationship' then
        table.sort(filtered, function(a, b) return a.last_interaction < b.last_interaction end)
        return filtered[1]
    elseif Replacement.priority == 'distance' and lastLocation then
        local lx, ly, lz = lastLocation.x, lastLocation.y, lastLocation.z
        table.sort(filtered, function(a, b)
            local srcA, srcB = OVI.Cache.imeiOwner[a.phone_imei], OVI.Cache.imeiOwner[b.phone_imei]
            local pedA, pedB = GetPlayerPed(srcA), GetPlayerPed(srcB)
            local cA, cB = GetEntityCoords(pedA), GetEntityCoords(pedB)
            local dA = #(cA - vector3(lx, ly, lz))
            local dB = #(cB - vector3(lx, ly, lz))
            return dA < dB
        end)
        return filtered[1]
    end

    return filtered[1]
end

RegisterNetEvent('ovi:server:findReplacement', function(failedImei, contactId, deliveryId)
    local key = contactId
    local attempts = (OVI.Cache.replacementAttempts[key] or 0) + 1
    if attempts > Replacement.maxAttempts then
        OVI.Cache.replacementAttempts[key] = nil
        return
    end
    OVI.Cache.replacementAttempts[key] = attempts

    SetTimeout(Replacement.cooldownSeconds * 1000, function()
        local oldDelivery = OVI.DB.GetDelivery(deliveryId)
        local candidates = OVI.DB.GetOwnersOfContact(contactId)
        local lastLocation = nil
        if oldDelivery and oldDelivery.location then
            local x, y, z = oldDelivery.location:match('([^,]+),([^,]+),([^,]+)')
            if x then lastLocation = vector3(tonumber(x), tonumber(y), tonumber(z)) end
        end

        local replacementRow = pickReplacement(candidates, failedImei, lastLocation)
        if not replacementRow then return end

        local globalClient = OVI.DB.GetGlobalClient(contactId)
        if not globalClient then return end

        OVI.GenerateDeliveryRequest(replacementRow.phone_imei, contactId)
    end)
end)
