-- Generic weight-based inventory engine. An "inventory" is just an id + a
-- sparse table of slots; player inventories, stashes, (and later, shops'
-- backrooms etc.) are all the same data structure underneath.

OxInv = {
    cache = {}, -- [id] = { id, type, label, maxWeight, slots, items = { [slot] = {slot,name,count,metadata} }, clothing = { [slotName] = {name,metadata} } }
}

local function FindItemDef(name)
    return Items[name]
end

function OxInv.GetWeight(inv)
    local total = 0

    for _, entry in pairs(inv.items) do
        local def = FindItemDef(entry.name)
        if def then
            total = total + (def.weight * entry.count)
        end
    end

    return total
end

function OxInv.CanCarry(inv, itemName, count)
    local def = FindItemDef(itemName)
    if not def then return false end

    return (OxInv.GetWeight(inv) + def.weight * count) <= inv.maxWeight
end

function OxInv.Load(id, invType, label, maxWeight, slots)
    if OxInv.cache[id] then return OxInv.cache[id] end

    local row = OxInvDB.Load(id)
    local items, clothing = {}, {}

    if row and row.data then
        local decoded = json.decode(row.data)

        if decoded then
            -- decoded.items is the current shape; a bare array is the
            -- pre-clothing format saved before this field existed.
            local rawItems = decoded.items or decoded

            for _, entry in ipairs(rawItems) do
                items[entry.slot] = entry
            end

            clothing = decoded.clothing or {}
        end
    end

    local inv = {
        id = id,
        type = invType,
        label = label or id,
        maxWeight = maxWeight or Config.MaxWeight,
        slots = slots or Config.MaxSlots,
        items = items,
        clothing = clothing,
    }

    OxInv.cache[id] = inv
    return inv
end

function OxInv.Get(id)
    return OxInv.cache[id]
end

function OxInv.Save(inv)
    if inv.ephemeral then return end -- ground bags never touch the DB

    local list = {}

    for _, entry in pairs(inv.items) do
        list[#list + 1] = entry
    end

    OxInvDB.Save(inv.id, inv.type, { items = list, clothing = inv.clothing })
end

-- Ground items: created on drop, never DB-backed, destroyed once emptied.
function OxInv.CreateEphemeral(id, label, maxWeight, slots, coords)
    local inv = {
        id = id,
        type = 'ground',
        label = label,
        maxWeight = maxWeight,
        slots = slots,
        items = {},
        clothing = {},
        coords = coords,
        ephemeral = true,
    }

    OxInv.cache[id] = inv
    return inv
end

function OxInv.Destroy(id)
    OxInv.cache[id] = nil
end

function OxInv.IsEmpty(inv)
    for _ in pairs(inv.items) do
        return false
    end

    return true
end

function OxInv.FindEmptySlot(inv)
    for slot = 1, inv.slots do
        if not inv.items[slot] then
            return slot
        end
    end

    return nil
end

-- Moves a clothing-type item out of its normal weighted slot into the fixed
-- clothing slot named on the item def. Equipped items don't count toward
-- weight - they're worn, not carried.
function OxInv.EquipItem(id, slot)
    local inv = OxInv.cache[id]
    if not inv then return false, 'inventory not loaded' end

    local entry = inv.items[slot]
    if not entry then return false, 'empty slot' end

    local def = FindItemDef(entry.name)
    if not def or def.type ~= 'clothing' or not def.slot then
        return false, 'item is not wearable'
    end

    if inv.clothing[def.slot] then
        return false, 'unequip that slot first'
    end

    inv.clothing[def.slot] = { name = entry.name, metadata = entry.metadata }

    entry.count = entry.count - 1
    if entry.count <= 0 then
        inv.items[slot] = nil
    end

    return true
end

-- Reverses EquipItem: the worn item re-enters the normal weighted inventory,
-- so it can fail if there's no space or weight capacity left.
function OxInv.UnequipItem(id, clothingSlot)
    local inv = OxInv.cache[id]
    if not inv then return false, 'inventory not loaded' end

    local worn = inv.clothing[clothingSlot]
    if not worn then return false, 'slot is empty' end

    local added = OxInv.AddItem(id, worn.name, 1, worn.metadata)
    if not added then return false, 'no space in inventory' end

    inv.clothing[clothingSlot] = nil
    return true
end

function OxInv.Close(id)
    local inv = OxInv.cache[id]
    if inv then
        OxInv.Save(inv)
    end

    OxInv.cache[id] = nil
end

-- Returns an existing stack with room, or the first empty slot, for itemName.
local function FindSlotFor(inv, itemName, count)
    local def = FindItemDef(itemName)
    if not def then return nil end

    if def.stack > 1 then
        for slot = 1, inv.slots do
            local entry = inv.items[slot]
            if entry and entry.name == itemName and entry.count < def.stack then
                return slot, math.min(count, def.stack - entry.count)
            end
        end
    end

    for slot = 1, inv.slots do
        if not inv.items[slot] then
            return slot, math.min(count, def.stack)
        end
    end

    return nil
end

function OxInv.AddItem(id, itemName, count, metadata)
    local def = FindItemDef(itemName)
    if not def then return false, 'invalid item' end
    if type(count) ~= 'number' or count <= 0 then return false, 'invalid count' end

    local inv = OxInv.cache[id]
    if not inv then return false, 'inventory not loaded' end

    if not OxInv.CanCarry(inv, itemName, count) then
        return false, 'not enough weight capacity'
    end

    local remaining = count

    while remaining > 0 do
        local slot, amount = FindSlotFor(inv, itemName, remaining)
        if not slot then return false, 'not enough space' end

        local entry = inv.items[slot]
        if entry then
            entry.count = entry.count + amount
        else
            inv.items[slot] = { slot = slot, name = itemName, count = amount, metadata = metadata or {} }
        end

        remaining = remaining - amount
    end

    return true
end

function OxInv.GetItemCount(id, itemName)
    local inv = OxInv.cache[id]
    if not inv then return 0 end

    local total = 0
    for _, entry in pairs(inv.items) do
        if entry.name == itemName then
            total = total + entry.count
        end
    end

    return total
end

function OxInv.RemoveItem(id, itemName, count)
    if type(count) ~= 'number' or count <= 0 then return false, 'invalid count' end

    local inv = OxInv.cache[id]
    if not inv then return false, 'inventory not loaded' end

    if OxInv.GetItemCount(id, itemName) < count then
        return false, 'not enough items'
    end

    local remaining = count

    for slot = 1, inv.slots do
        if remaining <= 0 then break end

        local entry = inv.items[slot]
        if entry and entry.name == itemName then
            local take = math.min(entry.count, remaining)
            entry.count = entry.count - take
            remaining = remaining - take

            if entry.count <= 0 then
                inv.items[slot] = nil
            end
        end
    end

    return true
end

function OxInv.Snapshot(id)
    local inv = OxInv.cache[id]
    if not inv then return nil end

    local items = {}

    for slot, entry in pairs(inv.items) do
        local def = FindItemDef(entry.name)

        items[#items + 1] = {
            slot = slot,
            name = entry.name,
            count = entry.count,
            metadata = entry.metadata,
            label = def and def.label or entry.name,
            weight = def and def.weight or 0,
            icon = def and def.icon or '❓',
            description = def and def.description or '',
            type = def and def.type or 'item',
            wearSlot = def and def.slot or nil,
        }
    end

    local clothing = {}

    for slotName, worn in pairs(inv.clothing or {}) do
        local def = FindItemDef(worn.name)

        clothing[slotName] = {
            name = worn.name,
            metadata = worn.metadata,
            label = def and def.label or worn.name,
            icon = def and def.icon or '❓',
            description = def and def.description or '',
        }
    end

    return {
        id = inv.id,
        label = inv.label,
        slots = inv.slots,
        maxWeight = inv.maxWeight,
        weight = OxInv.GetWeight(inv),
        items = items,
        clothing = clothing,
    }
end

function OxInv.MoveItem(fromId, fromSlot, toId, toSlot, count)
    local fromInv = OxInv.cache[fromId]
    local toInv = OxInv.cache[toId]
    if not fromInv or not toInv then return false, 'inventory not loaded' end

    local entry = fromInv.items[fromSlot]
    if not entry then return false, 'empty slot' end

    count = math.min(count or entry.count, entry.count)

    if fromId == toId then
        local target = toInv.items[toSlot]

        if target and target.name == entry.name then
            target.count = target.count + count
        elseif not target then
            toInv.items[toSlot] = { slot = toSlot, name = entry.name, count = count, metadata = entry.metadata }
        else
            return false, 'slot occupied'
        end

        entry.count = entry.count - count
        if entry.count <= 0 then
            fromInv.items[fromSlot] = nil
        end

        return true
    end

    if not OxInv.CanCarry(toInv, entry.name, count) then
        return false, 'destination inventory is full'
    end

    local removed = OxInv.RemoveItem(fromId, entry.name, count)
    if not removed then return false, 'failed to remove item' end

    local added = OxInv.AddItem(toId, entry.name, count, entry.metadata)
    if not added then
        OxInv.AddItem(fromId, entry.name, count, entry.metadata) -- roll back
        return false, 'failed to add item'
    end

    return true
end
