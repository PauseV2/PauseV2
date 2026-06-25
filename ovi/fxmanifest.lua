fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ovi'
author 'OVI'
description 'OVI - Onderworld Connection Interface | Persistent criminal phone network for QBCore'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config/main.lua',
    'config/phones.lua',
    'config/installers.lua',
    'config/security.lua',
    'config/ui.lua',
    'config/street_sales.lua',
    'config/clients.lua',
    'config/drugs.lua',
    'config/negotiation.lua',
    'config/trust.lua',
    'config/timers.lua',
    'config/complaints.lua',
    'config/referrals.lua',
    'config/shared_clients.lua',
    'config/replacement.lua',
    'config/heat.lua',
    'config/network.lua',
    'config/deaddrops.lua',
    'config/random_contacts.lua',
    'config/traps.lua',
    'config/vehicle_loot.lua',
    'config/suppliers.lua',
    'config/ghosting.lua',
    'config/police.lua',
    'config/cloning.lua',
    'config/codes.lua',
    'config/numbergivers.lua',
    'shared/items.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua',
    'client/phone.lua',
    'client/installer.lua',
    'client/deaddrops.lua',
    'client/traps.lua',
    'client/cloning.lua',
    'client/suppliers.lua',
    'client/numbergivers.lua',
    'client/streetsales.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/main.lua',
    'server/phones.lua',
    'server/security.lua',
    'server/clients.lua',
    'server/negotiation.lua',
    'server/trust.lua',
    'server/heat.lua',
    'server/network.lua',
    'server/timers.lua',
    'server/deliveries.lua',
    'server/complaints.lua',
    'server/referrals.lua',
    'server/shared.lua',
    'server/replacement.lua',
    'server/deaddrops.lua',
    'server/randomcontacts.lua',
    'server/traps.lua',
    'server/suppliers.lua',
    'server/ghosting.lua',
    'server/police.lua',
    'server/cloning.lua',
    'server/codes.lua',
    'server/installer.lua',
    'server/setup.lua',
    'server/presence.lua',
    'server/numbergivers.lua',
    'server/streetsales.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/img/*.png'
}

dependencies {
    'qb-core',
    'oxmysql'
}

escrow_ignore {
    'config/*.lua',
    'sql/*.sql'
}
