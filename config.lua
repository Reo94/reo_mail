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
    envelopeItem = 'reo_envelope_sealed'
}


-- ============================================================
-- SECTION 5: DEVELOPMENT SETTINGS
-- ============================================================

Config.Development = {
    -- Enable only while developing/testing your server installation.
    enabled = false
}

-- ============================================================
-- SECTION 6: PHYSICAL LETTER READER
-- ============================================================

Config.LetterReader = {
    prop = 'prop_cs_document_01',
    fallbackProp = 'prop_notepad_01',
    bone = 57005, -- right hand
    position = vec3(0.12, 0.02, -0.02),
    rotation = vec3(-90.0, 0.0, 10.0)
}

-- ============================================================
-- SECTION 7: LOST MAIL RECOVERY COUNTER
-- Change these coordinates to place the postal recovery desk.
-- Players may purchase unlimited replacement copies for cash.
-- ============================================================

Config.MailRecovery = {
    enabled = true,
    coords = vec3(78.12, 111.91, 81.17),
    radius = 1.75,
    drawDistance = 15.0,
    unlimitedReissues = true,
    reissueCost = 150,
    paymentType = 'cash'
}


-- ============================================================
-- SECTION 8: LETTER TEMPLATES
-- Templates are server validated. Additional business/job
-- templates can be added later without changing compose logic.
-- ============================================================

Config.MailTemplates = {
    basic = {
        label = 'Basic Mail',
        description = 'Standard personal REO Mail stationery.',
        access = 'public'
    }
}

Config.DefaultMailTemplate = 'basic'

-- ============================================================
-- SECTION 9: RECIPIENT DIRECTORY
-- Character search reads Qbox's persistent players table directly.
-- Results are ranked so partial first/last/full-name matches are easy to find.
-- ============================================================

Config.RecipientDirectory = {
    enabled = true,
    minimumSearchLength = 1,
    maxResults = 12,
    liveSearchDelay = 180
}

-- ============================================================
-- SECTION 10: BUSINESS MAILBOXES
-- Add businesses here. `job` must match the Qbox job name.
-- The mailbox location is where authorized employees collect mail.
-- ============================================================

Config.Businesses = {
    -- Business mailboxes are optional and disabled by default in the public core build.
    -- Copy this example and change the key, label, Qbox job name, and mailbox coords.
    --[[
    example_business = {
        label = 'Example Business',
        enabled = true,
        job = 'examplejob',
        mailbox = vec3(0.0, 0.0, 0.0),
        radius = 1.75,
        drawDistance = 15.0
    }
    ]]
}



-- ============================================================
-- SECTION 11: PACKAGE SYSTEM v0.6.0
-- Physical GoPostal hub + tracking + anonymous/scheduled/signature delivery.
-- ============================================================

Config.Packages = {
    enabled = true,
    paymentType = 'cash',

    sizes = {
        small  = { label = 'Small Shipping Box',       item = 'reo_shipping_box_small',  slots = 5,  maxWeight = 10000 },
        medium = { label = 'Medium Shipping Box',      item = 'reo_shipping_box_medium', slots = 10, maxWeight = 25000 },
        large  = { label = 'Large Shipping Box',       item = 'reo_shipping_box_large',  slots = 20, maxWeight = 50000 },
        xlarge = { label = 'Extra Large Shipping Box', item = 'reo_shipping_box_xlarge', slots = 30, maxWeight = 100000 }
    },

    -- Explicit default price table. Server owners can rebalance each service/box independently.
    services = {
        standard = {
            label = 'Standard',
            minutes = 120,
            prices = { small = 0, medium = 0, large = 0, xlarge = 0 }
        },
        priority = {
            label = 'Priority',
            minutes = 60,
            prices = { small = 115, medium = 190, large = 300, xlarge = 490 }
        },
        overnight = {
            label = 'Overnight',
            minutes = 30,
            prices = { small = 190, medium = 315, large = 500, xlarge = 815 }
        },
        express = {
            label = 'Express',
            minutes = 15,
            prices = { small = 275, medium = 450, large = 700, xlarge = 1100 }
        }
    },

    addons = {
        anonymous = { label = 'Anonymous Sender', fee = 100 },
        signature = { label = 'Signature Required', fee = 150 }
    },

    -- Return-to-sender transit after a refused signature delivery.
    returnMinutes = 30,

    -- Default GTA V GoPostal building in Downtown Vinewood.
    -- Coordinates remain configurable for servers using an MLO/map replacement.
    goPostal = {
        enabled = true,
        label = 'San Andreas Postal Service',
        -- Unified postal counter: same location as Lost Mail Recovery.
        coords = vec3(78.12, 111.91, 81.17),
        radius = 2.0,
        drawDistance = 20.0,
        blip = {
            enabled = true,
            sprite = 478,
            colour = 1,
            scale = 0.75,
            label = 'Postal Services'
        }
    },

    courier = {
        enabled = true,
        model = 's_m_m_postal_01',
        spawnMinRadius = 18.0,
        spawnMaxRadius = 28.0,
        approachDistance = 2.25,
        timeoutSeconds = 90,
        retryMinutes = 5
    }
}

-- ============================================================
-- SECTION 12: PREPARED LETTERS & ENVELOPES v0.7.0
-- Mail is prepared first, then physically deposited at GoPostal
-- or a supported vanilla public post box.
-- ============================================================
Config.PreparedMail = {
    enabled = true,
    maxEnvelopeDocuments = 5,
    freeDevelopmentSupplies = false,
    items = {
        blankLetter = 'reo_letter_blank',
        outgoingLetter = 'reo_outgoing_letter',
        openEnvelope = 'reo_envelope_open',
        sealedEnvelope = 'reo_outgoing_envelope'
    },
    services = {
        standard = { label = 'Standard', minutes = 120, fee = 0 },
        priority = { label = 'Priority', minutes = 60, fee = 115 },
        overnight = { label = 'Overnight', minutes = 30, fee = 190 },
        express = { label = 'Express', minutes = 15, fee = 275 }
    },
    signatureFee = 150,
    anonymousFee = 100
}



-- ============================================================
-- SECTION 12A: POSTAL SUPPLY SHOP v0.8.1
-- All pricing is server-authoritative. Players choose exact quantities.
-- ============================================================
Config.PostalSupplies = {
    maxQuantityPerItem = 50,
    items = {
        {
            key = 'blank_letter', item = 'reo_letter_blank', label = 'Blank Letter',
            description = 'Standard stationery used to write a physical letter.', price = 5,
            image = 'reo_letter_blank.png'
        },
        {
            key = 'mailing_envelope', item = 'reo_envelope_open', label = 'Mailing Envelope',
            description = 'Open envelope that holds up to five prepared letters or documents.', price = 10,
            image = 'reo_envelope_open.png',
            metadata = { contents = {}, documentCount = 0, label = 'Open Mailing Envelope' }
        },
        {
            key = 'box_small', item = 'reo_shipping_box_small', label = 'Small Shipping Box',
            description = 'Small reusable shipping box with 5 packing slots.', price = 25,
            image = 'reo_shipping_box_small.png'
        },
        {
            key = 'box_medium', item = 'reo_shipping_box_medium', label = 'Medium Shipping Box',
            description = 'Medium reusable shipping box with 10 packing slots.', price = 40,
            image = 'reo_shipping_box_medium.png'
        },
        {
            key = 'box_large', item = 'reo_shipping_box_large', label = 'Large Shipping Box',
            description = 'Large reusable shipping box with 20 packing slots.', price = 60,
            image = 'reo_shipping_box_large.png'
        },
        {
            key = 'box_xlarge', item = 'reo_shipping_box_xlarge', label = 'Extra Large Shipping Box',
            description = 'Extra large reusable shipping box with 30 packing slots.', price = 85,
            image = 'reo_shipping_box_xlarge.png'
        }
    }
}

-- ============================================================
-- SECTION 13: MAILBOX DELIVERY ELIGIBILITY
-- ============================================================
Config.MailboxDelivery = {
    letter = true,
    envelope = true,
    small = true,
    medium = false,
    large = false,
    xlarge = false
}

-- ============================================================
-- SECTION 14: VANILLA GTA V PUBLIC POST BOXES
-- ============================================================
Config.PublicMailboxes = {
    enabled = true,
    models = {
        'prop_postbox_01a',
        'prop_postbox_ss_01a'
    },
    interactDistance = 1.8,
    scanRadius = 2.2,
    allowLetters = true,
    allowEnvelopes = true,
    allowPackages = false
}

-- ============================================================
-- SECTION 15: POSTAL CLERK / OX_LIB SERVICES v0.9.0
-- Uses the existing GoPostal service point as the testing location.
-- Move these coords later if the server adopts a GoPostal MLO/interior.
-- ============================================================
Config.PostalClerk = {
    enabled = true,
    model = 's_m_m_postal_01',
    coords = vec4(78.12, 111.91, 80.17, 160.0),
    interactDistance = 2.25,
    drawDistance = 25.0,
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    label = 'Talk to Postal Clerk'
}
