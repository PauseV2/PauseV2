-- ============================================================
-- Referral system: a satisfied client can introduce a brand new contact.
-- ============================================================

if not Config.Toggle.Referrals then return end

local Referrals = Config.Referrals

local function rollReferralPersonality()
    local pool = {}
    for key, weight in pairs(Referrals.qualityWeights) do
        pool[#pool + 1] = { key = key, weight = weight }
    end
    local picked = OVI.WeightedRandom(pool)
    return picked and picked.key or nil
end

RegisterNetEvent('ovi:server:checkReferral', function(imei, contactId, deliveriesDone)
    if deliveriesDone < Referrals.requiredDeliveries then return end

    local globalClient = OVI.DB.GetGlobalClient(contactId)
    if not globalClient or globalClient.referral_count >= Referrals.maxReferrals then return end

    if not OVI.Chance(Referrals.chance) then return end

    local personalityKey = rollReferralPersonality()
    local newContactId = OVI.CreateNewContact(imei, personalityKey, false)
    if not newContactId then return end

    OVI.DB.AddReferral(contactId, newContactId, imei)
    OVI.DB.IncrementReferralCount(contactId)

    local message = 'My cousin needs work.'
    OVI.DB.AddMessage(imei, contactId, 'client', message, false)

    OVI.NotifyPhoneHolder(imei, {
        type = 'newMessage',
        contactId = contactId,
        message = message,
        notification = 'OVI: new referral',
    })
end)
