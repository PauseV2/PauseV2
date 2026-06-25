-- ============================================================
-- Unlockable drug suppliers. Unlock requirement checks the reputation of
-- whichever phone the player currently has open in OVI.
-- ============================================================

if not Config.Toggle.Suppliers then return end

local function ensureRow(drugKey, citizenid)
    local row = OVI.DB.GetSupplier(drugKey, citizenid)
    if not row then
        OVI.DB.UpsertSupplier(drugKey, citizenid, { stock = 0, unlocked = 0, last_restock = os.time(), cooldown_until = 0 })
        row = OVI.DB.GetSupplier(drugKey, citizenid)
    end
    return row
end

RegisterNetEvent('ovi:server:checkSupplierUnlock', function(drugKey)
    local src = source
    local Player = OVI.GetPlayer(src)
    local supplierCfg = Config.Suppliers[drugKey]
    if not Player or not supplierCfg then return end

    local imei = OVI.GetOpenImei(src)
    if not imei then
        TriggerClientEvent('QBCore:Notify', src, 'Check OVI first - this supplier wants to see your standing.', 'error')
        return
    end

    local phoneRow = OVI.DB.GetPhone(imei)
    local row = ensureRow(drugKey, Player.PlayerData.citizenid)

    if row.unlocked == 0 then
        if supplierCfg.unlock.type == 'reputation' and phoneRow.reputation >= supplierCfg.unlock.amount then
            OVI.DB.UpsertSupplier(drugKey, Player.PlayerData.citizenid, { unlocked = 1, stock = supplierCfg.maxStock })
            TriggerClientEvent('QBCore:Notify', src, ('%s unlocked.'):format(supplierCfg.label), 'success')
        else
            TriggerClientEvent('QBCore:Notify', src, 'Not enough reputation yet.', 'error')
            return
        end
    end

    TriggerClientEvent('ovi:client:openSupplierMenu', src, drugKey, supplierCfg, OVI.DB.GetSupplier(drugKey, Player.PlayerData.citizenid))
end)

RegisterNetEvent('ovi:server:buyFromSupplier', function(drugKey, amount)
    local src = source
    local Player = OVI.GetPlayer(src)
    local supplierCfg = Config.Suppliers[drugKey]
    if not Player or not supplierCfg or not amount or amount <= 0 then return end

    local row = ensureRow(drugKey, Player.PlayerData.citizenid)
    if row.unlocked == 0 then return end

    if row.cooldown_until > os.time() then
        TriggerClientEvent('QBCore:Notify', src, 'Supplier is laying low. Try later.', 'error')
        return
    end

    if row.stock < amount then
        TriggerClientEvent('QBCore:Notify', src, 'Supplier does not have that much stock.', 'error')
        return
    end

    local cost = amount * supplierCfg.pricePerUnit
    if not Player.Functions.RemoveMoney('cash', cost) then
        TriggerClientEvent('QBCore:Notify', src, 'Not enough cash.', 'error')
        return
    end

    Player.Functions.AddItem(supplierCfg.item, amount)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[supplierCfg.item], 'add')

    OVI.DB.UpsertSupplier(drugKey, Player.PlayerData.citizenid, {
        stock = row.stock - amount,
        cooldown_until = os.time() + (supplierCfg.cooldownMinutes * 60),
    })
end)

CreateThread(function()
    while true do
        Wait(60 * 60 * 1000)
        for drugKey, supplierCfg in pairs(Config.Suppliers) do
            MySQL.update.await(
                'UPDATE ovi_suppliers SET stock = LEAST(?, stock + ?) WHERE drug = ?',
                { supplierCfg.maxStock, supplierCfg.restockPerHour, drugKey }
            )
        end
    end
end)
