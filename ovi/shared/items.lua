-- ============================================================
-- OVI item definitions.
--
-- These are injected automatically into QBCore.Shared.Items on resource
-- start (see server/main.lua) so you do NOT have to manually edit
-- qb-core/shared/items.lua for a default install.
--
-- If your server validates items differently (custom inventory fork that
-- snapshots its own item list instead of reading QBCore.Shared.Items live),
-- copy the entries below into qb-core/shared/items.lua yourself.
--
-- Drop matching images (same file name as `image`) into your inventory
-- resource's image folder, e.g. qb-inventory/html/images/.
-- ============================================================

OVIItems = {
    ovi_burner = {
        name = 'ovi_burner',
        label = 'Cheap Burner',
        weight = 150,
        type = 'item',
        image = 'ovi_burner.png',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'A disposable prepaid phone. Untraceable, for now.',
    },
    ovi_midburner = {
        name = 'ovi_midburner',
        label = 'Mid-Tier Encrypted Burner',
        weight = 180,
        type = 'item',
        image = 'ovi_midburner.png',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Encrypted firmware. Harder to trace, easier to trust.',
    },
    ovi_ghostphone = {
        name = 'ovi_ghostphone',
        label = 'Premium Ghost Phone',
        weight = 200,
        type = 'item',
        image = 'ovi_ghostphone.png',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Top tier hardware. Spoofed GPS, military grade encryption.',
    },
    ovi_installkey = {
        name = 'ovi_installkey',
        label = 'OVI Installer Key',
        weight = 10,
        type = 'item',
        image = 'ovi_installkey.png',
        unique = true,
        useable = false,
        shouldClose = true,
        combinable = nil,
        description = 'A physical dongle used by OVI installers. Worth something to the right person.',
    },
    ovi_cryptowallet = {
        name = 'ovi_cryptowallet',
        label = 'Crypto Wallet',
        weight = 5,
        type = 'item',
        image = 'ovi_cryptowallet.png',
        unique = true,
        useable = false,
        shouldClose = true,
        combinable = nil,
        description = 'A hardware wallet. Could be worth a fortune, or nothing.',
    },
    ovi_fakeid = {
        name = 'ovi_fakeid',
        label = 'Fake ID',
        weight = 5,
        type = 'item',
        image = 'ovi_fakeid.png',
        unique = true,
        useable = false,
        shouldClose = true,
        combinable = nil,
        description = 'A convincing fake identity card.',
    },
    ovi_stashkey = {
        name = 'ovi_stashkey',
        label = 'Stash Key',
        weight = 5,
        type = 'item',
        image = 'ovi_stashkey.png',
        unique = true,
        useable = false,
        shouldClose = true,
        combinable = nil,
        description = 'Leads to a set of stash coordinates. Use it before someone else does.',
    },
}
