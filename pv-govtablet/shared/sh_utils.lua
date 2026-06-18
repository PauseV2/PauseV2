Utils = {}

-- Strict input validation helpers shared by client + server.
-- Server is the only side these results are ever trusted on.

function Utils.IsValidCitizenId(id)
    return type(id) == 'string' and #id > 0 and #id <= 20 and id:match('^[%w]+$') ~= nil
end

function Utils.IsValidPlate(plate)
    return type(plate) == 'string' and #plate > 0 and #plate <= 10 and plate:match('^[%w%s]+$') ~= nil
end

function Utils.IsValidMoneyType(moneyType)
    if type(moneyType) ~= 'string' then return false end
    for _, t in ipairs(Config.MoneyTypes) do
        if t == moneyType then return true end
    end
    return false
end

function Utils.SanitizeString(str, maxLen)
    if type(str) ~= 'string' then return nil end
    str = str:gsub('[<>%%;]', '')
    str = str:sub(1, maxLen or 255)
    if #str == 0 then return nil end
    return str
end

function Utils.IsValidAccountNumber(n)
    return type(n) == 'string' and #n >= 6 and #n <= 20 and n:match('^%d+$') ~= nil
end

function Utils.IsPositiveNumber(n)
    return type(n) == 'number' and n > 0 and n == n and n ~= math.huge
end

function Utils.Round(n)
    return math.floor(tonumber(n) or 0)
end
