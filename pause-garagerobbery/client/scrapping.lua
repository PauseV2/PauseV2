--[[
    client/scrapping.lua
    Vehicle scrapping menu + the actual visual part removal. Rewards
    and success/fail are decided server-side; this file only renders
    the result using real vehicle natives so removed parts genuinely
    disappear (wheels detach, doors/hood/trunk break off, plate is
    cleared). Engine/turbo/transmission/etc are abstracted as
    "engine bay" loot since stock GTA vehicles don't expose separate
    meshes for those components - the hood must be removed first to
    gate access to them, which keeps the interaction realistic.
]]

GarageRobbery.ScrapVehicles = {}

local DOOR_LABELS = { [0] = 'Front Left', [1] = 'Front Right', [2] = 'Rear Left', [3] = 'Rear Right' }
local WHEEL_LABELS = { [0] = 'Front Left', [1] = 'Front Right', [2] = 'Rear Left', [3] = 'Rear Right' }

local function attemptScrap(netId, partType, index)
    local partConf = Config.VehicleParts[partType]
    if not partConf then return end

    if partConf.requiredItem and not GarageRobbery.HasItem(partConf.requiredItem) then
        GarageRobbery.Notify(Config.Locales.no_required_item, 'error')
        return
    end

    GarageRobbery.Progressbar(Config.Locales.scrapping, partConf.durationMs, function()
        TriggerServerEvent('garagerobbery:server:ScrapPart', netId, partType, index)
    end)
end

local function applyVisualRemoval(entity, partType, index)
    if partType == 'wheel' then
        BreakOffVehicleWheel(entity, index, true, true, true, false, false)
    elseif partType == 'door' then
        SetVehicleDoorBroken(entity, index, true)
    elseif partType == 'hood' then
        SetVehicleDoorBroken(entity, Config.VehicleParts.hood.boneIndex, true)
    elseif partType == 'trunk' then
        SetVehicleDoorBroken(entity, Config.VehicleParts.trunk.boneIndex, true)
    elseif partType == 'plate' then
        SetVehicleNumberPlateText(entity, '')
    elseif partType == 'engine' then
        SetVehicleEngineHealth(entity, 0.0)
        SetVehicleUndriveable(entity, true)
    end
end

RegisterNetEvent('garagerobbery:client:ScrapResult', function(netId, partType, index, success)
    if not success then return end
    local entity = GarageRobbery.ScrapVehicles[netId] or NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return end
    applyVisualRemoval(entity, partType, index)
end)

-- ---------------------------------------------------------------
-- Target menu building
-- ---------------------------------------------------------------
local function buildScrapOptions(netId)
    local options = {}

    for _, partType in ipairs(Config.ScrapMenuOrder) do
        local partConf = Config.VehicleParts[partType]
        if partType == 'door' or partType == 'wheel' then
            local labels = partType == 'door' and DOOR_LABELS or WHEEL_LABELS
            for _, index in ipairs(partConf.indices) do
                options[#options + 1] = {
                    icon = 'fas fa-wrench',
                    label = ('Remove %s (%s)'):format(partConf.label, labels[index] or index),
                    action = function() attemptScrap(netId, partType, index) end,
                }
            end
        else
            options[#options + 1] = {
                icon = 'fas fa-wrench',
                label = 'Remove ' .. partConf.label,
                action = function() attemptScrap(netId, partType, nil) end,
            }
        end
    end

    return options
end

function GarageRobbery.SetupScrapVehicles(vehiclePayload)
    GarageRobbery.ScrapVehicles = {}

    for _, data in ipairs(vehiclePayload) do
        local netId = data.netId
        CreateThread(function()
            local timeout = 0
            while not NetworkDoesEntityExistWithNetworkId(netId) and timeout < 100 do
                Wait(50)
                timeout = timeout + 1
            end

            local entity = NetworkGetEntityFromNetworkId(netId)
            timeout = 0
            while not DoesEntityExist(entity) and timeout < 100 do
                Wait(50)
                entity = NetworkGetEntityFromNetworkId(netId)
                timeout = timeout + 1
            end

            if DoesEntityExist(entity) then
                GarageRobbery.ScrapVehicles[netId] = entity
                GarageRobbery.AddTargetEntity(entity, buildScrapOptions(netId), Config.AntiAbuse.MaxVehicleDistance)
            end
        end)
    end
end

function GarageRobbery.CleanupScrapVehicles()
    for _, entity in pairs(GarageRobbery.ScrapVehicles) do
        if DoesEntityExist(entity) then
            GarageRobbery.RemoveTargetEntity(entity)
        end
    end
    GarageRobbery.ScrapVehicles = {}
end
