--[[
    server/main.lua
    Shared server-side namespace, helpers and state for the garage
    robbery system. Every other server/*.lua file reads/writes through
    the `GarageRobbery` table defined here (all server scripts in a
    resource share one Lua VM, so this acts as our module system).
]]

local QBCore = exports['qb-core']:GetCoreObject()

GarageRobbery = GarageRobbery or {}
GarageRobbery.QBCore = QBCore

-- ---------------------------------------------------------------
-- Shared state
-- ---------------------------------------------------------------
GarageRobbery.ActiveInstances   = {}   -- [garageId] = instance table (see server/garage.lua)
GarageRobbery.PlayerInstance    = {}   -- [src] = garageId
GarageRobbery.GarageCooldowns   = {}   -- [garageId] = os.time() expiry
GarageRobbery.PlayerCooldowns   = {}   -- [citizenid] = os.time() expiry
GarageRobbery.HackState         = {}   -- [garageId] = { camerasDisabledUntil, lockedUntil, failCount, hackedOnce }
GarageRobbery.RateLimits        = {}   -- [src] = { [key] = GetGameTimer() }
GarageRobbery.NextBucket        = 1000

-- ---------------------------------------------------------------
-- Generic helpers
-- ---------------------------------------------------------------
function GarageRobbery.GetPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

function GarageRobbery.Notify(src, message, ntype)
    TriggerClientEvent('QBCore:Notify', src, message, ntype or 'primary')
end

function GarageRobbery.GetDistance(src, coords)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return 9999.0 end
    local pCoords = GetEntityCoords(ped)
    return #(pCoords - vector3(coords.x, coords.y, coords.z))
end

function GarageRobbery.IsNearCoords(src, coords, maxDist)
    return GarageRobbery.GetDistance(src, coords) <= (maxDist or Config.AntiAbuse.MaxInteractDistance)
end

-- Returns false (and notifies) if the player has called `key` again
-- inside the configured rate-limit window.
function GarageRobbery.RateLimitOk(src, key)
    local now = GetGameTimer()
    GarageRobbery.RateLimits[src] = GarageRobbery.RateLimits[src] or {}
    local last = GarageRobbery.RateLimits[src][key]
    if last and (now - last) < Config.AntiAbuse.EventRateLimitMs then
        return false
    end
    GarageRobbery.RateLimits[src][key] = now
    return true
end

function GarageRobbery.RollChance(percent)
    if not percent or percent <= 0 then return false end
    return math.random(1, 100) <= percent
end

function GarageRobbery.RandomAmount(min, max)
    min, max = min or 1, max or 1
    if max < min then max = min end
    return math.random(min, max)
end

function GarageRobbery.GenerateBucket()
    GarageRobbery.NextBucket = GarageRobbery.NextBucket + 1
    return GarageRobbery.NextBucket
end

-- ---------------------------------------------------------------
-- Inventory bridge (qb-inventory via QBCore player functions)
-- ---------------------------------------------------------------
function GarageRobbery.HasItem(src, item, amount)
    local Player = GarageRobbery.GetPlayer(src)
    if not Player then return false end
    amount = amount or 1
    local hasItem = Player.Functions.GetItemByName(item)
    return hasItem ~= nil and hasItem.amount >= amount
end

function GarageRobbery.AddItem(src, item, amount)
    local Player = GarageRobbery.GetPlayer(src)
    if not Player then return false end
    amount = amount or 1
    local success = Player.Functions.AddItem(item, amount)
    if success then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add')
    end
    return success
end

function GarageRobbery.RemoveItem(src, item, amount)
    local Player = GarageRobbery.GetPlayer(src)
    if not Player then return false end
    amount = amount or 1
    local success = Player.Functions.RemoveItem(item, amount)
    if success then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'remove')
    end
    return success
end

function GarageRobbery.AddMoney(src, amount, account)
    local Player = GarageRobbery.GetPlayer(src)
    if not Player then return false end
    return Player.Functions.AddMoney(account or Config.Selling.PaymentType, amount, 'garage-robbery-sell')
end

-- ---------------------------------------------------------------
-- Police bridge
-- ---------------------------------------------------------------
function GarageRobbery.IsPolice(src)
    local Player = GarageRobbery.GetPlayer(src)
    if not Player then return false end
    for _, job in ipairs(Config.PoliceJobs) do
        if Player.PlayerData.job.name == job and Player.PlayerData.job.onduty then
            return true
        end
    end
    return false
end

function GarageRobbery.GetOnDutyPoliceCount()
    local count = 0
    for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        if GarageRobbery.IsPolice(tonumber(playerId)) then
            count = count + 1
        end
    end
    return count
end

function GarageRobbery.GetOnDutyPoliceSources()
    local sources = {}
    for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        playerId = tonumber(playerId)
        if GarageRobbery.IsPolice(playerId) then
            sources[#sources + 1] = playerId
        end
    end
    return sources
end

-- ---------------------------------------------------------------
-- Player cooldowns (global, per citizenid)
-- ---------------------------------------------------------------
function GarageRobbery.IsPlayerOnCooldown(src)
    local Player = GarageRobbery.GetPlayer(src)
    if not Player then return true end
    local citizenid = Player.PlayerData.citizenid
    local expiry = GarageRobbery.PlayerCooldowns[citizenid]
    return expiry ~= nil and expiry > os.time()
end

function GarageRobbery.SetPlayerCooldown(src)
    local Player = GarageRobbery.GetPlayer(src)
    if not Player then return end
    GarageRobbery.PlayerCooldowns[Player.PlayerData.citizenid] = os.time() + Config.Cooldowns.GlobalPerPlayer
end

-- ---------------------------------------------------------------
-- Cleanup on disconnect
-- ---------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    GarageRobbery.RateLimits[src] = nil
    if GarageRobbery.PlayerInstance[src] and GarageRobbery.HandlePlayerLeftInstance then
        GarageRobbery.HandlePlayerLeftInstance(src, true)
    end
end)

if Config.Debug then
    print('[pause-garagerobbery] server/main.lua loaded')
end
