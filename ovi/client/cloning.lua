-- ============================================================
-- Cloning NPC: backup/recover use whichever phone the player last used
-- (OVI.State.lastPhoneSlot); migrate asks for both inventory slots since
-- it needs two different phones at once.
-- ============================================================

if not Config.Toggle.Cloning then return end

local Cloning = Config.Cloning

local function openCloneMenu()
    local menu = {
        { header = 'Phone Cloning', isMenuHeader = true },
        {
            header = ('Backup ($%d)'):format(Cloning.backupPrice),
            txt = 'Backs up the phone you last used.',
            params = {
                event = 'ovi:client:cloneBackup',
            },
        },
        {
            header = ('Recover ($%d)'):format(Cloning.recoveryPrice),
            txt = 'Restores the latest backup onto that same phone.',
            params = {
                event = 'ovi:client:cloneRecover',
            },
        },
        {
            header = ('Migrate ($%d)'):format(Cloning.migratePrice),
            txt = 'Move an OVI identity onto a different physical phone.',
            params = {
                event = 'ovi:client:cloneMigrate',
            },
        },
    }
    exports['qb-menu']:openMenu(menu)
end

RegisterNetEvent('ovi:client:cloneBackup', function()
    if not OVI.State.lastPhoneSlot then
        QBCore.Functions.Notify('Use the phone you want to back up first.', 'error')
        return
    end
    TriggerServerEvent('ovi:server:cloneBackup', OVI.State.lastPhoneSlot)
end)

RegisterNetEvent('ovi:client:cloneRecover', function()
    if not OVI.State.lastPhoneSlot then
        QBCore.Functions.Notify('Use the phone you want to recover onto first.', 'error')
        return
    end
    TriggerServerEvent('ovi:server:cloneRecover', OVI.State.lastPhoneSlot)
end)

RegisterNetEvent('ovi:client:cloneMigrate', function()
    local input = exports['qb-input']:ShowInput({
        header = 'Migrate Identity',
        submitText = 'Migrate',
        inputs = {
            { type = 'number', name = 'sourceSlot', text = 'Source phone inventory slot', isRequired = true },
            { type = 'number', name = 'targetSlot', text = 'Target phone inventory slot', isRequired = true },
        },
    })
    if not input or not input.sourceSlot or not input.targetSlot then return end

    TriggerServerEvent('ovi:server:cloneMigrate', tonumber(input.sourceSlot), tonumber(input.targetSlot))
end)

CreateThread(function()
    local npc = Cloning.npc
    local model = joaat(npc.model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    local ped = CreatePed(4, model, npc.coords.x, npc.coords.y, npc.coords.z - 1.0, npc.coords.w, false, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if npc.scenario then
        TaskStartScenarioInPlace(ped, npc.scenario, 0, true)
    end

    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            {
                type = 'client',
                icon = npc.target.icon,
                label = npc.target.label,
                action = openCloneMenu,
            },
        },
        distance = npc.target.distance,
    })
end)
