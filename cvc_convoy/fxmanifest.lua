shared_script '@WaveShield/resource/include.lua'

fx_version 'cerulean'
game 'gta5'

author 'CVC Development'
description 'Mode de jeu Convoi contre Convoi - Instancié et configurable'
version '1.1.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua', -- Optionnel, pour les notifications améliorées
    'config.lua'
}

client_scripts {
    'client/utils.lua',
    'client/ped.lua',
    'client/teams.lua',
    'client/vehicles.lua',
    'client/main.lua'
}

server_scripts {
    'server/utils.lua',
    'server/teams.lua',
    'server/vehicles.lua', -- NOUVEAU: Gestion serveur des véhicules
    'server/commands.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'qs-inventory'
}