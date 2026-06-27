OxInvState = { open = false, mode = nil, secondaryId = nil }

function OxInvOpen(mode, secondaryId)
    local ok, playerSnap = OxInvTriggerCallback('ox_inventory:getInventory', 'player')
    if not ok then return end

    local secondarySnap, shopData

    if mode == 'stash' and secondaryId then
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

    cb({ ok = true, fromSnapshot = fromSnapshot, toSnapshot = toSnapshot })
end)

RegisterNUICallback('useItem', function(data, cb)
    local ok, snapshot = OxInvTriggerCallback('ox_inventory:useItem', data.slot)

    if not ok then
        cb({ ok = false, error = snapshot })
        return
    end

    cb({ ok = true, snapshot = snapshot })
end)

RegisterNUICallback('buyItem', function(data, cb)
    local ok, snapshot = OxInvTriggerCallback('ox_inventory:buyItem', data)

    if not ok then
        cb({ ok = false, error = snapshot })
        return
    end

    cb({ ok = true, snapshot = snapshot })
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
