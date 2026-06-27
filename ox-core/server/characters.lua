-- Character lifecycle: list/create/select/delete. Every action that targets
-- a citizenid re-checks it belongs to the calling source's license, so one
-- player can never read/load/delete another player's character by guessing
-- or replaying a citizenid.

OxCharacters = {}

local function GetIdentifiers(source)
    return Ox.Identifiers[source]
end

function OxCharacters.ListForSource(source)
    local ids = GetIdentifiers(source)
    if not ids then return {} end

    local rows = OxDB.GetCharactersByLicense(ids.license)
    local list = {}

    for _, row in ipairs(rows) do
        list[#list + 1] = {
            citizenid = row.citizenid,
            slot = row.slot,
            charinfo = json.decode(row.charinfo),
            job = json.decode(row.job),
        }
    end

    return list
end

function OxCharacters.LoadPlayer(source, row)
    local player = OxPlayer.New(source, row)

    Ox.AddPlayer(source, player)
    player:SyncStateBags()

    TriggerClientEvent('ox:client:spawnPlayer', source, player.position, player.citizenid)
    TriggerEvent('ox:server:playerLoaded', source, player.citizenid)

    return player
end

function OxCharacters.Select(source, citizenid)
    local ids = GetIdentifiers(source)
    if not ids then return false, 'no identifiers' end

    local row = OxDB.GetCharacter(citizenid)
    if not row then return false, 'character not found' end

    if row.license ~= ids.license then
        return false, 'character does not belong to this player'
    end

    OxCharacters.LoadPlayer(source, row)
    return true
end

function OxCharacters.Create(source, data)
    local ids = GetIdentifiers(source)
    if not ids then return false, 'no identifiers' end

    if not OxShared.IsValidName(data.firstname) or not OxShared.IsValidName(data.lastname) then
        return false, 'invalid name'
    end

    if not OxShared.IsValidDate(data.birthdate) then
        return false, 'invalid birthdate'
    end

    if not OxShared.IsValidGender(data.gender) then
        return false, 'invalid gender'
    end

    local slotCount = OxDB.CountCharacterSlots(ids.license)
    if slotCount >= Config.MaxCharacterSlots then
        return false, 'no free character slots'
    end

    local allowed, reason = OxHooks.RunHooks('canCreateCharacter', source, ids.license, data)
    if not allowed then
        return false, reason or 'denied'
    end

    local citizenid = OxShared.GenerateCitizenId()
    while OxDB.CitizenIdExists(citizenid) do
        citizenid = OxShared.GenerateCitizenId()
    end

    OxDB.CreateCharacter({
        citizenid = citizenid,
        license = ids.license,
        slot = slotCount + 1,
        charinfo = {
            firstname = data.firstname,
            lastname = data.lastname,
            birthdate = data.birthdate,
            gender = data.gender,
            nationality = data.nationality or 'USA',
        },
        job = { name = 'unemployed', label = Jobs.unemployed.label, grade = 0, gradeLabel = Jobs.unemployed.grades[0].name, onduty = true },
        gang = { name = 'none', label = Gangs.none.label, grade = 0, gradeLabel = Gangs.none.grades[0].name },
        money = OxShared.DeepCopy(Config.StartingMoney),
        metadata = OxShared.DeepCopy(Config.DefaultMetadata),
        position = OxShared.DeepCopy(Config.DefaultSpawn),
    })

    return true, citizenid
end

function OxCharacters.Delete(source, citizenid)
    local ids = GetIdentifiers(source)
    if not ids then return false, 'no identifiers' end

    local row = OxDB.GetCharacter(citizenid)
    if not row then return false, 'character not found' end

    if row.license ~= ids.license then
        return false, 'character does not belong to this player'
    end

    if Ox.GetPlayerByCitizenId(citizenid) then
        return false, 'cannot delete an active character'
    end

    OxDB.DeleteCharacter(citizenid, Config.CharacterDeleteMode == 'hard')
    return true
end

OxCallbacks.Register('ox:getCharacters', function(source)
    return true, OxCharacters.ListForSource(source)
end)

OxCallbacks.Register('ox:selectCharacter', function(source, citizenid)
    return OxCharacters.Select(source, citizenid)
end)

OxCallbacks.Register('ox:createCharacter', function(source, data)
    return OxCharacters.Create(source, data)
end)

OxCallbacks.Register('ox:deleteCharacter', function(source, citizenid)
    return OxCharacters.Delete(source, citizenid)
end)
