--[[
    client/main.lua
    Shared client-side namespace: QBCore handle, player data cache,
    and bridge helpers (target/inventory/progressbar/notify) used by
    every other client/*.lua file. Includes a lightweight fallback
    interaction system so the resource still functions (degraded)
    if qb-target isn't running.
]]

local QBCore = exports['qb-core']:GetCoreObject()

GarageRobbery = GarageRobbery or {}
GarageRobbery.QBCore = QBCore
GarageRobbery.PlayerData = QBCore.Functions.GetPlayerData()
GarageRobbery.CurrentInstance = nil -- { garageId, bucket, tier, shell, vehicles = { [netId] = { model, removed = {} } } }
GarageRobbery.FallbackZones = {}    -- used only when Config.Bridge.Target isn't running

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    GarageRobbery.PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    GarageRobbery.PlayerData = data
end)

-- ---------------------------------------------------------------
-- Notify / inventory bridge
-- ---------------------------------------------------------------
function GarageRobbery.Notify(message, ntype)
    QBCore.Functions.Notify(message, ntype or 'primary')
end

function GarageRobbery.HasItem(item, amount)
    return QBCore.Functions.HasItem(item, amount or 1)
end

-- ---------------------------------------------------------------
-- Progressbar bridge
-- ---------------------------------------------------------------
function GarageRobbery.Progressbar(label, duration, onFinish, onCancel)
    if Config.Bridge.Progressbar == 'qb' then
        QBCore.Functions.Progressbar('garagerobbery_action', label, duration, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function()
            if onFinish then onFinish() end
        end, function()
            if onCancel then onCancel() end
        end)
    else
        exports[Config.Bridge.Progressbar]:Progress({
            name = 'garagerobbery_action',
            duration = duration,
            label = label,
            useWhileDead = false,
            canCancel = true,
            controlDisables = {
                disableMovement = true,
                disableCarMovement = true,
                disableCombat = true,
            },
        }, function(cancelled)
            if cancelled then
                if onCancel then onCancel() end
            else
                if onFinish then onFinish() end
            end
        end)
    end
end

-- ---------------------------------------------------------------
-- Target bridge (qb-target with a minimal fallback)
-- ---------------------------------------------------------------
local function targetIsRunning()
    return GetResourceState(Config.Bridge.Target) == 'started'
end

function GarageRobbery.AddBoxZone(name, coords, length, width, heading, targetOptions, distance)
    if targetIsRunning() then
        exports[Config.Bridge.Target]:AddBoxZone(name, vector3(coords.x, coords.y, coords.z), length, width, {
            name = name,
            heading = heading or coords.w or 0.0,
            debugPoly = Config.Debug,
            minZ = coords.z - 1.5,
            maxZ = coords.z + 1.5,
        }, {
            options = targetOptions,
            distance = distance or 2.5,
        })
    else
        GarageRobbery.FallbackZones[name] = {
            getCoords = function() return coords end,
            options = targetOptions,
            distance = distance or 2.5,
        }
    end
end

function GarageRobbery.AddTargetEntity(entity, targetOptions, distance)
    if not DoesEntityExist(entity) then return end
    if targetIsRunning() then
        exports[Config.Bridge.Target]:AddTargetEntity(entity, {
            options = targetOptions,
            distance = distance or 2.5,
        })
    else
        GarageRobbery.FallbackZones['entity_' .. entity] = {
            getCoords = function() return DoesEntityExist(entity) and GetEntityCoords(entity) or nil end,
            options = targetOptions,
            distance = distance or 2.5,
        }
    end
end

function GarageRobbery.RemoveZone(name)
    if targetIsRunning() then
        exports[Config.Bridge.Target]:RemoveZone(name)
    else
        GarageRobbery.FallbackZones[name] = nil
    end
end

function GarageRobbery.RemoveTargetEntity(entity)
    if targetIsRunning() then
        pcall(function() exports[Config.Bridge.Target]:RemoveTargetEntity(entity) end)
    else
        GarageRobbery.FallbackZones['entity_' .. entity] = nil
    end
end

-- Fallback interaction loop: only does any work if qb-target is missing
-- and a fallback zone was registered, keeping the idle cost at ~0.
CreateThread(function()
    while true do
        local sleep = 750
        if not targetIsRunning() and next(GarageRobbery.FallbackZones) then
            sleep = 0
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)
            for name, zone in pairs(GarageRobbery.FallbackZones) do
                local coords = zone.getCoords()
                if coords then
                    local dist = #(pCoords - vector3(coords.x, coords.y, coords.z))
                    if dist <= zone.distance then
                        local opt = zone.options[1]
                        if opt then
                            DrawText3D(coords.x, coords.y, coords.z, ('[E] %s'):format(opt.label))
                            if IsControlJustReleased(0, 38) then
                                opt.action(nil)
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(sx, sy)
end

if Config.Debug then
    print('[pause-garagerobbery] client/main.lua loaded')
end
