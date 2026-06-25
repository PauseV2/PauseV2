-- ============================================================
-- Free-type negotiation parser. Players type a chat-style reply in the
-- OVI app; this tokenizes it and decides how the NPC reacts.
-- ============================================================

if not Config.Toggle.Negotiation then return end

local Neg = Config.Negotiation

local function classify(text)
    local result = {}
    result.isCounter, result.counterWord   = OVI.ContainsAny(text, Neg.keywords.counterOffer)
    result.isUrgent                        = OVI.ContainsAny(text, Neg.keywords.urgency)
    result.isQualityClaim                  = OVI.ContainsAny(text, Neg.keywords.qualityClaim)
    result.isQuantityChange                = OVI.ContainsAny(text, Neg.keywords.quantityChange)
    result.isRude                          = OVI.ContainsAny(text, Neg.keywords.rude)
    result.number                          = OVI.ExtractNumber(text)
    if Config.Toggle.CodeLanguage then
        result.usesDirectName = OVI.UsesDirectDrugName(text)
    end
    return result
end

local function getTolerancePercent(personality, contactRow, parsed)
    local tolerance = Neg.maxPriceTolerancePercent
    tolerance = tolerance + (contactRow.trust * Neg.trustBonusPercent)
    tolerance = tolerance + (contactRow.loyalty * Neg.loyaltyBonusPercent)
    if parsed.isUrgent then
        tolerance = tolerance * Neg.urgencyMultiplier
    end
    if parsed.isQualityClaim then
        tolerance = tolerance + 5
    end
    if Config.Toggle.Complaints then
        tolerance = tolerance - OVI.GetComplaintPenalty(contactRow.phone_imei, contactRow.contact_id)
    end
    return tolerance
end

--- Returns outcome string + an optional reply line + adjusted price/quantity.
local function resolveNegotiation(globalClient, contactRow, delivery, parsed)
    local personality = Config.Personalities[globalClient.personality]

    if parsed.isRude then
        if OVI.Chance(Neg.insultChance * (personality.insultChanceMult or 1) * 2) then
            return 'insult', 'Watch your mouth. Deal is off.', nil, nil
        end
    end

    if parsed.usesDirectName and globalClient.personality == 'ParanoidClient' then
        if OVI.Chance(Neg.walkAwayChance * (personality.walkAwayMult or 1) * 1.5) then
            return 'cancel', "Don't ever say that shit plainly. We're done.", nil, nil
        end
    end

    local newQuantity = delivery.quantity
    if parsed.isQuantityChange and parsed.number then
        newQuantity = OVI.Clamp(parsed.number, 1, 999)
    end

    if not parsed.number then
        -- no concrete offer, just chatter - client gets impatient
        if OVI.Chance(Neg.walkAwayChance * (personality.walkAwayMult or 1) * 0.5) then
            return 'cancel', "Don't waste my time. I'm out.", nil, nil
        end
        return 'counter', "Numbers, not stories. What's the price?", delivery.price, newQuantity
    end

    local proposedPrice = parsed.isQuantityChange and delivery.price or parsed.number
    local originalPrice = delivery.price

    local tolerancePercent = getTolerancePercent(personality, contactRow, parsed)
    local diffPercent = ((proposedPrice - originalPrice) / originalPrice) * 100

    if diffPercent <= tolerancePercent then
        return 'accept', 'Bet. Send it.', proposedPrice, newQuantity
    end

    if diffPercent <= tolerancePercent * 1.6 then
        local counterPrice = math.floor((originalPrice + proposedPrice) / 2)
        return 'counter', ('I can do %d, not a cent more.'):format(counterPrice), counterPrice, newQuantity
    end

    -- way too high
    if OVI.Chance(Neg.walkAwayChance * (personality.walkAwayMult or 1)) then
        return 'cancel', "That's a joke. I'm gone.", nil, nil
    end

    if OVI.Chance(Neg.insultChance * (personality.insultChanceMult or 1)) then
        return 'insult', "You trying to rob me? Forget it.", nil, nil
    end

    return 'reject', "Too much. Come back with a real price.", nil, nil
end

RegisterNetEvent('ovi:server:negotiate', function(deliveryId, contactId, text)
    local src = source
    local imei = OVI.GetOpenImei(src)
    if not imei then return end

    local delivery = OVI.DB.GetDelivery(deliveryId)
    local contactRow = OVI.DB.GetPhoneContact(imei, contactId)
    local globalClient = OVI.DB.GetGlobalClient(contactId)
    if not delivery or not contactRow or not globalClient then return end
    if delivery.phone_imei ~= imei or delivery.status ~= 'pending' then return end

    OVI.DB.AddMessage(imei, contactId, 'player', text, false)

    local parsed = classify(text)
    local outcome, reply, newPrice, newQuantity = resolveNegotiation(globalClient, contactRow, delivery, parsed)

    if reply then
        OVI.DB.AddMessage(imei, contactId, 'client', reply, false)
    end

    if outcome == 'accept' then
        OVI.DB.UpdateDeliveryTerms(deliveryId, newPrice, newQuantity)
        TriggerEvent('ovi:server:dealAccepted', imei, contactId, deliveryId)
    elseif outcome == 'counter' then
        OVI.DB.UpdateDeliveryTerms(deliveryId, newPrice, newQuantity)
    elseif outcome == 'reject' then
        TriggerEvent('ovi:server:adjustTrust', imei, contactId, 'repeatedDeclines')
    elseif outcome == 'insult' or outcome == 'cancel' then
        OVI.DB.SetDeliveryStatus(deliveryId, 'failed')
        TriggerEvent('ovi:server:adjustTrust', imei, contactId, 'ignoring')
        if outcome == 'insult' and OVI.Chance(15) then
            TriggerEvent('ovi:server:blacklistContact', imei, contactId)
        end
    end

    TriggerClientEvent('ovi:client:pushUpdate', src, {
        type = 'negotiationResult',
        outcome = outcome,
        reply = reply,
        deliveryId = deliveryId,
        contactId = contactId,
        price = newPrice,
        quantity = newQuantity,
    })
end)
