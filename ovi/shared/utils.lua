-- ============================================================
-- Shared helper functions (loaded client + server side).
-- ============================================================

OVI = OVI or {}

--- Pick a random element from a plain array table.
function OVI.RandomFrom(tbl)
    if not tbl or #tbl == 0 then return nil end
    return tbl[math.random(1, #tbl)]
end

--- Weighted random pick. `tbl` is an array of { weight = number, ... } entries.
--- Returns the chosen entry itself.
function OVI.WeightedRandom(tbl)
    local total = 0
    for _, entry in ipairs(tbl) do
        total = total + (entry.weight or 1)
    end
    if total <= 0 then return nil end

    local roll = math.random() * total
    local cumulative = 0
    for _, entry in ipairs(tbl) do
        cumulative = cumulative + (entry.weight or 1)
        if roll <= cumulative then
            return entry
        end
    end
    return tbl[#tbl]
end

--- Roll a percent chance (0-100).
function OVI.Chance(percent)
    if not percent or percent <= 0 then return false end
    return math.random(1, 10000) <= (percent * 100)
end

--- Random integer between min/max inclusive, tolerant of {min,max} table input.
function OVI.RandomRange(min, max)
    if type(min) == 'table' then
        max = min[2]
        min = min[1]
    end
    return math.random(min, max)
end

function OVI.Round(value, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(value * mult + 0.5) / mult
end

function OVI.GenerateRandomDigits(length)
    local str = ''
    for _ = 1, length do
        str = str .. tostring(math.random(0, 9))
    end
    return str
end

function OVI.GeneratePhoneNumber()
    local prefix = OVI.RandomFrom(Config.PhoneNumberFormat.prefix)
    return prefix .. '-' .. OVI.GenerateRandomDigits(Config.PhoneNumberFormat.length)
end

function OVI.GenerateIMEI()
    return OVI.GenerateRandomDigits(15)
end

function OVI.GenerateContactId()
    return 'C' .. OVI.GenerateRandomDigits(8)
end

function OVI.GenerateFullName()
    local first = OVI.RandomFrom(Config.ClientNames.first)
    local last = OVI.RandomFrom(Config.ClientNames.last)
    return first .. ' ' .. last
end

--- Find a plain numeric value inside a free-typed string, e.g. "i want 490".
--- Returns nil if no number was found.
function OVI.ExtractNumber(text)
    local num = string.match(text, '%d+')
    return num and tonumber(num) or nil
end

--- Case-insensitive substring containment check for a list of keywords.
--- Returns true and the matched keyword on the first hit.
function OVI.ContainsAny(text, keywords)
    local lower = string.lower(text)
    for _, word in ipairs(keywords) do
        if string.find(lower, string.lower(word), 1, true) then
            return true, word
        end
    end
    return false, nil
end

function OVI.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end
