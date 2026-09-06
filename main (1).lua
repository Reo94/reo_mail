-- ============================================================
-- REO DEVELOPMENT
-- REO MAIL
-- Server Core
-- Version 0.1.0
-- ============================================================

local RESOURCE_NAME = GetCurrentResourceName()
REO_MAIL.Server = REO_MAIL.Server or {}

-- ============================================================
-- SECTION 1: DEBUG LOGGER
-- ============================================================

local function DebugPrint(message)
    if Config.Debug then print(('[%s] %s'):format(RESOURCE_NAME, message)) end
end

-- ============================================================
-- SECTION 2: POSTAL PROFILES
-- ============================================================

local function GetMailProfile(characterId)
    if not characterId then return nil end
    return MySQL.single.await('SELECT * FROM reo_mail_profiles WHERE character_id = ? LIMIT 1', { characterId })
end

local function GetNextPOBox()
    local highest = MySQL.scalar.await('SELECT MAX(po_box) FROM reo_mail_profiles')
    return highest and (tonumber(highest) + 1) or Config.POBox.StartingNumber or Config.POBox.minNumber or 1000
end

local function CreateMailProfile(characterId)
    if not characterId then return nil end
    local existing = GetMailProfile(characterId)
    if existing then return existing end

    local poBox = GetNextPOBox()
    local insertId = MySQL.insert.await([[
        INSERT INTO reo_mail_profiles (character_id, po_box, preferred_address_type)
        VALUES (?, ?, ?)
    ]], { characterId, poBox, REO_MAIL.AddressTypes.PO_BOX })

    if not insertId then
        print(('[%s] ERROR: Failed to create mail profile for character %s.'):format(RESOURCE_NAME, characterId))
        return nil
    end

    DebugPrint(('Created mail profile for character %s with PO Box %s.'):format(characterId, poBox))
    return GetMailProfile(characterId)
end

local function EnsureMailProfile(characterId)
    if not characterId then return nil end
    return GetMailProfile(characterId) or CreateMailProfile(characterId)
end

REO_MAIL.Server.EnsureMailProfile = EnsureMailProfile

-- ============================================================
-- SECTION 3: ADDRESS RESOLUTION
-- ============================================================

local function ResolveMailingAddress(characterId)
    local profile = EnsureMailProfile(characterId)
    if not profile then return nil end

    return {
        type = REO_MAIL.AddressTypes.PO_BOX,
        id = tostring(profile.po_box),
        label = ('%s %s'):format(Config.POBox.Prefix or Config.POBox.prefix or 'PO Box', profile.po_box),
        postOffice = (Config.PostalService and Config.PostalService.CentralOffice) or 'Central Post Office'
    }
end

REO_MAIL.Server.ResolveMailingAddress = ResolveMailingAddress

-- ============================================================
-- SECTION 4: TRACKING + MAIL CREATION
-- ============================================================

local function GenerateTrackingNumber()
    return ('REO-%s-%06d'):format(os.time(), math.random(0, 999999))
end

local function CreateMail(data)
    if not data or not data.recipientCharacterId then return nil end

    local destination = ResolveMailingAddress(data.recipientCharacterId)
    if not destination then return nil end

    local tracking = GenerateTrackingNumber()
    local insertId = MySQL.insert.await([[
        INSERT INTO reo_mail_items (
            tracking_number, sender_type, sender_id, sender_name,
            recipient_character_id, recipient_name, mail_type,
            subject, body, status, destination_type, destination_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        tracking,
        data.senderType or REO_MAIL.SenderTypes.SYSTEM,
        data.senderId,
        data.senderName or (Config.PostalService and Config.PostalService.Name) or (Config.Postal and Config.Postal.defaultSender) or 'San Andreas Postal Service',
        data.recipientCharacterId,
        data.recipientName,
        data.mailType or REO_MAIL.Types.LETTER,
        data.subject,
        data.body,
        REO_MAIL.Status.CREATED,
        destination.type,
        destination.id
    })

    if not insertId then return nil end
    DebugPrint(('Created mail item %s with tracking number %s.'):format(insertId, tracking))

    return { id = insertId, trackingNumber = tracking, destination = destination }
end

REO_MAIL.Server.CreateMail = CreateMail

-- ============================================================
-- SECTION 5: MAIL RETRIEVAL
-- ============================================================

local function GetCharacterMail(characterId)
    if not characterId then return {} end
    return MySQL.query.await([[
        SELECT * FROM reo_mail_items
        WHERE recipient_character_id = ?
        ORDER BY created_at DESC, id DESC
    ]], { characterId }) or {}
end

REO_MAIL.Server.GetCharacterMail = GetCharacterMail

-- ============================================================
-- SECTION 6: PHYSICAL ENVELOPE
-- ============================================================

local function CreatePhysicalEnvelope(source, mailId)
    if not source or source == 0 or not mailId then return false end

    local mail = MySQL.single.await('SELECT * FROM reo_mail_items WHERE id = ? LIMIT 1', { mailId })
    if not mail then return false end

    local metadata = {
        mailId = mail.id,
        trackingNumber = mail.tracking_number,
        sender = mail.sender_name,
        recipient = mail.recipient_name,
        subject = mail.subject or 'No Subject',

        -- ========================================================
        -- ENVELOPE STATE
        -- Physical envelopes begin sealed and remember their state
        -- independently through ox_inventory metadata.
        -- ========================================================
        opened = false,
        label = 'Sealed Envelope',
        description = ('Sealed Mail | From: %s | Tracking: %s'):format(mail.sender_name, mail.tracking_number)
    }

    local success, response = exports.ox_inventory:AddItem(source, 'reo_envelope', 1, metadata)
    if not success then
        DebugPrint(('Failed to give envelope for Mail ID %s: %s'):format(mailId, tostring(response)))
        return false
    end

    DebugPrint(('Created physical envelope for Mail ID %s and gave it to source %s.'):format(mailId, source))
    return true
end

REO_MAIL.Server.CreatePhysicalEnvelope = CreatePhysicalEnvelope

-- ============================================================
-- SECTION 7: DEVELOPMENT COMMANDS
-- ============================================================

RegisterCommand('reomailtest', function(_, args)
    local characterId = args[1]
    if not characterId then print('[reo_mail] Usage: reomailtest <characterId>') return end
    local profile = EnsureMailProfile(characterId)
    local address = ResolveMailingAddress(characterId)
    if not profile or not address then return end
    print(('REO MAIL TEST | Character: %s | PO Box: %s | Address: %s'):format(characterId, profile.po_box, address.label))
end, true)

RegisterCommand('reomailsendtest', function(_, args)
    local characterId = args[1]
    if not characterId then print('[reo_mail] Usage: reomailsendtest <characterId>') return end
    local result = CreateMail({
        recipientCharacterId = characterId,
        recipientName = 'Test Recipient',
        senderType = REO_MAIL.SenderTypes.SYSTEM,
        senderId = 'reo_mail',
        senderName = 'San Andreas Postal Service',
        mailType = REO_MAIL.Types.LETTER,
        subject = 'Welcome to REO Mail',
        body = 'This is the first test letter created through the REO Mail postal framework.'
    })
    if not result then print('[reo_mail] Mail creation test FAILED.') return end
    print(('REO MAIL CREATION TEST | Mail ID: %s | Tracking: %s | Destination: %s'):format(result.id, result.trackingNumber, result.destination.label))
end, true)

-- ============================================================
-- SECTION 8: RESOURCE START
-- ============================================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE_NAME then return end
    print('============================================================')
    print(' REO DEVELOPMENT')
    print(' REO MAIL v0.1.0')
    print('============================================================')
    print(' Postal core initialized.')
    print('============================================================')
    DebugPrint('Debug mode is enabled.')
end)

-- ============================================================
-- SECTION 9: PHYSICAL ENVELOPE INTERACTIONS
-- ============================================================


-- ============================================================
-- SECTION 9A: INSPECT PHYSICAL ENVELOPE
-- ============================================================

lib.callback.register('reo_mail:server:inspectPhysicalEnvelope', function(source, slotId)

    -- --------------------------------------------------------
    -- Validate Physical Envelope
    -- --------------------------------------------------------

    local slot = exports.ox_inventory:GetSlot(source, slotId)

    if not slot or slot.name ~= 'reo_envelope' then
        return nil, 'invalid_envelope'
    end

    local metadata = slot.metadata or {}
    local mailId = tonumber(metadata.mailId)

    if not mailId then
        return nil, 'invalid_envelope'
    end

    -- --------------------------------------------------------
    -- Resolve Active Character
    -- --------------------------------------------------------

    local characterId = REO_MAIL.Server.GetCharacterId(source)

    if not characterId then
        return nil, 'character_not_found'
    end

    -- --------------------------------------------------------
    -- Retrieve And Validate Postal Record
    -- --------------------------------------------------------

    local mail = MySQL.single.await([[
        SELECT *
        FROM reo_mail_items
        WHERE id = ?
          AND recipient_character_id = ?
        LIMIT 1
    ]], {
        mailId,
        characterId
    })

    if not mail then
        return nil, 'mail_not_found'
    end

    -- --------------------------------------------------------
    -- Return Exterior Envelope Information
    -- --------------------------------------------------------

    return {
        mailId = mail.id,
        senderName = mail.sender_name or 'Unknown Sender',
        recipientName = mail.recipient_name or 'Unknown Recipient',
        subject = mail.subject or 'No Subject',
        trackingNumber = mail.tracking_number or 'Unknown',
        mailType = mail.mail_type or 'Standard',
        opened = metadata.opened == true
    }
end)


-- ============================================================
-- SECTION 9B: OPEN PHYSICAL ENVELOPE
-- ============================================================

lib.callback.register('reo_mail:server:openPhysicalEnvelope', function(source, slotId)

    -- --------------------------------------------------------
    -- Validate Physical Envelope
    -- --------------------------------------------------------

    local slot = exports.ox_inventory:GetSlot(source, slotId)

    if not slot or slot.name ~= 'reo_envelope' then
        return nil, 'invalid_envelope'
    end

    local metadata = slot.metadata or {}
    local mailId = tonumber(metadata.mailId)

    if not mailId then
        return nil, 'invalid_envelope'
    end

    -- --------------------------------------------------------
    -- Resolve Active Character
    -- --------------------------------------------------------

    local characterId = REO_MAIL.Server.GetCharacterId(source)

    if not characterId then
        return nil, 'character_not_found'
    end

    -- --------------------------------------------------------
    -- Retrieve And Validate Postal Record / Ownership
    -- --------------------------------------------------------

    local mail = MySQL.single.await([[
        SELECT *
        FROM reo_mail_items
        WHERE id = ?
          AND recipient_character_id = ?
        LIMIT 1
    ]], {
        mailId,
        characterId
    })

    if not mail then
        return nil, 'mail_not_found'
    end

    -- --------------------------------------------------------
    -- Mark Physical Envelope As Opened
    -- --------------------------------------------------------

    if metadata.opened ~= true then
        metadata.opened = true
        metadata.label = 'Opened Envelope'
        metadata.description = 'An opened piece of mail handled by the San Andreas Postal Service.'

        exports.ox_inventory:SetMetadata(source, slotId, metadata)
    end

    -- --------------------------------------------------------
    -- Return Updated Envelope Information
    -- --------------------------------------------------------

    return {
        mailId = mail.id,
        senderName = mail.sender_name or 'Unknown Sender',
        recipientName = mail.recipient_name or 'Unknown Recipient',
        subject = mail.subject or 'No Subject',
        trackingNumber = mail.tracking_number or 'Unknown',
        mailType = mail.mail_type or 'Standard',
        status = mail.status or 'Unknown',
        opened = true
    }
end)


-- ============================================================
-- SECTION 9C: READ PHYSICAL ENVELOPE
-- ============================================================

lib.callback.register('reo_mail:server:readPhysicalEnvelope', function(source, slotId)

    -- --------------------------------------------------------
    -- Validate Physical Envelope
    -- --------------------------------------------------------

    local slot = exports.ox_inventory:GetSlot(source, slotId)

    if not slot or slot.name ~= 'reo_envelope' then
        return nil, 'invalid_envelope'
    end

    local metadata = slot.metadata or {}
    local mailId = tonumber(metadata.mailId)

    if not mailId then
        return nil, 'invalid_envelope'
    end

    -- --------------------------------------------------------
    -- Require Envelope To Be Opened
    -- --------------------------------------------------------

    if metadata.opened ~= true then
        return nil, 'envelope_sealed'
    end

    -- --------------------------------------------------------
    -- Resolve Active Character
    -- --------------------------------------------------------

    local characterId = REO_MAIL.Server.GetCharacterId(source)

    if not characterId then
        return nil, 'character_not_found'
    end

    -- --------------------------------------------------------
    -- Retrieve And Validate Postal Record
    -- --------------------------------------------------------

    local mail = MySQL.single.await([[
        SELECT *
        FROM reo_mail_items
        WHERE id = ?
          AND recipient_character_id = ?
        LIMIT 1
    ]], {
        mailId,
        characterId
    })

    if not mail then
        return nil, 'mail_not_found'
    end

    -- --------------------------------------------------------
    -- Return Letter Contents
    -- --------------------------------------------------------

    return {
        mailId = mail.id,
        senderName = mail.sender_name or 'Unknown Sender',
        recipientName = mail.recipient_name or 'Unknown Recipient',
        subject = mail.subject or 'No Subject',
        body = mail.body or '',
        trackingNumber = mail.tracking_number or 'Unknown',
        mailType = mail.mail_type or 'Standard',
        status = mail.status or 'Unknown'
    }
end)