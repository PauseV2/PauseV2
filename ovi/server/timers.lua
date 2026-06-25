-- ============================================================
-- Delivery patience timers. Purely event driven - one thread per active
-- delivery, not a global tick loop.
-- ============================================================

if not Config.Toggle.Timers then return end

local Timers = Config.Timers

RegisterNetEvent('ovi:server:dealAccepted', function(imei, contactId, deliveryId)
    OVI.DB.SetDeliveryStatus(deliveryId, 'accepted')

    local waitSeconds = OVI.RandomRange(Timers.minWaitMinutes, Timers.maxWaitMinutes) * 60
    local startedAt = os.time()
    local endsAt = startedAt + waitSeconds

    OVI.Cache.timers[deliveryId] = { warned = {}, endsAt = endsAt }

    CreateThread(function()
        while true do
            Wait(5000)

            local delivery = OVI.DB.GetDelivery(deliveryId)
            if not delivery or delivery.status ~= 'accepted' then
                OVI.Cache.timers[deliveryId] = nil
                return
            end

            local remaining = endsAt - os.time()
            local elapsedPercent = ((waitSeconds - remaining) / waitSeconds) * 100
            local state = OVI.Cache.timers[deliveryId]
            if not state then return end

            for _, warning in ipairs(Timers.warnings) do
                if elapsedPercent >= warning.atPercent and not state.warned[warning.atPercent] then
                    state.warned[warning.atPercent] = true
                    OVI.DB.AddMessage(imei, contactId, 'client', warning.message, false)
                    OVI.NotifyPhoneHolder(imei, {
                        type = 'newMessage',
                        contactId = contactId,
                        message = warning.message,
                        deliveryId = deliveryId,
                        notification = 'OVI: client getting impatient',
                    })
                end
            end

            if remaining <= 0 then
                OVI.DB.SetDeliveryStatus(deliveryId, 'timeout')
                OVI.DB.AddMessage(imei, contactId, 'client', Timers.timeoutMessage, false)
                OVI.NotifyPhoneHolder(imei, {
                    type = 'newMessage',
                    contactId = contactId,
                    message = Timers.timeoutMessage,
                    deliveryId = deliveryId,
                    notification = 'OVI: deal timed out',
                })

                if Timers.timeoutConsequences.trustLoss then
                    local contactRow = OVI.DB.GetPhoneContact(imei, contactId)
                    if contactRow then
                        local newTrust = OVI.Clamp(contactRow.trust + Timers.timeoutConsequences.trustLoss, Config.Trust.minTrust, Config.Trust.maxTrust)
                        OVI.DB.UpdatePhoneContact(imei, contactId, { trust = newTrust })
                    end
                end

                if OVI.Chance(Timers.timeoutConsequences.complaintChance) then
                    TriggerEvent('ovi:server:fileComplaint', imei, contactId, 'minor')
                end

                if OVI.Chance(Timers.timeoutConsequences.contactBurnChance) then
                    TriggerEvent('ovi:server:blacklistContact', imei, contactId)
                end

                if Config.Toggle.ClientReplacement then
                    TriggerEvent('ovi:server:findReplacement', imei, contactId, deliveryId)
                end

                OVI.Cache.timers[deliveryId] = nil
                return
            end
        end
    end)
end)
