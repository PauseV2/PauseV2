OxInvCallbacks.Register('ox_inventory:buyItem', function(source, data)
    local shop = Shops[data.shop]
    if not shop then return false, 'invalid shop' end

    local listing
    for _, entry in ipairs(shop.items) do
        if entry.name == data.item then
            listing = entry
            break
        end
    end
    if not listing then return false, 'shop does not sell this item' end

    local count = tonumber(data.count) or 1
    if count <= 0 or count > 50 then return false, 'invalid count' end

    local citizenid = OxInv.GetCitizenId(source)
    if not citizenid then return false, 'character not loaded' end

    -- weight-check before charging money so the common failure path needs no refund
    if not OxInv.CanCarry(OxInv.Get(citizenid), listing.name, count) then
        return false, 'not enough space to carry that'
    end

    local account = data.account == 'bank' and 'bank' or 'cash'
    local total = listing.price * count

    local paid, payErr = exports['ox-core']:RemoveMoney(source, account, total, 'shop:' .. data.shop)
    if not paid then return false, payErr or 'insufficient funds' end

    local added = OxInv.AddItem(citizenid, listing.name, count)
    if not added then
        exports['ox-core']:AddMoney(source, account, total, 'shop refund: ' .. data.shop)
        return false, 'failed to add item'
    end

    return true, OxInv.Snapshot(citizenid)
end)

OxInvCallbacks.Register('ox_inventory:getShop', function(_, shopName)
    local shop = Shops[shopName]
    if not shop then return false, 'invalid shop' end
    return true, { label = shop.label, items = shop.items }
end)
