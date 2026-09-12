-- ============================================================
-- REO DEVELOPMENT
-- REO MAIL
-- Server-Wide Physical Mail & Postal Framework
-- Version 2.0.0 Stable Public Core Release
-- ============================================================

fx_version 'cerulean'
game 'gta5'

author 'REO Development'
description 'Server-wide physical mail and postal framework for FiveM.'
version '2.0.0'

lua54 'yes'

-- ============================================================
-- SECTION 1: SHARED SCRIPTS
-- ============================================================

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/constants.lua'
}

-- ============================================================
-- SECTION 2: CLIENT SCRIPTS
-- ============================================================

client_scripts {
    'client/main.lua',
    'client/prepared_mail.lua'
}

-- ============================================================
-- SECTION 3: NUI LETTER READER
-- ============================================================

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/images/*.png'
}

-- ============================================================
-- SECTION 4: SERVER SCRIPTS
-- ============================================================

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'bridges/server/qbx.lua',
    'server/prepared_mail.lua'
}

-- ============================================================
-- SECTION 5: DEPENDENCIES
-- ============================================================

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory'
}
