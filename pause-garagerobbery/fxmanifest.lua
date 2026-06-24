fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pause-garagerobbery'
author 'PauseV2'
description 'Modular garage / mechanic shop robbery system for QBCore'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/garage.lua',
    'client/hacking.lua',
    'client/loot.lua',
    'client/scrapping.lua',
    'client/police.lua',
}

server_scripts {
    'server/main.lua',
    'server/garage.lua',
    'server/loot.lua',
    'server/police.lua',
}

dependencies {
    'qb-core',
}
