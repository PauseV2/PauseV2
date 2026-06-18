--[[
    Audit logging - every read/write action performed through the
    tablet is written to gt_logs and optionally mirrored to Discord.
]]

Logger = {}

local actionColors = {
    search          = 3447003,
    view_profile    = 3447003,
    freeze          = 15158332,
    unfreeze        = 3066993,
    hide            = 10038562,
    reveal          = 3066993,
    seize_funds     = 15158332,
    seize_vehicle   = 15158332,
    release_vehicle = 3066993,
    impound_vehicle = 15105570,
    seize_property  = 15158332,
    restore_property= 3066993,
    add_record      = 15105570,
    approve_request = 3066993,
    deny_request    = 10038562,
}

local function sendWebhook(officialName, officialJob, action, targetCitizenId, details)
    if not Config.Webhook or Config.Webhook == '' then return end

    local embed = {
        {
            title = 'Government Tablet Action',
            color = actionColors[action] or 3447003,
            fields = {
                { name = 'Official', value = officialName, inline = true },
                { name = 'Role', value = officialJob, inline = true },
                { name = 'Action', value = action, inline = true },
                { name = 'Target Citizen', value = targetCitizenId or 'N/A', inline = true },
                { name = 'Details', value = details ~= '' and details or 'N/A' },
            },
            footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
        }
    }

    PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
        username = Config.WebhookName,
        avatar_url = Config.WebhookAvatar,
        embeds = embed,
    }), { ['Content-Type'] = 'application/json' })
end

-- official = { citizenid, name, job }
function Logger.Add(official, action, targetCitizenId, details)
    details = details or ''

    MySQL.insert.await([[
        INSERT INTO gt_logs (official_citizenid, official_name, official_job, action, target_citizenid, details)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { official.citizenid, official.name, official.job, action, targetCitizenId, details })

    sendWebhook(official.name, official.job, action, targetCitizenId, details)

    if Config.Debug then
        print(('[pv-govtablet] %s (%s) -> %s on %s | %s'):format(official.name, official.job, action, targetCitizenId or 'N/A', details))
    end
end

function Logger.GetRecent(limit)
    limit = tonumber(limit) or 100
    if limit > 200 then limit = 200 end
    return MySQL.query.await('SELECT * FROM gt_logs ORDER BY created_at DESC LIMIT ?', { limit }) or {}
end
