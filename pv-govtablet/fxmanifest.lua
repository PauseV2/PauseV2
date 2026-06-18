fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pv-govtablet'
author 'PauseV2'
description 'Government Tablet System - secure citizen profile & asset management for QBCore'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/img/placeholder.svg'
}

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
    'shared/sh_utils.lua'
}

client_scripts {
    'client/cl_main.lua',
    'client/cl_photo.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua',
    'server/sv_logs.lua',
    'server/sv_riskmonitor.lua',
    'bridge/sv_banking.lua',
    'bridge/sv_housing.lua',
    'bridge/sv_garage.lua',
    'bridge/sv_police.lua',
    'bridge/sv_accounts.lua',
    'bridge/sv_business.lua'
}

dependencies {
    'qb-core',
    'oxmysql'
}
