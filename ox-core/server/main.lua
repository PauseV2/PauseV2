Ox.Identifiers = Ox.Identifiers or {} -- [source] = { license, license2, discord }

AddEventHandler('playerConnecting', function(name, _setKickReason, deferrals)
    local source = source
    deferrals.defer()
    Wait(0)

    local identifiers = GetPlayerIdentifiers(source)
    local license, license2, discord

    for _, id in ipairs(identifiers) do
        if id:find('^license:') then
            license = id
        elseif id:find('^license2:') then
            license2 = id
        elseif id:find('^discord:') then
            discord = id
        end
    end

    if not license then
        deferrals.done('A valid Rockstar license identifier is required to join this server.')
        return
    end

    Ox.Identifiers[source] = { license = license, license2 = license2, discord = discord }

    local ok, err = pcall(OxDB.UpsertPlayer, license, license2, discord, name)
    if not ok then
        print(('[ox-core] failed to upsert player %s: %s'):format(license, tostring(err)))
        deferrals.done('A database error occurred while connecting. Please try again.')
        return
    end

    deferrals.done()
end)

AddEventHandler('playerDropped', function()
    local source = source
    local player = Ox.GetPlayer(source)

    if player then
        player:Save()
        TriggerEvent('ox:server:playerUnloaded', source, player.citizenid)
    end

    Ox.RemovePlayer(source)
    Ox.Identifiers[source] = nil
end)

CreateThread(function()
    while true do
        Wait(Config.AutoSaveIntervalMs)

        for _, player in pairs(Ox.Players) do
            player:Save()
        end
    end
end)
