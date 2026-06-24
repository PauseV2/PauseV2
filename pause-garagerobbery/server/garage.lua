--[[
    server/garage.lua
    Garage instance lifecycle: entry validation, routing bucket
    allocation, scrap vehicle spawning/cleanup, and the electrical
    box hacking state machine (camera disable / lockouts).
]]

-- ---------------------------------------------------------------
-- Lookups
-- ---------------------------------------------------------------
function GarageRobbery.GetGarageById(garageId)
    for _, garage in ipairs(Config.Garages) do
        if garage.id == garageId then return garage end
    end
    return nil
end

local function getHackState(garageId)
    GarageRobbery.HackState[garageId] = GarageRobbery.HackState[garageId] or {
        camerasDisabledUntil = 0,
        lockedUntil = 0,
        failCount = 0,
        hackedOnce = false,
        pending = nil,
    }
    return GarageRobbery.HackState[garageId]
end

function GarageRobbery.AreCamerasDisabled(garageId)
    local state = getHackState(garageId)
    return state.camerasDisabledUntil > os.time()
end

-- ---------------------------------------------------------------
-- Electrical box hacking
-- ---------------------------------------------------------------
RegisterNetEvent('garagerobbery:server:RequestHack', function(garageId)
    local src = source
    if not GarageRobbery.RateLimitOk(src, 'requestHack') then return end

    local garage = GarageRobbery.GetGarageById(garageId)
    if not garage then return end

    if not GarageRobbery.IsNearCoords(src, garage.electricalBox, Config.AntiAbuse.MaxInteractDistance) then
        GarageRobbery.Notify(src, Config.Locales.too_far, 'error')
        return
    end

    local state = getHackState(garageId)
    if state.lockedUntil > os.time() then
        GarageRobbery.Notify(src, Config.Locales.hack_locked_out, 'error')
        return
    end

    if Config.HackSettings.RequiredItem then
        if not GarageRobbery.HasItem(src, Config.HackSettings.RequiredItem) then
            GarageRobbery.Notify(src, Config.Locales.no_required_item, 'error')
            return
        end
    end

    state.pending = { src = src, startedAt = GetGameTimer() }
    TriggerClientEvent('garagerobbery:client:StartHack', src, garageId, Config.HackSettings)
end)

RegisterNetEvent('garagerobbery:server:HackResult', function(garageId, success)
    local src = source
    local garage = GarageRobbery.GetGarageById(garageId)
    if not garage then return end

    local state = getHackState(garageId)
    local pending = state.pending
    state.pending = nil

    if not pending or pending.src ~= src then return end
    local elapsed = GetGameTimer() - pending.startedAt
    if elapsed > (Config.HackSettings.HackTimeLimit + 3000) then return end
    if not GarageRobbery.IsNearCoords(src, garage.electricalBox, Config.AntiAbuse.MaxInteractDistance) then return end

    if success then
        state.camerasDisabledUntil = os.time() + Config.HackSettings.CameraDisableDuration
        state.failCount = 0
        state.hackedOnce = true
        GarageRobbery.Notify(src, Config.Locales.hack_success, 'success')
    else
        state.failCount = state.failCount + 1
        if state.failCount >= Config.HackSettings.MaxAttemptsBeforeLockout then
            state.lockedUntil = os.time() + Config.HackSettings.LockoutDuration
            state.failCount = 0
        end
        GarageRobbery.Notify(src, Config.Locales.hack_failed, 'error')
        GarageRobbery.TriggerPoliceAlert(garage, src, Config.HackSettings.PoliceAlertChanceOnFail, 'hack_failed')
    end
end)

-- ---------------------------------------------------------------
-- Scrap vehicle spawning
-- ---------------------------------------------------------------
local function spawnScrapVehicle(model, coords, bucket)
    local hash = GetHashKey(model)
    local veh = CreateVehicleServerSetter(hash, 'automobile', coords.x, coords.y, coords.z, coords.w)

    local attempts = 0
    while not DoesEntityExist(veh) and attempts < 50 do
        Wait(50)
        attempts = attempts + 1
    end
    if not DoesEntityExist(veh) then return nil end

    SetEntityRoutingBucket(veh, bucket)
    SetVehicleDirtLevel(veh, 15.0)
    SetVehicleEngineHealth(veh, 300.0)
    SetVehicleBodyHealth(veh, 600.0)
    SetVehicleDoorsLocked(veh, 1)
    SetEntityAsMissionEntity(veh, true, true)
    FreezeEntityPosition(veh, true)
    SetVehicleNumberPlateText(veh, ('STLN%03d'):format(math.random(0, 999)))

    return veh
end

-- ---------------------------------------------------------------
-- Instance lifecycle
-- ---------------------------------------------------------------
function GarageRobbery.StartInstance(src, garage)
    local bucket = GarageRobbery.GenerateBucket()
    local shell = Config.Shells[garage.tier]
    local tierConf = Config.Tiers[garage.tier]
    local hackedActive = GarageRobbery.AreCamerasDisabled(garage.id)

    local instance = {
        garageId = garage.id,
        tier = garage.tier,
        bucket = bucket,
        owner = src,
        vehicles = {},
        lootedSpots = {},
        startedAt = os.time(),
        hacked = hackedActive,
        lastRaidCall = 0,
    }

    GarageRobbery.ActiveInstances[garage.id] = instance
    GarageRobbery.PlayerInstance[src] = garage.id

    if Config.Cooldowns.StartCooldownOnEntry then
        GarageRobbery.GarageCooldowns[garage.id] = os.time() + Config.Cooldowns.PerGarage
    end
    GarageRobbery.SetPlayerCooldown(src)
    SetPlayerRoutingBucket(src, bucket)

    local models = Config.ScrapVehicleModels[garage.tier] or { 'blista' }
    local spawnCount = math.min(tierConf.vehicleSpawnCount, #shell.vehicleSpawns)

    local vehiclePayload = {}
    for i = 1, spawnCount do
        local coords = shell.vehicleSpawns[i]
        local model = models[math.random(#models)]
        local veh = spawnScrapVehicle(model, coords, bucket)
        if veh then
            local netId = NetworkGetNetworkIdFromEntity(veh)
            instance.vehicles[netId] = { entity = veh, model = model, removed = {} }
            vehiclePayload[#vehiclePayload + 1] = { netId = netId, model = model, coords = coords }
        end
    end

    if not hackedActive then
        GarageRobbery.TriggerPoliceAlert(garage, src, Config.HackSettings.PoliceAlertChanceNoHack, 'breach')
    end

    TriggerClientEvent('garagerobbery:client:EnterInstance', src, garage, bucket, vehiclePayload, shell)
end

function GarageRobbery.EndInstance(garageId, src)
    local instance = GarageRobbery.ActiveInstances[garageId]
    if not instance then return end

    for _, data in pairs(instance.vehicles) do
        if data.entity and DoesEntityExist(data.entity) then
            DeleteEntity(data.entity)
        end
    end

    if src and GetPlayerName(src) then
        SetPlayerRoutingBucket(src, 0)
    end

    GarageRobbery.PlayerInstance[src] = nil
    GarageRobbery.ActiveInstances[garageId] = nil

    if not Config.Cooldowns.StartCooldownOnEntry then
        GarageRobbery.GarageCooldowns[garageId] = os.time() + Config.Cooldowns.PerGarage
    end
end

function GarageRobbery.HandlePlayerLeftInstance(src)
    local garageId = GarageRobbery.PlayerInstance[src]
    if garageId then
        GarageRobbery.EndInstance(garageId, src)
    end
end

function GarageRobbery.GetPlayerInstance(src)
    local garageId = GarageRobbery.PlayerInstance[src]
    if not garageId then return nil end
    return GarageRobbery.ActiveInstances[garageId], garageId
end

-- ---------------------------------------------------------------
-- Entry request
-- ---------------------------------------------------------------
RegisterNetEvent('garagerobbery:server:RequestEntry', function(garageId)
    local src = source
    if not GarageRobbery.RateLimitOk(src, 'requestEntry') then return end

    local garage = GarageRobbery.GetGarageById(garageId)
    if not garage then return end

    if GarageRobbery.PlayerInstance[src] then
        GarageRobbery.Notify(src, Config.Locales.instance_full, 'error')
        return
    end

    -- ActiveInstances is keyed per-garage, so only one instance can ever
    -- be active on a given garage at a time - this must be checked
    -- explicitly and not inferred from the cooldown timestamp, since
    -- Config.Cooldowns.StartCooldownOnEntry = false delays that write
    -- until the robbery ends, leaving a window for a second player to
    -- start a colliding instance on the same garageId.
    if GarageRobbery.ActiveInstances[garageId] then
        GarageRobbery.Notify(src, Config.Locales.garage_on_cooldown, 'error')
        return
    end

    if GarageRobbery.IsPlayerOnCooldown(src) then
        GarageRobbery.Notify(src, Config.Locales.player_on_cooldown, 'error')
        return
    end

    local cooldownExpiry = GarageRobbery.GarageCooldowns[garageId]
    if cooldownExpiry and cooldownExpiry > os.time() then
        GarageRobbery.Notify(src, Config.Locales.garage_on_cooldown, 'error')
        return
    end

    if not GarageRobbery.IsNearCoords(src, garage.entry, Config.AntiAbuse.MaxInteractDistance) then
        GarageRobbery.Notify(src, Config.Locales.too_far, 'error')
        return
    end

    local tierConf = Config.Tiers[garage.tier]
    if tierConf.minPolice and tierConf.minPolice > 0 then
        if GarageRobbery.GetOnDutyPoliceCount() < tierConf.minPolice then
            GarageRobbery.Notify(src, Config.Locales.not_enough_police, 'error')
            return
        end
    end

    GarageRobbery.StartInstance(src, garage)
end)

RegisterNetEvent('garagerobbery:server:RequestExit', function()
    local src = source
    local garageId = GarageRobbery.PlayerInstance[src]
    if not garageId then return end
    GarageRobbery.EndInstance(garageId, src)
end)

-- Hook for external camera resources: query whether a garage's
-- cameras are currently disabled before granting a live feed.
exports('AreCamerasDisabled', function(garageId)
    return GarageRobbery.AreCamerasDisabled(garageId)
end)
