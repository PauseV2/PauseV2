OxShared = {}

local citizenIdChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

function OxShared.GenerateCitizenId()
    local id = Config.CitizenIdPrefix
    for _ = 1, Config.CitizenIdLength do
        local idx = math.random(1, #citizenIdChars)
        id = id .. citizenIdChars:sub(idx, idx)
    end
    return id
end

function OxShared.IsValidName(str)
    return type(str) == 'string' and #str >= 2 and #str <= 20 and str:match('^[%a][%a%s%-\']*$') ~= nil
end

-- expects DD/MM/YYYY
function OxShared.IsValidDate(str)
    if type(str) ~= 'string' then return false end

    local d, m, y = str:match('^(%d%d)/(%d%d)/(%d%d%d%d)$')
    if not d then return false end

    d, m, y = tonumber(d), tonumber(m), tonumber(y)
    if not (d and m and y) then return false end

    return d >= 1 and d <= 31 and m >= 1 and m <= 12 and y >= 1900 and y <= 2026
end

function OxShared.IsValidGender(str)
    return str == 'male' or str == 'female'
end

function OxShared.DeepCopy(tbl)
    if type(tbl) ~= 'table' then return tbl end

    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = OxShared.DeepCopy(v)
    end
    return copy
end
