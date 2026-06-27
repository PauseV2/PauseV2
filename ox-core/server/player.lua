-- OxPlayer: the in-memory representation of a loaded character.
-- job/gang are pushed to a replicated state bag (other resources/clients can
-- read `Player(id).state.job` instantly, no event round-trip). money/metadata
-- stay server-only in the state bag and are pushed to the owning client via a
-- single targeted event instead of being broadcast to everyone.

Ox = Ox or {}
Ox.Players = {} -- [source] = OxPlayer
Ox.PlayersByCitizenId = {} -- [citizenid] = source

OxPlayer = {}
OxPlayer.__index = OxPlayer

function OxPlayer.New(source, row)
    local self = setmetatable({}, OxPlayer)

    self.source = source
    self.license = row.license
    self.citizenid = row.citizenid
    self.charinfo = json.decode(row.charinfo) or {}
    self.job = row.job and json.decode(row.job) or { name = 'unemployed', label = Jobs.unemployed.label, grade = 0, gradeLabel = Jobs.unemployed.grades[0].name, onduty = true }
    self.gang = row.gang and json.decode(row.gang) or { name = 'none', label = Gangs.none.label, grade = 0, gradeLabel = Gangs.none.grades[0].name }
    self.money = row.money and json.decode(row.money) or OxShared.DeepCopy(Config.StartingMoney)
    self.metadata = row.metadata and json.decode(row.metadata) or OxShared.DeepCopy(Config.DefaultMetadata)
    self.position = row.position and json.decode(row.position) or OxShared.DeepCopy(Config.DefaultSpawn)

    return self
end

function OxPlayer:SyncStateBags()
    local state = Player(self.source).state
    state:set('citizenid', self.citizenid, true)
    state:set('job', self.job, true)
    state:set('gang', self.gang, true)
    state:set('money', self.money, false)
    state:set('metadata', self.metadata, false)

    TriggerClientEvent('ox:client:syncMoney', self.source, self.money)
    TriggerClientEvent('ox:client:syncMetadata', self.source, self.metadata)
end

function OxPlayer:SetMetadata(key, value)
    self.metadata[key] = value
    Player(self.source).state:set('metadata', self.metadata, false)
    TriggerClientEvent('ox:client:syncMetadata', self.source, self.metadata)
end

function OxPlayer:GetMetadata(key)
    return self.metadata[key]
end

function OxPlayer:SetJob(name, grade)
    local job = Jobs[name]
    if not job then return false, 'invalid job' end

    grade = grade or 0
    local gradeData = job.grades[grade]
    if not gradeData then return false, 'invalid grade' end

    local allowed, reason = OxHooks.RunHooks('beforeJobSet', self, name, grade)
    if not allowed then return false, reason end

    self.job = {
        name = name,
        label = job.label,
        grade = grade,
        gradeLabel = gradeData.name,
        onduty = job.defaultDuty or false,
        isboss = gradeData.isboss or false,
    }

    Player(self.source).state:set('job', self.job, true)
    TriggerEvent('ox:server:jobChanged', self.source, self.job)
    return true
end

function OxPlayer:SetGang(name, grade)
    local gang = Gangs[name]
    if not gang then return false, 'invalid gang' end

    grade = grade or 0
    local gradeData = gang.grades[grade]
    if not gradeData then return false, 'invalid grade' end

    self.gang = {
        name = name,
        label = gang.label,
        grade = grade,
        gradeLabel = gradeData.name,
        isboss = gradeData.isboss or false,
    }

    Player(self.source).state:set('gang', self.gang, true)
    TriggerEvent('ox:server:gangChanged', self.source, self.gang)
    return true
end

function OxPlayer:SetDuty(onduty)
    self.job.onduty = onduty and true or false
    Player(self.source).state:set('job', self.job, true)
    return true
end

function OxPlayer:UpdatePosition()
    local ped = GetPlayerPed(self.source)
    if ped and ped ~= 0 then
        local coords = GetEntityCoords(ped)
        self.position = { x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(ped) }
    end
end

function OxPlayer:Save()
    self:UpdatePosition()
    OxDB.SaveCharacter(self.citizenid, {
        job = self.job,
        gang = self.gang,
        money = self.money,
        metadata = self.metadata,
        position = self.position,
    })
end

function Ox.GetPlayer(source)
    return Ox.Players[source]
end

function Ox.GetPlayerByCitizenId(citizenid)
    local source = Ox.PlayersByCitizenId[citizenid]
    return source and Ox.Players[source] or nil
end

function Ox.GetPlayers()
    return Ox.Players
end

function Ox.AddPlayer(source, player)
    Ox.Players[source] = player
    Ox.PlayersByCitizenId[player.citizenid] = source
end

function Ox.RemovePlayer(source)
    local player = Ox.Players[source]
    if not player then return end

    Ox.PlayersByCitizenId[player.citizenid] = nil
    Ox.Players[source] = nil
end
