-- ============================================================
-- REO DEVELOPMENT
-- REO MAIL
-- CONFIGURATION
-- ============================================================

Config = Config or {}

-- ============================================================
-- SECTION 1: GENERAL SETTINGS
-- ============================================================

-- Enables additional development/debug information.
Config.Debug = false

-- Framework used by REO Mail.
Config.Framework = 'qbx'


-- ============================================================
-- SECTION 2: POSTAL SETTINGS
-- ============================================================

Config.Postal = {
    -- Default sender used by the postal system.
    defaultSender = 'San Andreas Postal Service',

    -- Default type assigned to standard mail.
    defaultMailType = 'Standard',

    -- Prefix used for REO Mail tracking numbers.
    trackingPrefix = 'REO'
}


-- ============================================================
-- SECTION 3: PO BOX SETTINGS
-- ============================================================

Config.POBox = {
    -- Prefix displayed before PO Box numbers.
    prefix = 'PO BOX',

    -- Starting range for generated PO Box numbers.
    minNumber = 1000,

    -- Maximum range for generated PO Box numbers.
    maxNumber = 9999
}


-- ============================================================
-- SECTION 4: INVENTORY SETTINGS
-- ============================================================

Config.Inventory = {
    -- ox_inventory item used for physical letters.
    envelopeItem = 'reo_envelope'
}


-- ============================================================
-- SECTION 5: DEVELOPMENT SETTINGS
-- ============================================================

Config.Development = {
    -- Keep development/test functionality enabled while
    -- REO Mail is being built.
    enabled = true
}