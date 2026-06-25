-- ============================================================
-- NPC contact generation, caching and delivery-request messaging.
-- ============================================================

--- Best-effort delivery of an OVI event to whoever is currently holding
--- the given phone (tracked in OVI.Cache.imeiOwner, refreshed every time
--- the item is used). Always safe to call even if nobody is holding it.
function OVI.NotifyPhoneHolder(imei, payload)
    local src = OVI.Cache.imeiOwner[imei]
    if not src then return end

    local phoneRow = OVI.DB.GetPhone(imei)
    if not phoneRow or phoneRow.online == 0 then return end

    if OVI.GetOpenImei(src) == imei then
        TriggerClientEvent('ovi:client:pushUpdate', src, payload)
    end

    local ok = pcall(function()
        exports['qb-phone']:newNotification(src, payload.notification or 'OVI: new activity')
    end)
    if not ok then
        TriggerClientEvent('QBCore:Notify', src, payload.notification or 'OVI: new activity', 'primary')
    end
end

--- Picks a personality key weighted evenly unless you want to bias it -
--- extend this if you want certain personalities rarer than others.
local function rollPersonality()
    local keys = {}
    for key in pairs(Config.Personalities) do keys[#keys + 1] = key end
    return OVI.RandomFrom(keys)
end

--- Picks a drug key weighted by demand (config/drugs.lua).
function OVI.RollDrug()
    local pool = {}
    for key, drug in pairs(Config.Drugs) do
        pool[#pool + 1] = { key = key, weight = drug.demand }
    end
    local picked = OVI.WeightedRandom(pool)
    return picked and picked.key or nil
end

--- Creates a brand new global NPC client and attaches it to one phone.
--- `personalityKey` and `shared` are optional overrides.
function OVI.CreateNewContact(imei, personalityKey, shared)
    personalityKey = personalityKey or rollPersonality()
    local personality = Config.Personalities[personalityKey]
    if not personality then return nil end

    local contactId = OVI.GenerateContactId()
    local preferredDrug = OVI.RollDrug()

    OVI.DB.CreateGlobalClient({
        contactId = contactId,
        fullName = OVI.GenerateFullName(),
        number = OVI.GeneratePhoneNumber(),
        personality = personalityKey,
        preferredDrug = preferredDrug,
        quantityMin = personality.quantityRange[1],
        quantityMax = personality.quantityRange[2],
        riskLevel = personality.riskLevel,
        shared = shared or false,
    })

    local trust = OVI.RandomRange(Config.ClientGeneration.minTrustStart, Config.ClientGeneration.maxTrustStart)
    local loyalty = OVI.RandomRange(Config.ClientGeneration.minLoyaltyStart, Config.ClientGeneration.maxLoyaltyStart)
    OVI.DB.AddPhoneContact(imei, contactId, trust, loyalty)

    return contactId
end

--- Attaches an *existing* global contact (used by shared clients / referrals)
--- to another phone without creating a new NPC identity.
function OVI.AttachExistingContact(imei, contactId)
    if OVI.DB.GetPhoneContact(imei, contactId) then return end
    local trust = OVI.RandomRange(Config.ClientGeneration.minTrustStart, Config.ClientGeneration.maxTrustStart)
    local loyalty = OVI.RandomRange(Config.ClientGeneration.minLoyaltyStart, Config.ClientGeneration.maxLoyaltyStart)
    OVI.DB.AddPhoneContact(imei, contactId, trust, loyalty)
end

-- ------------------------------------------------------- request messages --

local function buildRequestLine(drugKey, quantity, price)
    local label = Config.Drugs[drugKey] and Config.Drugs[drugKey].label or drugKey

    if Config.Toggle.CodeLanguage and OVI.Chance(Config.CodeLanguageChance) and Config.Codes[drugKey] then
        label = OVI.RandomFrom(Config.Codes[drugKey])
    end

    return ('Need %d %s. Got %d ready.'):format(quantity, label, price)
end

--- Rolls the drug/quantity/price/message for one request from a global
--- client, without touching the DB. Shared by the per-phone flow below
--- and the shared-client broadcast flow in server/shared.lua.
function OVI.BuildRequestTerms(globalClient)
    local personality = Config.Personalities[globalClient.personality]
    if not personality then return nil end

    local drugKey = globalClient.preferred_drug
    local drugCfg = Config.Drugs[drugKey]
    if not drugCfg then return nil end

    local quantity = OVI.RandomRange(globalClient.quantity_min, globalClient.quantity_max)
    local basePrice = drugCfg.basePrice * drugCfg.marketMultiplier * quantity
    local tolerance = 1 + (personality.priceTolerance / 100)
    local price = math.floor(basePrice * tolerance)
    local message = buildRequestLine(drugKey, quantity, price)

    return drugKey, quantity, price, message
end

--- Generates and stores a new delivery request from a contact to a phone,
--- pushing the message + notification to whoever currently holds it.
--- Shared clients (config/shared_clients.lua) are routed through
--- OVI.BroadcastSharedRequest instead, since they don't belong to one phone.
function OVI.GenerateDeliveryRequest(imei, contactId)
    local contactRow = OVI.DB.GetPhoneContact(imei, contactId)
    local globalClient = OVI.DB.GetGlobalClient(contactId)
    if not contactRow or not globalClient then return end
    if contactRow.blacklisted == 1 or globalClient.status ~= 'active' then return end

    if Config.Toggle.SharedClients and globalClient.shared == 1 then
        return OVI.BroadcastSharedRequest(contactId, globalClient)
    end

    local drugKey, quantity, price, message = OVI.BuildRequestTerms(globalClient)
    if not drugKey then return end

    OVI.DB.AddMessage(imei, contactId, 'client', message, false)
    local deliveryId = OVI.DB.CreateDelivery(imei, contactId, drugKey, quantity, price, nil, false)

    OVI.NotifyPhoneHolder(imei, {
        type = 'newMessage',
        contactId = contactId,
        message = message,
        deliveryId = deliveryId,
        drug = drugKey,
        quantity = quantity,
        price = price,
        notification = ('OVI: new message from %s'):format(globalClient.full_name),
    })

    return deliveryId
end

-- ---------------------------------------------------------------- ticking --
-- Event driven, not a tight loop: one long-interval sweep over phones that
-- are actually known to be held by an online player right now.
CreateThread(function()
    while true do
        Wait(Config.ClientGeneration.requestIntervalMinutes * 60 * 1000)

        for imei, src in pairs(OVI.Cache.imeiOwner) do
            if GetPlayerName(src) then
                local contacts = OVI.DB.GetContactsForPhone(imei)
                for _, contact in ipairs(contacts) do
                    if contact.blacklisted == 0 and contact.status == 'active' and OVI.Chance(Config.ClientGeneration.requestChance) then
                        OVI.GenerateDeliveryRequest(imei, contact.contact_id)
                    end
                end
            end
        end
    end
end)
