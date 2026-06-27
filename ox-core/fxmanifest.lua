fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ox-core'
author 'OXBase'
description 'OXBase core framework - player, character, job, gang and money management'
version '0.1.0'

shared_scripts {
    'config/config.lua',
    'config/jobs.lua',
    'config/gangs.lua',
    'shared/shared.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/hooks.lua',
    'server/callbacks.lua',
    'server/player.lua',
    'server/money.lua',
    'server/jobs.lua',
    'server/characters.lua',
    'server/main.lua',
    'server/commands.lua',
    'server/exports.lua',
}

client_scripts {
    'client/callbacks.lua',
    'client/characters.lua',
    'client/main.lua',
    'client/exports.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/app.js',
    'html/style.css',
}

server_exports {
    'GetPlayer',
    'GetPlayerByCitizenId',
    'GetPlayers',
    'CreateCharacter',
    'DeleteCharacter',
    'AddMoney',
    'RemoveMoney',
    'SetMoney',
    'GetMoney',
    'SetJob',
    'SetGang',
    'SetMetadata',
    'RegisterHook',
}

exports {
    'GetPlayerData',
    'IsCharacterLoaded',
}

dependencies {
    'oxmysql',
}
