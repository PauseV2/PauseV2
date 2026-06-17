--[[
    Auto photo capture
    ------------------
    Takes a screenshot of the player's character shortly after they spawn
    in and uploads it via screenshot-basic to a Discord webhook, then
    saves the resulting CDN URL as that citizen's tablet photo. Entirely
    optional - if screenshot-basic isn't running or Config.AutoPhoto.Webhook
    is left empty, this just does nothing and staff can still set a photo
    manually from the tablet.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local function captureAutoPhoto()
    if not Config.AutoPhoto.Enabled then return end
    if Config.AutoPhoto.Webhook == '' then return end
    if GetResourceState(Config.AutoPhoto.Resource) ~= 'started' then return end

    QBCore.Functions.TriggerCallback('pv-govtablet:server:needsAutoPhoto', function(needsPhoto)
        if not needsPhoto then return end

        Wait(Config.AutoPhoto.Delay)

        exports[Config.AutoPhoto.Resource]:requestScreenshotUpload(Config.AutoPhoto.Webhook, 'files[]', function(data)
            local ok, decoded = pcall(json.decode, data)
            local url = ok and decoded and decoded.attachments and decoded.attachments[1] and decoded.attachments[1].url
            if url then
                TriggerServerEvent('pv-govtablet:server:saveAutoPhoto', url)
            end
        end)
    end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', captureAutoPhoto)
