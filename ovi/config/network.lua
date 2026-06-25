Config = Config or {}

-- ============================================================
-- Global OVI network status. Replaces a visible "heat" readout with a
-- simple narrative connection state every player sees the same way -
-- the network is either safe to use or it's been compromised.
-- Toggled live by staff with /<command> when police take down the
-- network in an RP raid; every open OVI dashboard updates instantly.
-- ============================================================

Config.NetworkStatus = {
    command = 'oviraid', -- restricted command, requires the command.oviraid ace permission
    -- /oviraid stable   -> network is safe again
    -- /oviraid raided   -> network is compromised

    stable = {
        title    = 'OVI: Connection Stable.',
        subtitle = 'Unreadable.',
    },
    raided = {
        title    = 'OVI: Connection Failed.',
        subtitle = 'Detectable.',
    },
}
