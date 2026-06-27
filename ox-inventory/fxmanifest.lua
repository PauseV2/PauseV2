fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ox-inventory'
author 'OXBase'
description 'OXBase weight-based inventory, stashes, and shops'
version '0.1.0'

shared_scripts {
    'config/config.lua',
    'config/items.lua',
    'config/shops.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/callbacks.lua',
    'server/inventory.lua',
    'server/player.lua',
    'server/shops.lua',
    'server/exports.lua',
}

client_scripts {
    'client/callbacks.lua',
    'client/main.lua',
    'client/shops.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/app.js',
    'html/style.css',
}

server_exports {
    'AddItem',
    'RemoveItem',
    'GetItemCount',
    'HasItem',
    'GetInventory',
}

dependencies {
    'ox-core',
    'oxmysql',
}
