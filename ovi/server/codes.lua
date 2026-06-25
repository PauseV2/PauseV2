-- ============================================================
-- Coded slang detection. Used by negotiation.lua to react when a player
-- says a drug's real name out loud instead of playing along with the code -
-- paranoid clients in particular do not like that.
-- ============================================================

if not Config.Toggle.CodeLanguage then return end

function OVI.DecodeDrugWord(text)
    local lower = string.lower(text)
    for drugKey, words in pairs(Config.Codes) do
        for _, word in ipairs(words) do
            if string.find(lower, string.lower(word), 1, true) then
                return drugKey
            end
        end
    end
    return nil
end

function OVI.UsesDirectDrugName(text)
    local lower = string.lower(text)
    for drugKey, drugCfg in pairs(Config.Drugs) do
        if string.find(lower, string.lower(drugCfg.label), 1, true) then
            return true, drugKey
        end
    end
    return false, nil
end
