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

-- 'player' always resolves to the caller's own citizenid - the client can
-- never request another player's inventory by id. Stashes are server-side
-- distance-checked before the inventory is even loaded.
local function ResolveInvId(source, label)
    if label == 'player' then
        return OxInv.GetCitizenId(source)
    end

    local stash = Config.Stashes[label]
    if not stash then return nil end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local dx, dy, dz = coords.x - stash.coords.x, coords.y - stash.coords.y, coords.z - stash.coords.z
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

    if distance > Config.StashRange then
        return nil
    end

    OxInv.Load(label, 'stash', stash.label, stash.maxWeight, stash.slots)
    return label
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

    if def.type ~= 'food' and def.type ~= 'drink' then
        return false, 'item is not usable'
    end

    local removed = OxInv.RemoveItem(citizenid, entry.name, 1)
    if not removed then return false, 'failed to use item' end

    local playerData = exports['ox-core']:GetPlayer(source)
    local key = def.type == 'food' and 'hunger' or 'thirst'
    local current = (playerData and playerData.metadata and playerData.metadata[key]) or 0

    exports['ox-core']:SetMetadata(source, key, math.min(100, current + 30))
    TriggerClientEvent('ox_inventory:client:playUseAnim', source, def.type)

    return true, OxInv.Snapshot(citizenid)
end)
