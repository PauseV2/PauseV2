AddEventHandler('ox:server:playerLoaded', function(source, citizenid)
    OxInv.Load(citizenid, 'player', citizenid, Config.MaxWeight, Config.MaxSlots)
end)

AddEventHandler('ox:server:playerUnloaded', function(_, citizenid)
    OxInv.Close(citizenid)
end)

-- Cross-resource exports return plain data (msgpack strips metatables), so
-- this only ever reads fields off the result - never call methods on it.
function OxInv.GetCitizenId(source)
    local playerData = exports['ox-core']:GetPlayer(source)
    return playerData and playerData.citizenid or nil
end

local function DistanceTo(source, coords)
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local dx, dy, dz = playerCoords.x - coords.x, playerCoords.y - coords.y, playerCoords.z - coords.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- 'player' always resolves to the caller's own citizenid - the client can
-- never request another player's inventory by id. Stashes/ground bags are
-- server-side distance-checked before the inventory is even loaded/touched.
local function ResolveInvId(source, label)
    if label == 'player' then
        return OxInv.GetCitizenId(source)
    end

    if label:sub(1, 7) == 'ground:' then
        local inv = OxInv.cache[label]
        if not inv or DistanceTo(source, inv.coords) > Config.StashRange then
            return nil
        end

        return label
    end

    local stash = Config.Stashes[label]
    if not stash then return nil end

    if DistanceTo(source, stash.coords) > Config.StashRange then
        return nil
    end

    OxInv.Load(label, 'stash', stash.label, stash.maxWeight, stash.slots)
    return label
end

-- Ground bags are ephemeral - once the last item leaves one, evict it from
-- cache and tell every client to despawn the matching networked prop.
local function CleanupGroundIfEmpty(id)
    local inv = OxInv.cache[id]
    if not inv or not inv.ephemeral or not OxInv.IsEmpty(inv) then return end

    local netId = tonumber(id:match('^ground:(%d+)$'))
    OxInv.Destroy(id)

    if netId then
        TriggerClientEvent('ox_inventory:client:removeGroundProp', -1, netId)
    end
end

OxInvCallbacks.Register('ox_inventory:getInventory', function(source, label)
    local id = ResolveInvId(source, label)
    if not id then return false, 'invalid inventory' end
    return true, OxInv.Snapshot(id)
end)

OxInvCallbacks.Register('ox_inventory:moveItem', function(source, data)
    local fromId = ResolveInvId(source, data.fromInv)
    local toId = ResolveInvId(source, data.toInv)
    if not fromId or not toId then return false, 'invalid inventory' end

    local ok, err = OxInv.MoveItem(fromId, data.fromSlot, toId, data.toSlot, data.count)
    if not ok then return false, err end

    CleanupGroundIfEmpty(fromId)

    return true, OxInv.Snapshot(fromId), OxInv.Snapshot(toId)
end)

OxInvCallbacks.Register('ox_inventory:useItem', function(source, slot)
    local citizenid = OxInv.GetCitizenId(source)
    if not citizenid then return false, 'character not loaded' end

    local inv = OxInv.Get(citizenid)
    if not inv then return false, 'inventory not loaded' end

    local entry = inv.items[slot]
    if not entry then return false, 'empty slot' end

    local def = Items[entry.name]
    if not def then return false, 'invalid item' end

    if def.type ~= 'food' and def.type ~= 'drink' and def.type ~= 'medical' then
        return false, 'item is not usable'
    end

    local removed = OxInv.RemoveItem(citizenid, entry.name, 1)
    if not removed then return false, 'failed to use item' end

    local playerData = exports['ox-core']:GetPlayer(source)
    local current, key

    if def.type == 'medical' then
        key = 'health'
        current = (playerData and playerData.metadata and playerData.metadata.health) or 0
    else
        key = def.type == 'food' and 'hunger' or 'thirst'
        current = (playerData and playerData.metadata and playerData.metadata[key]) or 0
    end

    local cap = def.type == 'medical' and 200 or 100
    exports['ox-core']:SetMetadata(source, key, math.min(cap, current + 30))
    TriggerClientEvent('ox_inventory:client:playUseAnim', source, def.type)

    return true, OxInv.Snapshot(citizenid)
end)

OxInvCallbacks.Register('ox_inventory:dropItem', function(source, data)
    local citizenid = OxInv.GetCitizenId(source)
    if not citizenid then return false, 'character not loaded' end

    local inv = OxInv.Get(citizenid)
    if not inv then return false, 'inventory not loaded' end

    local entry = inv.items[data.slot]
    if not entry then return false, 'empty slot' end

    local count = math.min(tonumber(data.count) or entry.count, entry.count)
    if not count or count <= 0 then return false, 'invalid count' end

    local netId = tonumber(data.netId)
    if not netId then return false, 'invalid drop' end

    local itemName, metadata = entry.name, entry.metadata

    local removed = OxInv.RemoveItem(citizenid, itemName, count)
    if not removed then return false, 'failed to drop item' end

    local coords = GetEntityCoords(GetPlayerPed(source))
    local groundId = 'ground:' .. netId

    OxInv.CreateEphemeral(groundId, 'Dropped Items', 100000, 5, { x = coords.x, y = coords.y, z = coords.z })

    local added = OxInv.AddItem(groundId, itemName, count, metadata)
    if not added then
        OxInv.Destroy(groundId)
        OxInv.AddItem(citizenid, itemName, count, metadata) -- roll back
        return false, 'failed to drop item'
    end

    return true, OxInv.Snapshot(citizenid)
end)

OxInvCallbacks.Register('ox_inventory:giveItem', function(source, data)
    local citizenid = OxInv.GetCitizenId(source)
    if not citizenid then return false, 'character not loaded' end

    local targetSrc = tonumber(data.target)
    if not targetSrc or targetSrc == source then return false, 'invalid target' end

    local targetCitizenId = OxInv.GetCitizenId(targetSrc)
    if not targetCitizenId then return false, 'target not loaded' end

    local sourcePed, targetPed = GetPlayerPed(source), GetPlayerPed(targetSrc)
    if sourcePed == 0 or targetPed == 0 then return false, 'invalid target' end

    if DistanceTo(source, GetEntityCoords(targetPed)) > Config.GiveRange then
        return false, 'target is too far away'
    end

    local inv = OxInv.Get(citizenid)
    local entry = inv and inv.items[data.slot]
    if not entry then return false, 'empty slot' end

    local count = math.min(tonumber(data.count) or entry.count, entry.count)
    if not count or count <= 0 then return false, 'invalid count' end

    OxInv.Load(targetCitizenId, 'player', targetCitizenId, Config.MaxWeight, Config.MaxSlots)

    if not OxInv.CanCarry(OxInv.Get(targetCitizenId), entry.name, count) then
        return false, "target can't carry that much"
    end

    local itemName, metadata = entry.name, entry.metadata

    local removed = OxInv.RemoveItem(citizenid, itemName, count)
    if not removed then return false, 'failed to give item' end

    local added = OxInv.AddItem(targetCitizenId, itemName, count, metadata)
    if not added then
        OxInv.AddItem(citizenid, itemName, count, metadata) -- roll back
        return false, 'failed to give item'
    end

    local def = Items[itemName]
    TriggerClientEvent('ox_inventory:client:notify', targetSrc, ('You received %dx %s'):format(count, def and def.label or itemName))

    return true, OxInv.Snapshot(citizenid)
end)

OxInvCallbacks.Register('ox_inventory:splitStack', function(source, data)
    local citizenid = OxInv.GetCitizenId(source)
    if not citizenid then return false, 'character not loaded' end

    local inv = OxInv.Get(citizenid)
    if not inv then return false, 'inventory not loaded' end

    local entry = inv.items[data.slot]
    if not entry then return false, 'empty slot' end

    local count = tonumber(data.count) or 0
    if count <= 0 or count >= entry.count then return false, 'invalid split amount' end

    local emptySlot = OxInv.FindEmptySlot(inv)
    if not emptySlot then return false, 'no empty slot to split into' end

    local ok, err = OxInv.MoveItem(citizenid, data.slot, citizenid, emptySlot, count)
    if not ok then return false, err end

    return true, OxInv.Snapshot(citizenid)
end)

OxInvCallbacks.Register('ox_inventory:equipItem', function(source, data)
    local citizenid = OxInv.GetCitizenId(source)
    if not citizenid then return false, 'character not loaded' end

    local ok, err = OxInv.EquipItem(citizenid, data.slot)
    if not ok then return false, err end

    return true, OxInv.Snapshot(citizenid)
end)

OxInvCallbacks.Register('ox_inventory:unequipItem', function(source, data)
    local citizenid = OxInv.GetCitizenId(source)
    if not citizenid then return false, 'character not loaded' end

    local ok, err = OxInv.UnequipItem(citizenid, data.slot)
    if not ok then return false, err end

    return true, OxInv.Snapshot(citizenid)
end)
