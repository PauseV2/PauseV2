Config = Config or {}

-- ============================================================
-- OVI app appearance / behaviour. Pure presentation config, consumed by
-- html/app.js through the 'ovi:init' NUI message.
-- ============================================================

Config.UI = {
    appName       = 'OVI',
    appSubtitle   = 'Onderworld Connection Interface',
    theme = {
        background     = '#0a0d0a',
        panel          = '#11140f',
        accent         = '#1d8348',
        accentBright   = '#27ae60',
        danger         = '#8b1a1a',
        text           = '#d9f2dd',
        textMuted      = '#6f8f76',
        border         = '#1c2a1c',
    },
    bootLoadingTimeMs = 1600,    -- fake "encrypted handshake" boot animation length
    bootLines = {
        'establishing encrypted tunnel...',
        'spoofing carrier handshake...',
        'verifying device signature...',
        'loading vault...',
    },
    tabs = {
        contacts   = true,
        messages   = true,
        deliveries = true,
        connection = true,
        vault      = true,
        burn       = true,
    },
}
