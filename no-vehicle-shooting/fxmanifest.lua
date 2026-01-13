fx_version 'cerulean'
game 'gta5'

author 'Votre Nom'
description 'Système anti-tir en véhicule optimisé + Changement de siège'
version '2.0.0'

lua54 'yes'

-- Interface NUI
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

-- Configuration
shared_script 'config.lua'

-- Scripts client
client_scripts {
    'client/main.lua',
    'client/seat_change.lua'
}

-- Scripts serveur
server_scripts {
    'server/main.lua',
    'server/seat_change.lua'
}