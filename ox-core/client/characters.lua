OxCharacters = {}

local function RefreshList()
    local ok, list = OxTriggerCallback('ox:getCharacters')
    SendNUIMessage({ action = 'characters', list = ok and list or {}, maxSlots = Config.MaxCharacterSlots })
end

function OxCharacters.OpenSelect()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    RefreshList()
end

function OxCharacters.Close()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('selectCharacter', function(data, cb)
    local ok, result = OxTriggerCallback('ox:selectCharacter', data.citizenid)

    if ok then
        OxCharacters.Close()
    end

    cb({ ok = ok, error = not ok and result or nil })
end)

RegisterNUICallback('createCharacter', function(data, cb)
    local createOk, citizenidOrReason = OxTriggerCallback('ox:createCharacter', data)

    if not createOk then
        cb({ ok = false, error = citizenidOrReason })
        return
    end

    local selectOk, selectErr = OxTriggerCallback('ox:selectCharacter', citizenidOrReason)

    if selectOk then
        OxCharacters.Close()
    end

    cb({ ok = selectOk, citizenid = citizenidOrReason, error = not selectOk and selectErr or nil })
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    local ok, result = OxTriggerCallback('ox:deleteCharacter', data.citizenid)

    if ok then
        RefreshList()
    end

    cb({ ok = ok, error = not ok and result or nil })
end)

RegisterNUICallback('closeMenu', function(_, cb)
    cb({ ok = true })
end)
