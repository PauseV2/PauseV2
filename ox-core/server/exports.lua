exports('GetPlayer', function(source)
    return Ox.GetPlayer(source)
end)

exports('GetPlayerByCitizenId', function(citizenid)
    return Ox.GetPlayerByCitizenId(citizenid)
end)

exports('GetPlayers', function()
    return Ox.GetPlayers()
end)

exports('CreateCharacter', function(source, data)
    return OxCharacters.Create(source, data)
end)

exports('DeleteCharacter', function(source, citizenid)
    return OxCharacters.Delete(source, citizenid)
end)

exports('AddMoney', function(source, account, amount, reason)
    local player = Ox.GetPlayer(source)
    if not player then return false, 'character not loaded' end
    return player:AddMoney(account, amount, reason)
end)

exports('RemoveMoney', function(source, account, amount, reason)
    local player = Ox.GetPlayer(source)
    if not player then return false, 'character not loaded' end
    return player:RemoveMoney(account, amount, reason)
end)

exports('SetMoney', function(source, account, amount, reason)
    local player = Ox.GetPlayer(source)
    if not player then return false, 'character not loaded' end
    return player:SetMoney(account, amount, reason)
end)

exports('GetMoney', function(source, account)
    local player = Ox.GetPlayer(source)
    if not player then return nil end
    return player:GetMoney(account)
end)

exports('SetJob', function(source, name, grade)
    local player = Ox.GetPlayer(source)
    if not player then return false, 'character not loaded' end
    return player:SetJob(name, grade)
end)

exports('SetGang', function(source, name, grade)
    local player = Ox.GetPlayer(source)
    if not player then return false, 'character not loaded' end
    return player:SetGang(name, grade)
end)

exports('SetMetadata', function(source, key, value)
    local player = Ox.GetPlayer(source)
    if not player then return false, 'character not loaded' end
    player:SetMetadata(key, value)
    return true
end)

exports('RegisterHook', function(name, fn, priority)
    OxHooks.RegisterHook(name, fn, priority)
end)
