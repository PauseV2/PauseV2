-- ============================================================
-- Per-phone online/offline presence, toggled from the dashboard topbar.
-- Offline phones are skipped entirely by OVI.NotifyPhoneHolder (see
-- server/clients.lua) - NPCs simply don't text a phone that's offline.
-- ============================================================

RegisterNetEvent('ovi:server:setOnlineStatus', function(slot, online)
    local src = source
    local Player = OVI.GetPlayer(src)
    if not Player then return end

    local item = Player.Functions.GetItemBySlot(slot)
    if not item or not item.info or not item.info.imei then return end

    OVI.DB.SetOnlineStatus(item.info.imei, online and true or false)
    TriggerClientEvent('ovi:client:pushUpdate', src, { type = 'onlineStatus', online = online and true or false })
end)
