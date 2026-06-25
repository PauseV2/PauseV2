-- ============================================================
-- Trust / loyalty point adjustments.
-- ============================================================

if not Config.Toggle.Trust then return end

local Trust = Config.Trust

local REASONS = {
    onTime       = Trust.gains.onTime,
    fairPricing  = Trust.gains.fairPricing,
    rightProduct = Trust.gains.rightProduct,
    goodQuality  = Trust.gains.goodQuality,
    overpricing      = Trust.losses.overpricing,
    noShow           = Trust.losses.noShow,
    fakeProduct      = Trust.losses.fakeProduct,
    ignoring         = Trust.losses.ignoring,
    repeatedDeclines = Trust.losses.repeatedDeclines,
}

function OVI.AdjustTrust(imei, contactId, reasonKey)
    local amount = REASONS[reasonKey]
    if not amount then return end

    local contactRow = OVI.DB.GetPhoneContact(imei, contactId)
    if not contactRow then return end

    local newTrust = OVI.Clamp(contactRow.trust + amount, Trust.minTrust, Trust.maxTrust)
    local positive = amount > 0
    local newLoyalty = OVI.Clamp(
        contactRow.loyalty + (positive and Trust.loyaltyGainPerSuccess or -Trust.loyaltyLossPerFailure),
        0, 1000
    )

    local updates = { trust = newTrust, loyalty = newLoyalty }

    if newTrust <= Trust.burnThreshold then
        updates.burned = 1
        updates.blacklisted = 1
        TriggerEvent('ovi:server:contactBurned', imei, contactId)
    elseif newTrust <= Trust.blacklistThreshold then
        updates.blacklisted = 1
    end

    OVI.DB.UpdatePhoneContact(imei, contactId, updates)
end

RegisterNetEvent('ovi:server:adjustTrust', function(imei, contactId, reasonKey)
    OVI.AdjustTrust(imei, contactId, reasonKey)
end)

RegisterNetEvent('ovi:server:blacklistContact', function(imei, contactId)
    OVI.DB.UpdatePhoneContact(imei, contactId, { blacklisted = 1 })
end)

-- ----------------------------------------------------------- passive drift --
CreateThread(function()
    while true do
        Wait(60 * 60 * 1000) -- once per hour
        if Trust.recoveryRatePerHour > 0 then
            MySQL.update.await(
                'UPDATE ovi_contacts SET trust = trust - ? WHERE trust > 0 AND blacklisted = 0',
                { Trust.recoveryRatePerHour }
            )
            MySQL.update.await(
                'UPDATE ovi_contacts SET trust = trust + ? WHERE trust < 0 AND blacklisted = 0',
                { Trust.recoveryRatePerHour }
            )
        end
    end
end)
