-- ============================================================
-- Unsolicited "got your number from someone" texts. Most are legit new
-- clients, but some are robbery setups, police stings or rival gang traps
-- disguised as a normal request - the player only finds out at the meet.
-- ============================================================

if not Config.Toggle.RandomContacts then return end

local RC = Config.RandomContacts
OVI.Cache.specialEncounters = OVI.Cache.specialEncounters or {} -- [contactId] = 'robbery' | 'rivalTrap' | 'police'

local function rollOutcome()
    local pool = {
        { key = 'legitClient',   weight = RC.outcomes.legitClient },
        { key = 'robberySetup',  weight = RC.outcomes.robberySetup },
        { key = 'policeSting',   weight = RC.outcomes.policeSting },
        { key = 'rivalGangTrap', weight = RC.outcomes.rivalGangTrap },
    }
    local picked = OVI.WeightedRandom(pool)
    return picked and picked.key or 'legitClient'
end

local function sendUnknownText(imei, contactId)
    OVI.DB.AddMessage(imei, contactId, 'client', RC.openingLine, false)
    OVI.NotifyPhoneHolder(imei, {
        type = 'newMessage',
        contactId = contactId,
        message = RC.openingLine,
        notification = 'OVI: unknown number',
    })
end

local function triggerRandomContact(imei)
    local outcome = rollOutcome()
    local contactId = OVI.CreateNewContact(imei, nil, false)
    if not contactId then return end

    if outcome == 'robberySetup' then
        OVI.Cache.specialEncounters[contactId] = 'robbery'
    elseif outcome == 'policeSting' then
        OVI.Cache.specialEncounters[contactId] = 'police'
    elseif outcome == 'rivalGangTrap' then
        OVI.Cache.specialEncounters[contactId] = 'rivalTrap'
    end

    sendUnknownText(imei, contactId)
    OVI.GenerateDeliveryRequest(imei, contactId)
end

--- Consumed once by deliveries.lua when the player initiates a meet for
--- a delivery tied to a flagged contact.
function OVI.ConsumeSpecialEncounter(contactId)
    local kind = OVI.Cache.specialEncounters[contactId]
    OVI.Cache.specialEncounters[contactId] = nil
    return kind
end

CreateThread(function()
    while true do
        Wait(RC.intervalMinutes * 60 * 1000)
        for imei, src in pairs(OVI.Cache.imeiOwner) do
            if GetPlayerName(src) and OVI.Chance(RC.chance) then
                triggerRandomContact(imei)
            end
        end
    end
end)
