fx_version 'cerulean'
game 'gta5'

description 'QB-Drugs by Saltylord'
version '1.0'

shared_scripts{
    '@oxmysql/lib/MySQL.lua',
    '@ox_lib/init.lua',
    '@qb-core/shared/locale.lua',
    'config.lua',
    'data/*.lua',
    'locales/*.lua'
}

client_scripts{
    'client/*.lua'
}

server_scripts{
    'server/*.lua'
}

lua54 'yes'
