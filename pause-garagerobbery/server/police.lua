--[[
    server/police.lua
    Dispatch alerts, evidence rolls and the raid system. Kept
    separate from garage.lua so server owners can swap in their own
    dispatch/camera resource without touching instance logic.
]]

-- ---------------------------------------------------------------
-- Dispatch alerts
-- ---------------------------------------------------------------
function GarageRobbery.TriggerPoliceAlert(garage, suspectSrc, chance, reason)
    if not GarageRobbery.RollChance(chance) then return end

    if Config.PoliceSettings.RequiredOnlineToTriggerAlert > 0
        and GarageRobbery.GetOnDutyPoliceCount() < Config.PoliceSettings.RequiredOnlineToTriggerAlert then
        return
    end

    local payload = {
        garageId = garage.id,
        label = garage.label,
        coords = garage.entry,
        tier = garage.tier,
        reason = reason, -- 'breach' | 'hack_failed'
    }

    -- Hook for a custom dispatch resource (ps-dispatch, cd_dispatch, etc.)
    if Config.PoliceSettings.DispatchEvent then
        TriggerEvent(Config.PoliceSettings.DispatchEvent, payload)
    end

    if Config.PoliceSettings.UseBuiltInFallback then
        for _, policeSrc in ipairs(GarageRobbery.GetOnDutyPoliceSources()) do
            TriggerClientEvent('garagerobbery:client:PoliceAlert', policeSrc, payload)
        end
    end
end

-- ---------------------------------------------------------------
-- Evidence
-- ---------------------------------------------------------------
function GarageRobbery.MaybeDropEvidence(src, garage)
    if not GarageRobbery.RollChance(Config.PoliceSettings.EvidenceChance) then return end

    local Player = GarageRobbery.GetPlayer(src)
    if not Player then return end

    local payload = {
        garageId = garage.id,
        label = garage.label,
        coords = garage.entry,
        kind = ({ 'fingerprint', 'blood' })[math.random(1, 2)],
    }

    for _, policeSrc in ipairs(GarageRobbery.GetOnDutyPoliceSources()) do
        TriggerClientEvent('garagerobbery:client:EvidenceFound', policeSrc, payload)
    end
end

-- ---------------------------------------------------------------
-- Raid system
-- ---------------------------------------------------------------
RegisterNetEvent('garagerobbery:server:CallRaid', function(garageId)
    local src = source
    if not Config.PoliceSettings.RaidSystem.Enabled then return end
    if not GarageRobbery.RateLimitOk(src, 'callRaid') then return end

    if not GarageRobbery.IsPolice(src) then return end

    local instance = GarageRobbery.ActiveInstances[garageId]
    if not instance then
        GarageRobbery.Notify(src, 'No active robbery there.', 'error')
        return
    end

    local now = os.time()
    if instance.lastRaidCall and (now - instance.lastRaidCall) < Config.PoliceSettings.RaidSystem.Cooldown then
        GarageRobbery.Notify(src, 'Raid already called recently.', 'error')
        return
    end

    if GarageRobbery.GetOnDutyPoliceCount() < Config.PoliceSettings.RaidSystem.RequiredPoliceCount then
        GarageRobbery.Notify(src, Config.Locales.not_enough_police, 'error')
        return
    end

    instance.lastRaidCall = now
    local garage = GarageRobbery.GetGarageById(garageId)

    TriggerClientEvent('garagerobbery:client:RaidCalled', instance.owner, garage)
    for _, policeSrc in ipairs(GarageRobbery.GetOnDutyPoliceSources()) do
        TriggerClientEvent('garagerobbery:client:RaidConfirmed', policeSrc, garage, instance.bucket)
    end
end)
