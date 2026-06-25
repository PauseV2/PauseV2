-- ============================================================
-- Server-side validation for the number-giver NPCs. Accepting a number
-- requires a phone with OVI fully installed ("an active key") - anything
-- else and the NPC declines rather than hand out their number.
-- ============================================================

if not Config.Toggle.NumberGivers then return end

RegisterNetEvent('ovi:server:numberGiverResponse', function(slot, npcIndex, accept)
    local src = source
    local Player = OVI.GetPlayer(src)
    if not Player then return end

    local cfg = Config.NumberGivers[npcIndex]
    if not cfg then return end
    if not accept then return end

    local item = Player.Functions.GetItemBySlot(slot)
    if not item or not item.info or not item.info.imei or not item.info.oviInstalled then
        TriggerClientEvent('ovi:client:numberGiverDeclined', src, cfg.declineLine or 'Please use a different phone, I will only talk on a private connection.')
        return
    end

    local imei = item.info.imei
    local contactId = OVI.CreateNewContact(imei)
    if not contactId then return end

    local globalClient = OVI.DB.GetGlobalClient(contactId)
    local message = "It's me. Save this number."
    OVI.DB.AddMessage(imei, contactId, 'client', message, false)

    OVI.NotifyPhoneHolder(imei, {
        type = 'newMessage',
        contactId = contactId,
        message = message,
        notification = ('OVI: new contact - %s'):format(globalClient and globalClient.full_name or 'Unknown'),
    })

    TriggerClientEvent('QBCore:Notify', src, 'New contact saved to OVI.', 'success')
end)
