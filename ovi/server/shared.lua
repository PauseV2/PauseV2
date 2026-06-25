-- ============================================================
-- Shared contacts: the same NPC client can be owned by several players.
-- A request goes out to every eligible holder at once; whoever accepts
-- first gets the real delivery, everyone else is told it's handled.
-- ============================================================

if not Config.Toggle.SharedClients then return end

local SharedCfg = Config.SharedClients
OVI.Cache.sharedOffers = OVI.Cache.sharedOffers or {}

local function generateOfferId()
    return 'OFR' .. OVI.GenerateRandomDigits(8)
end

function OVI.BroadcastSharedRequest(contactId, globalClient)
    local owners = OVI.DB.GetOwnersOfContact(contactId)
    if #owners == 0 then return end

    local drugKey, quantity, price, message = OVI.BuildRequestTerms(globalClient)
    if not drugKey then return end

    -- only ping holders who currently have the phone in hand and online
    local eligible = {}
    for _, row in ipairs(owners) do
        if OVI.Cache.imeiOwner[row.phone_imei] and GetPlayerName(OVI.Cache.imeiOwner[row.phone_imei]) then
            eligible[#eligible + 1] = row.phone_imei
        end
    end
    if #eligible == 0 then return end

    if #eligible > SharedCfg.maxCompetitors then
        -- trim down to maxCompetitors at random so it doesn't always favor the same group
        while #eligible > SharedCfg.maxCompetitors do
            table.remove(eligible, math.random(1, #eligible))
        end
    end

    local offerId = generateOfferId()
    OVI.Cache.sharedOffers[offerId] = {
        contactId = contactId,
        drugKey = drugKey,
        quantity = quantity,
        price = price,
        claimedBy = nil,
        imeis = eligible,
    }

    for _, imei in ipairs(eligible) do
        OVI.DB.AddMessage(imei, contactId, 'client', message, false)
        OVI.NotifyPhoneHolder(imei, {
            type = 'sharedOffer',
            contactId = contactId,
            message = message,
            offerId = offerId,
            drug = drugKey,
            quantity = quantity,
            price = price,
            notification = ('OVI: new message from %s'):format(globalClient.full_name),
        })
    end
end

RegisterNetEvent('ovi:server:claimSharedOffer', function(offerId)
    local src = source
    local imei = OVI.GetOpenImei(src)
    local offer = OVI.Cache.sharedOffers[offerId]
    if not imei or not offer then return end

    if offer.claimedBy then
        OVI.DB.AddMessage(imei, offer.contactId, 'client', SharedCfg.alreadyHandledMessage, false)
        TriggerClientEvent('ovi:client:pushUpdate', src, {
            type = 'sharedOfferClosed',
            offerId = offerId,
            message = SharedCfg.alreadyHandledMessage,
        })
        return
    end

    local valid = false
    for _, candidate in ipairs(offer.imeis) do
        if candidate == imei then valid = true break end
    end
    if not valid then return end

    offer.claimedBy = imei
    local deliveryId = OVI.DB.CreateDelivery(imei, offer.contactId, offer.drugKey, offer.quantity, offer.price, nil, false)

    for _, otherImei in ipairs(offer.imeis) do
        if otherImei ~= imei then
            OVI.DB.AddMessage(otherImei, offer.contactId, 'client', SharedCfg.alreadyHandledMessage, false)
            OVI.NotifyPhoneHolder(otherImei, {
                type = 'sharedOfferClosed',
                offerId = offerId,
                message = SharedCfg.alreadyHandledMessage,
            })
        end
    end

    TriggerClientEvent('ovi:client:pushUpdate', src, {
        type = 'sharedOfferWon',
        offerId = offerId,
        deliveryId = deliveryId,
    })

    OVI.Cache.sharedOffers[offerId] = nil
end)
