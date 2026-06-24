--[[
    client/garage.lua
    Garage entry/exit points, blips, and instance enter/leave flow.
    Loot prop and scrap vehicle setup live in their own files and are
    just invoked from here when an instance starts/ends.
]]

local function buildExitOptions()
    local options = {
        {
            icon = 'fas fa-door-open',
            label = 'Leave Garage',
            action = function() GarageRobbery.LeaveInstance() end,
        },
    }

    if Config.Selling.SellAtExit then
        table.insert(options, {
            icon = 'fas fa-hand-holding-dollar',
            label = 'Sell Stolen Parts',
            action = function() GarageRobbery.OpenSellMenu() end,
        })
        table.insert(options, {
            icon = 'fas fa-recycle',
            label = 'Scrap Parts into Materials',
            action = function() GarageRobbery.OpenScrapMenu() end,
        })
    end

    return options
end

-- ---------------------------------------------------------------
-- Static world setup: blips + entry zones
-- ---------------------------------------------------------------
local function setupGarages()
    for _, garage in ipairs(Config.Garages) do
        if garage.blip then
            local blip = AddBlipForCoord(garage.entry.x, garage.entry.y, garage.entry.z)
            SetBlipSprite(blip, garage.blip.sprite)
            SetBlipColour(blip, garage.blip.color)
            SetBlipScale(blip, garage.blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(garage.label)
            EndTextCommandSetBlipName(blip)
        end

        GarageRobbery.AddBoxZone('garagerobbery_entry_' .. garage.id, garage.entry, 1.5, 1.5, garage.entry.w, {
            {
                icon = 'fas fa-warehouse',
                label = 'Breach Garage',
                action = function() TriggerServerEvent('garagerobbery:server:RequestEntry', garage.id) end,
            },
        })
    end
end

CreateThread(function()
    Wait(1000)
    setupGarages()
end)

-- ---------------------------------------------------------------
-- Instance enter / leave
-- ---------------------------------------------------------------
RegisterNetEvent('garagerobbery:client:EnterInstance', function(garage, bucket, vehiclePayload, shell)
    GarageRobbery.CurrentInstance = {
        garageId = garage.id,
        garage = garage,
        tier = garage.tier,
        bucket = bucket,
        shell = shell,
    }

    local ped = PlayerPedId()
    DoScreenFadeOut(300)
    Wait(350)
    SetEntityCoords(ped, shell.playerSpawn.x, shell.playerSpawn.y, shell.playerSpawn.z, false, false, false, true)
    SetEntityHeading(ped, shell.playerSpawn.w)
    Wait(150)
    DoScreenFadeIn(300)

    GarageRobbery.Notify(Config.Locales.entered_garage, 'success')
    GarageRobbery.SetupLootSpots(shell)
    GarageRobbery.SetupScrapVehicles(vehiclePayload)
    GarageRobbery.AddBoxZone('garagerobbery_exit_' .. garage.id, shell.exitPoint, 1.5, 1.5, shell.exitPoint.w, buildExitOptions())
end)

function GarageRobbery.LeaveInstance()
    local instance = GarageRobbery.CurrentInstance
    if not instance then return end

    GarageRobbery.CleanupLootSpots()
    GarageRobbery.CleanupScrapVehicles()
    GarageRobbery.RemoveZone('garagerobbery_exit_' .. instance.garageId)

    TriggerServerEvent('garagerobbery:server:RequestExit')

    local ped = PlayerPedId()
    DoScreenFadeOut(300)
    Wait(350)
    SetEntityCoords(ped, instance.garage.entry.x, instance.garage.entry.y, instance.garage.entry.z, false, false, false, true)
    SetEntityHeading(ped, instance.garage.entry.w)
    Wait(150)
    DoScreenFadeIn(300)

    GarageRobbery.CurrentInstance = nil
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if GarageRobbery.CurrentInstance then
        TriggerServerEvent('garagerobbery:server:RequestExit')
    end
end)
