local QBCore = nil
if GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
end

local hudVisible = true

local function GetWeaponLabel(weaponHash)
    if QBCore and QBCore.Shared and QBCore.Shared.Weapons and QBCore.Shared.Weapons[weaponHash] then
        return QBCore.Shared.Weapons[weaponHash].label
    end
    return 'Weapon'
end

local function GetWeaponState(ped)
    local weaponHash = GetSelectedPedWeapon(ped)
    if weaponHash == GetHashKey('WEAPON_UNARMED') then
        return nil
    end

    local _, clipAmmo = GetAmmoInClip(ped, weaponHash)
    local totalAmmo = GetAmmoInPedWeapon(ped, weaponHash)

    return {
        label = GetWeaponLabel(weaponHash),
        clip = clipAmmo or 0,
        total = totalAmmo or 0
    }
end

local function IsPlayerTalking()
    local ok, talking = pcall(NetworkIsPlayerTalking, PlayerId())
    return ok and talking or false
end

local function BuildState()
    local ped = PlayerPedId()

    local health = math.max(math.min(GetEntityHealth(ped) - 100, 100), 0)
    local armor = GetPedArmour(ped)
    local stamina = math.floor(GetPlayerSprintStaminaRemaining(PlayerId()) or 100)

    return {
        health = health,
        armor = armor,
        stamina = stamina,
        talking = IsPlayerTalking(),
        weapon = GetWeaponState(ped)
    }
end

CreateThread(function()
    while true do
        Wait(200)
        if hudVisible then
            local state = BuildState()
            SendNUIMessage({ action = 'update', data = state })
        end
    end
end)

RegisterCommand('togglehud', function()
    hudVisible = not hudVisible
    SendNUIMessage({ action = 'visibility', data = { show = hudVisible } })
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        SendNUIMessage({ action = 'visibility', data = { show = false } })
    end
end)
