-- ============================================================
-- Hidden heat system. Heat lives on ovi_phones.heat, mirrored into a small
-- cache so frequent checks (e.g. trap chance rolls) don't hit the DB.
-- ============================================================

if not Config.Toggle.Heat then return end

local Heat = Config.Heat
OVI.Cache.heatMirror = OVI.Cache.heatMirror or {}

function OVI.GetHeat(imei)
    if OVI.Cache.heatMirror[imei] ~= nil then
        return OVI.Cache.heatMirror[imei]
    end
    local row = OVI.DB.GetPhone(imei)
    local value = row and row.heat or 0
    OVI.Cache.heatMirror[imei] = value
    return value
end

function OVI.AddHeat(imei, amount, reason)
    local current = OVI.GetHeat(imei)
    local newHeat = OVI.Clamp(current + amount, Heat.min, Heat.max)
    OVI.Cache.heatMirror[imei] = newHeat
    OVI.DB.SetHeat(imei, newHeat)
    OVI.DB.AddHeatLog(imei, amount, reason)
    return newHeat
end

RegisterNetEvent('ovi:server:addHeat', function(imei, amount, reason)
    OVI.AddHeat(imei, amount, reason)
end)

--- Used by traps.lua to bump the base trap chance based on current heat.
function OVI.GetTrapHeatBonus(imei)
    local heat = OVI.GetHeat(imei)
    if heat >= Heat.thresholds.trapChanceBonus.heat then
        return Heat.thresholds.trapChanceBonus.bonusPercent
    end
    return 0
end

--- Rolled when generating a new client interaction - simulates undercover
--- buyers / tapped lines / surveillance appearing at high heat.
function OVI.RollHeatEvent(imei)
    local heat = OVI.GetHeat(imei)

    if heat >= Heat.thresholds.undercoverBuyerChance.heat and OVI.Chance(Heat.thresholds.undercoverBuyerChance.chance) then
        return 'undercover'
    end
    if heat >= Heat.thresholds.tappedPhoneChance.heat and OVI.Chance(Heat.thresholds.tappedPhoneChance.chance) then
        return 'tapped'
    end
    if heat >= Heat.thresholds.surveillanceChance.heat and OVI.Chance(Heat.thresholds.surveillanceChance.chance) then
        return 'surveillance'
    end
    return nil
end

-- ------------------------------------------------------------------ decay --
CreateThread(function()
    while true do
        Wait(60 * 60 * 1000)
        MySQL.update.await('UPDATE ovi_phones SET heat = GREATEST(?, heat - ?)', { Heat.min, Heat.decayPerHour })
        for imei, value in pairs(OVI.Cache.heatMirror) do
            OVI.Cache.heatMirror[imei] = OVI.Clamp(value - Heat.decayPerHour, Heat.min, Heat.max)
        end
    end
end)
