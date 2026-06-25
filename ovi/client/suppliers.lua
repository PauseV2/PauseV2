-- ============================================================
-- Unlockable drug suppliers. Unlock check requires the player to have
-- their OVI dashboard open (the supplier wants to see standing on that
-- specific phone) - enforced server side via OVI.GetOpenImei.
-- ============================================================

if not Config.Toggle.Suppliers then return end

RegisterNetEvent('ovi:client:openSupplierMenu', function(drugKey, supplierCfg, row)
    local stock = row and row.stock or 0

    local input = exports['qb-input']:ShowInput({
        header = ('%s (stock: %d)'):format(supplierCfg.label, stock),
        submitText = 'Buy',
        inputs = {
            { type = 'number', name = 'amount', text = ('Amount @ $%d each'):format(supplierCfg.pricePerUnit), isRequired = true },
        },
    })
    if not input or not input.amount then return end

    TriggerServerEvent('ovi:server:buyFromSupplier', drugKey, tonumber(input.amount))
end)

CreateThread(function()
    for drugKey, supplierCfg in pairs(Config.Suppliers) do
        local model = joaat(supplierCfg.npcModel)
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end

        local ped = CreatePed(4, model, supplierCfg.coords.x, supplierCfg.coords.y, supplierCfg.coords.z - 1.0, supplierCfg.coords.w, false, true)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)

        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    type = 'client',
                    icon = 'fas fa-cash-register',
                    label = ('Talk to %s'):format(supplierCfg.label),
                    action = function() TriggerServerEvent('ovi:server:checkSupplierUnlock', drugKey) end,
                },
            },
            distance = 2.0,
        })
    end
end)
