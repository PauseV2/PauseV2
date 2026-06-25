-- ============================================================
-- Ambush meetings. Combat plays out entirely client side; once the ambush
-- is resolved (won or fled) the result is reported back to the server,
-- which is the only place loot/trust/heat actually gets applied.
-- ============================================================

if not Config.Toggle.Traps then return end

local activePeds = {}
local activeVehicle = nil
local activeDeliveryId = nil
local resolved = false

local function cleanupAmbush()
    for _, ped in ipairs(activePeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    activePeds = {}
    if activeVehicle and DoesEntityExist(activeVehicle) then
        DeleteEntity(activeVehicle)
    end
    activeVehicle = nil
end

RegisterNetEvent('ovi:client:spawnAmbush', function(deliveryId, coords, ambushCfg)
    cleanupAmbush()
    activeDeliveryId = deliveryId
    resolved = false

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    if ambushCfg.vehicleModel then
        local vModel = joaat(ambushCfg.vehicleModel)
        RequestModel(vModel)
        while not HasModelLoaded(vModel) do Wait(10) end
        local heading = GetHeadingFromVector_2d(playerCoords.x - coords.x, playerCoords.y - coords.y)
        activeVehicle = CreateVehicle(vModel, coords.x, coords.y, coords.z, heading, true, false)
        SetVehicleDoorsLocked(activeVehicle, 1)
    end

    for i = 1, ambushCfg.npcCount do
        local model = joaat('g_m_y_lost_01')
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end

        local offset = vector3(coords.x + math.random(-3, 3) * 1.0, coords.y + math.random(-3, 3) * 1.0, coords.z)
        local ped = CreatePed(4, model, offset.x, offset.y, offset.z, 0.0, true, true)

        SetPedAsEnemy(ped, true)
        SetPedRelationshipGroupHash(ped, GetHashKey('HATES_PLAYER'))
        SetPedCombatAttributes(ped, 46, true)
        SetPedAccuracy(ped, ambushCfg.accuracy)
        SetPedCombatAbility(ped, ambushCfg.combatAbility)
        GiveWeaponToPed(ped, GetHashKey(OVI.RandomFrom(ambushCfg.weapons)), 250, false, true)
        TaskCombatPed(ped, playerPed, 0, 16)

        activePeds[#activePeds + 1] = ped
    end

    QBCore.Functions.Notify('This feels like a setup!', 'error')

    CreateThread(function()
        while not resolved do
            Wait(1500)

            local allDead = true
            for _, ped in ipairs(activePeds) do
                if DoesEntityExist(ped) and not IsEntityDead(ped) then
                    allDead = false
                    break
                end
            end

            if allDead and #activePeds > 0 then
                resolved = true
                QBCore.Functions.Notify('Search the vehicle before someone shows up.', 'primary')
                if activeVehicle and DoesEntityExist(activeVehicle) then
                    exports['qb-target']:AddTargetEntity(activeVehicle, {
                        options = {
                            {
                                type = 'client',
                                icon = 'fas fa-search',
                                label = 'Search Trap Vehicle',
                                action = function()
                                    TriggerServerEvent('ovi:server:trapResult', activeDeliveryId, 'won')
                                    cleanupAmbush()
                                end,
                            },
                        },
                        distance = 2.5,
                    })
                else
                    TriggerServerEvent('ovi:server:trapResult', activeDeliveryId, 'won')
                    cleanupAmbush()
                end
                return
            end

            local dist = #(GetEntityCoords(PlayerPedId()) - coords)
            if dist > Config.Traps.fleeRadius then
                resolved = true
                TriggerServerEvent('ovi:server:trapResult', activeDeliveryId, 'fled')
                cleanupAmbush()
                return
            end
        end
    end)
end)
