OxInvState = { open = false, mode = nil, secondaryId = nil }
Hotbar = {} -- [1..5] = inventory slot number, purely a client-side reference into the player's own inventory

local function FindSnapshotEntry(snapshot, slot)
    if not snapshot then return nil end

    for _, entry in ipairs(snapshot.items) do
        if entry.slot == slot then return entry end
    end

    return nil
end

-- Hotbar slots only ever hold a slot *number*, not an item identity, so once
-- whatever used to be in that slot is gone (used up, dropped, given away,
-- moved out), the assignment is stale and needs to drop automatically.
local function SyncHotbar(snapshot)
    if not snapshot then return end

    local changed = false

    for i = 1, 5 do
        local slot = Hotbar[i]
        if slot and not FindSnapshotEntry(snapshot, slot) then
            Hotbar[i] = nil
            changed = true
        end
    end

    if changed then
        SendNUIMessage({ action = 'hotbar', hotbar = Hotbar })
    end
end

function OxInvUseHotbarSlot(index)
    local slot = Hotbar[index]
    if not slot then return end

    local ok, snapshot = OxInvTriggerCallback('ox_inventory:useItem', slot)
    if not ok then return end

    SyncHotbar(snapshot)
end

function OxInvOpen(mode, secondaryId)
    local ok, playerSnap = OxInvTriggerCallback('ox_inventory:getInventory', 'player')
    if not ok then return end

    local secondarySnap, shopData

    if (mode == 'stash' or mode == 'ground' or mode == 'trunk') and secondaryId then
        local stashOk, snap = OxInvTriggerCallback('ox_inventory:getInventory', secondaryId)
        if not stashOk then return end
        secondarySnap = snap
    elseif mode == 'shop' and secondaryId then
        local shopOk, data = OxInvTriggerCallback('ox_inventory:getShop', secondaryId)
        if not shopOk then return end
        shopData = data
    end

    OxInvState.open = true
    OxInvState.mode = mode
    OxInvState.secondaryId = secondaryId

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        mode = mode,
        secondaryId = secondaryId,
        player = playerSnap,
        secondary = secondarySnap,
        shop = shopData,
        hotbar = Hotbar,
    })
end

function OxInvClose()
    OxInvState.open = false
    OxInvState.mode = nil
    OxInvState.secondaryId = nil

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterCommand('oxinventory:toggle', function()
    if OxInvState.open then
        OxInvClose()
    else
        OxInvOpen('inventory')
    end
end, false)

RegisterKeyMapping('oxinventory:toggle', 'Open Inventory', 'keyboard', 'F2')

RegisterNUICallback('close', function(_, cb)
    OxInvClose()
    cb({ ok = true })
end)

RegisterNUICallback('moveItem', function(data, cb)
    local ok, fromSnapshot, toSnapshot = OxInvTriggerCallback('ox_inventory:moveItem', data)

    if not ok then
        cb({ ok = false, error = fromSnapshot })
        return
    end

    SyncHotbar(data.toInv == 'player' and toSnapshot or fromSnapshot)
    cb({ ok = true, fromSnapshot = fromSnapshot, toSnapshot = toSnapshot })
end)

RegisterNUICallback('useItem', function(data, cb)
    local ok, snapshot = OxInvTriggerCallback('ox_inventory:useItem', data.slot)

    if not ok then
        cb({ ok = false, error = snapshot })
        return
    end

    SyncHotbar(snapshot)
    cb({ ok = true, snapshot = snapshot })
end)

RegisterNUICallback('buyItem', function(data, cb)
    local ok, snapshot = OxInvTriggerCallback('ox_inventory:buyItem', data)

    if not ok then
        cb({ ok = false, error = snapshot })
        return
    end

    SyncHotbar(snapshot)
    cb({ ok = true, snapshot = snapshot })
end)

RegisterNUICallback('splitStack', function(data, cb)
    local ok, snapshot = OxInvTriggerCallback('ox_inventory:splitStack', data)

    if not ok then
        cb({ ok = false, error = snapshot })
        return
    end

    SyncHotbar(snapshot)
    cb({ ok = true, snapshot = snapshot })
end)

RegisterNUICallback('setHotbar', function(data, cb)
    Hotbar[data.index] = data.slot
    cb({ ok = true })
end)

RegisterNUICallback('clearHotbar', function(data, cb)
    Hotbar[data.index] = nil
    cb({ ok = true })
end)

RegisterNUICallback('dropItem', function(data, cb)
    local model = GetHashKey(Config.DropProp)
    RequestModel(model)

    local timeout = 0
    while not HasModelLoaded(model) and timeout < 200 do
        Wait(10)
        timeout = timeout + 1
    end

    if not HasModelLoaded(model) then
        cb({ ok = false, error = 'failed to load drop prop' })
        return
    end

    local coords = GetEntityCoords(PlayerPedId())
    local obj = CreateObject(model, coords.x, coords.y, coords.z - 0.9, true, true, false)
    PlaceObjectOnGroundProperly(obj)

    local netId = NetworkGetNetworkIdFromEntity(obj)
    local ok, snapshot = OxInvTriggerCallback('ox_inventory:dropItem', { slot = data.slot, count = data.count, netId = netId })

    if not ok then
        DeleteObject(obj)
        cb({ ok = false, error = snapshot })
        return
    end

    SyncHotbar(snapshot)
    cb({ ok = true, snapshot = snapshot })
end)

RegisterNUICallback('giveItem', function(data, cb)
    local coords = GetEntityCoords(PlayerPedId())
    local target, closestDist = nil, Config.GiveRange

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local dist = #(coords - GetEntityCoords(GetPlayerPed(playerId)))
            if dist <= closestDist then
                target, closestDist = playerId, dist
            end
        end
    end

    if not target then
        cb({ ok = false, error = 'no nearby player to give to' })
        return
    end

    local ok, snapshot = OxInvTriggerCallback('ox_inventory:giveItem', {
        target = GetPlayerServerId(target),
        slot = data.slot,
        count = data.count,
    })

    if not ok then
        cb({ ok = false, error = snapshot })
        return
    end

    SyncHotbar(snapshot)
    cb({ ok = true, snapshot = snapshot })
end)

RegisterNetEvent('ox_inventory:client:removeGroundProp', function(netId)
    local obj = NetworkGetEntityFromNetworkId(netId)
    if obj ~= 0 and DoesEntityExist(obj) then
        DeleteObject(obj)
    end
end)

RegisterNetEvent('ox_inventory:client:notify', function(message)
    SendNUIMessage({ action = 'notify', message = message })
end)

-- Z is a pure modifier here, not bound to anything on its own - holding it
-- and pressing 1-5 uses whatever's in that hotbar slot. The +/- command
-- prefix is FiveM's documented way to track key-down/key-up state.
local zHeld = false

RegisterCommand('+oxinv:hotbarmod', function() zHeld = true end, false)
RegisterCommand('-oxinv:hotbarmod', function() zHeld = false end, false)
RegisterKeyMapping('+oxinv:hotbarmod', 'Hotbar Use Modifier', 'keyboard', 'Z')

for i = 1, 5 do
    RegisterCommand('oxinv:hotbar' .. i, function()
        if zHeld and not OxInvState.open then
            OxInvUseHotbarSlot(i)
        end
    end, false)

    RegisterKeyMapping('oxinv:hotbar' .. i, 'Use Hotbar Slot ' .. i, 'keyboard', tostring(i))
end

-- Ground bags: any player's dropped prop is visible to everyone since
-- CreateObject(..., true, ...) is networked by the engine automatically.
CreateThread(function()
    while true do
        Wait(750)

        if not OxInvState.open then
            local coords = GetEntityCoords(PlayerPedId())
            local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 2.0, GetHashKey(Config.DropProp), false, false, false)

            if obj ~= 0 then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('[E] Pick up')
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustReleased(0, 38) then
                    local netId = NetworkGetNetworkIdFromEntity(obj)
                    OxInvOpen('ground', 'ground:' .. netId)
                end
            end
        end
    end
end)

-- Proves the generic stash path: proximity-checked client-side for the
-- prompt, re-checked server-side (Config.StashRange) before any data loads.
CreateThread(function()
    while true do
        Wait(500)

        if not OxInvState.open then
            local coords = GetEntityCoords(PlayerPedId())
            local nearestId, nearestDist

            for id, stash in pairs(Config.Stashes) do
                local dist = #(coords - vector3(stash.coords.x, stash.coords.y, stash.coords.z))
                if dist <= Config.StashRange and (not nearestDist or dist < nearestDist) then
                    nearestId, nearestDist = id, dist
                end
            end

            if nearestId then
                local stash = Config.Stashes[nearestId]
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(('[E] Open %s'):format(stash.label))
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustReleased(0, 38) then
                    OxInvOpen('stash', nearestId)
                end
            end
        end
    end
end)

-- There's no native GetClosestVehicle, so we walk the engine's pool of
-- spawned vehicle entities ourselves and pick the nearest one in range.
local function GetNearbyVehicle(coords, maxDist)
    local nearest, nearestDist

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        local dist = #(coords - GetEntityCoords(vehicle))
        if dist <= maxDist and (not nearestDist or dist < nearestDist) then
            nearest, nearestDist = vehicle, dist
        end
    end

    return nearest
end

-- Trunk inventory: the label sent to the server is session-local
-- ('trunk:<netId>') so the server can re-verify distance against the live
-- entity, but it resolves internally to a persistent 'trunk:<plate>' storage
-- key so contents survive the vehicle despawning and respawning.
CreateThread(function()
    while true do
        Wait(500)

        if not OxInvState.open then
            local coords = GetEntityCoords(PlayerPedId())
            local vehicle = GetNearbyVehicle(coords, Config.TrunkRange)

            if vehicle then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('[E] Open Trunk')
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustReleased(0, 38) then
                    local netId = NetworkGetNetworkIdFromEntity(vehicle)
                    OxInvOpen('trunk', 'trunk:' .. netId)
                end
            end
        end
    end
end)
