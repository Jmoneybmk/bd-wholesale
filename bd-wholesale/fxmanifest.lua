fx_version 'cerulean'
game 'gta5'

author 'Big Domo'
description 'NPC Distributor'
version '1.0.0'

shared_scripts {
'@ox_lib/init.lua',
'config.lua'
}

client_scripts {
'client.lua'
}

server_scripts {
'@oxmysql/lib/mysql.lua',
'server.lua'
}

dependencies {
'qb-core',
'qb-target',
'ox_lib',
'oxmysql'
}

lua54 'yes'