exports('AddItem', function(source, itemName, count, metadata)
    local citizenid = OxInv.GetCitizenId(source)
    if not citizenid then return false, 'character not loaded' end
    return OxInv.AddItem(citizenid, itemName, count, metadata)
end)

exports('RemoveItem', function(source, itemName, count)
    local citizenid = OxInv.GetCitizenId(source)
    if not citizenid then return false, 'character not loaded' end
    return OxInv.RemoveItem(citizenid, itemName, count)
end)

exports('GetItemCount', function(source, itemName)
    local citizenid = OxInv.GetCitizenId(source)
    if not citizenid then return 0 end
    return OxInv.GetItemCount(citizenid, itemName)
end)

exports('HasItem', function(source, itemName, count)
    count = count or 1
    local citizenid = OxInv.GetCitizenId(source)
    if not citizenid then return false end
    return OxInv.GetItemCount(citizenid, itemName) >= count
end)

exports('GetInventory', function(source)
    local citizenid = OxInv.GetCitizenId(source)
    if not citizenid then return nil end
    return OxInv.Snapshot(citizenid)
end)
