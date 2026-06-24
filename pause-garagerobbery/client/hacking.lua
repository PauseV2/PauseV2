--[[
    client/hacking.lua
    Electrical box interaction + hacking minigame. Ships with a
    built-in skill-check minigame so the resource works standalone;
    set Config.Bridge.UseQBMinigames = true to call out to
    qb-minigames instead (adjust the export call below to match the
    signature of the qb-minigames fork you run).
]]

local DIFFICULTY = {
    easy   = { rounds = 2, zoneWidth = 0.20, duration = 1400 },
    medium = { rounds = 3, zoneWidth = 0.14, duration = 1200 },
    hard   = { rounds = 4, zoneWidth = 0.09, duration = 1000 },
}

local function drawSkillBar(pos, zoneStart, zoneWidth)
    DrawRect(0.5, 0.85, 0.25, 0.03, 0, 0, 0, 180)
    DrawRect(0.5 - 0.125 + zoneStart * 0.25 + (zoneWidth * 0.25) / 2, 0.85, zoneWidth * 0.25, 0.03, 0, 200, 0, 200)
    DrawRect(0.5 - 0.125 + pos * 0.25, 0.85, 0.0025, 0.045, 255, 255, 255, 255)
end

local function skillCheckRound(zoneWidth, duration)
    local zoneStart = math.random(5, 95 - math.floor(zoneWidth * 100)) / 100
    local startTime = GetGameTimer()

    while true do
        local elapsed = GetGameTimer() - startTime
        local pos = (elapsed % duration) / duration
        drawSkillBar(pos, zoneStart, zoneWidth)

        if IsControlJustPressed(0, 38) then -- E
            return pos >= zoneStart and pos <= zoneStart + zoneWidth
        end

        if elapsed > duration * 3 then
            return false -- took too long on this round
        end

        Wait(0)
    end
end

local function runBuiltInMinigame(difficulty)
    local conf = DIFFICULTY[difficulty] or DIFFICULTY.medium

    for _ = 1, conf.rounds do
        if not skillCheckRound(conf.zoneWidth, conf.duration) then
            return false
        end
    end

    return true
end

function GarageRobbery.RunHackMinigame(hackSettings, cb)
    if Config.Bridge.UseQBMinigames then
        local ok, result = pcall(function()
            return exports[Config.Bridge.Minigames]:Hacking()
        end)
        cb(ok and result == true)
    else
        cb(runBuiltInMinigame(hackSettings.Difficulty))
    end
end

RegisterNetEvent('garagerobbery:client:StartHack', function(garageId, hackSettings)
    GarageRobbery.RunHackMinigame(hackSettings, function(success)
        TriggerServerEvent('garagerobbery:server:HackResult', garageId, success)
    end)
end)

-- ---------------------------------------------------------------
-- Electrical box zones
-- ---------------------------------------------------------------
local function setupElectricalBoxes()
    for _, garage in ipairs(Config.Garages) do
        GarageRobbery.AddBoxZone('garagerobbery_hackbox_' .. garage.id, garage.electricalBox, 1.0, 1.0, garage.electricalBox.w, {
            {
                icon = 'fas fa-bolt',
                label = 'Hack Electrical Box',
                action = function() TriggerServerEvent('garagerobbery:server:RequestHack', garage.id) end,
            },
        })
    end
end

CreateThread(function()
    Wait(1000)
    setupElectricalBoxes()
end)
