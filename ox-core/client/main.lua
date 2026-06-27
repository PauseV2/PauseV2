OxClientData = { money = {}, metadata = {} }

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(0)
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    DisplayHud(false)
    DisplayRadar(false)

    OxCharacters.OpenSelect()
end)

RegisterNetEvent('ox:client:spawnPlayer', function(position)
    DoScreenFadeOut(500)
    Wait(600)

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, position.x, position.y, position.z, true, true, true)
    SetEntityHeading(ped, position.w or 0.0)
    FreezeEntityPosition(ped, false)

    DisplayHud(true)
    DisplayRadar(true)

    DoScreenFadeIn(500)
end)

RegisterNetEvent('ox:client:syncMoney', function(money)
    OxClientData.money = money
end)

RegisterNetEvent('ox:client:syncMetadata', function(metadata)
    OxClientData.metadata = metadata
end)
