-- ============================================================
-- REO DEVELOPMENT
-- REO MAIL
-- Server-Wide Physical Mail & Postal Framework
-- Version 0.1.0 Proof of Concept
-- ============================================================

fx_version 'cerulean'
game 'gta5'

author 'REO Development'
description 'Server-wide physical mail and postal framework for FiveM.'
version '0.1.0'

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
    'client/main.lua'
}

-- ============================================================
-- SECTION 3: SERVER SCRIPTS
-- ============================================================

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'bridges/server/qbx.lua'
}

-- ============================================================
-- SECTION 4: DEPENDENCIES
-- ============================================================

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory'
}
