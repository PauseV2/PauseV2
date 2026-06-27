fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ox-banking'
author 'OXBase'
description 'OXBase ATM banking (deposit/withdraw)'
version '0.1.0'

shared_scripts {
    'config/config.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/app.js',
    'html/style.css',
}

dependencies {
    'ox-core',
}
