-- ============================================================
-- Selling drugs to random street NPCs. Targets the configured ped models
-- wherever they happen to be in the world (qb-target's AddTargetModel),
-- rather than spawning anything dedicated.
-- ============================================================

if not Config.Toggle.StreetSales then return end

local Street = Config.StreetSales

local function promptSale(entity)
    local drugList = {}
    for key, drug in pairs(Config.Drugs) do
        drugList[#drugList + 1] = ('%s (%s)'):format(drug.label, key)
    end

    local input = exports['qb-input']:ShowInput({
        header = 'Offer a Deal',
        submitText = 'Offer',
        inputs = {
            { type = 'text', name = 'drug', text = ('Drug key: %s'):format(table.concat(drugList, ', ')), isRequired = true },
            { type = 'number', name = 'amount', text = 'Amount', isRequired = true },
        },
    })
    if not input or not input.drug or not input.amount then return end

    local drugKey = string.lower(tostring(input.drug))
    if not Config.Drugs[drugKey] then
        QBCore.Functions.Notify('Unknown drug.', 'error')
        return
    end

    local coords = GetEntityCoords(entity)
    TriggerServerEvent('ovi:server:streetSale', drugKey, tonumber(input.amount), coords)
end

CreateThread(function()
    Wait(500)
    exports['qb-target']:AddTargetModel(Street.npcModels, {
        options = {
            {
                type = 'client',
                icon = 'fas fa-money-bill',
                label = 'Offer a Deal',
                action = function(entity) promptSale(entity) end,
            },
        },
        distance = Street.sellDistance,
    })
end)

RegisterNetEvent('ovi:client:streetSaleRobbed', function(hadWeapon)
    if hadWeapon then
        QBCore.Functions.Notify('They pulled a weapon!', 'error')
    end
end)

RegisterNetEvent('ovi:client:streetSaleResult', function(outcome)
    -- purely cosmetic hook point - server already sends the relevant notify;
    -- kept as an event so other resources can react to street sale outcomes
end)
