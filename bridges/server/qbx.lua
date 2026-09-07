-- ============================================================
-- REO DEVELOPMENT
-- REO MAIL
-- Qbox Framework Bridge
-- Version 0.1.0
-- ============================================================

if Config.Framework ~= 'qbx' then return end

print('[reo_mail] Qbox bridge loaded successfully.')


-- ============================================================
-- SECTION 1: CHARACTER RESOLUTION
-- ============================================================

local function GetCharacterData(source)
    local player = exports.qbx_core:GetPlayer(source)

    if not player or not player.PlayerData then
        return nil
    end

    return player.PlayerData
end


local function GetCharacterId(source)
    local data = GetCharacterData(source)

    return data and data.citizenid or nil
end


-- Expose character resolution to the REO Mail server core.
REO_MAIL.Server.GetCharacterId = GetCharacterId


local function EnsurePlayerMailProfile(source)
    local characterId = GetCharacterId(source)

    if not characterId then
        return nil
    end

    local profile = REO_MAIL.Server.EnsureMailProfile(characterId)

    if profile and Config.Debug then
        print(
            ('[reo_mail] Character %s resolved to PO Box %s.')
                :format(characterId, profile.po_box)
        )
    end

    return profile
end


-- ============================================================
-- SECTION 2: PO BOX COMMAND
-- ============================================================

RegisterCommand('mypobox', function(source)

    if source == 0 then
        print('[reo_mail] /mypobox must be used by an in-game player.')
        return
    end

    local profile = EnsurePlayerMailProfile(source)

    if not profile then
        return
    end

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'San Andreas Postal Service',
        description = ('Your permanent mailing address is PO Box %s.')
            :format(profile.po_box),
        type = 'success'
    })
end, false)


-- ============================================================
-- SECTION 3: CHARACTER LOAD
-- ============================================================

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    EnsurePlayerMailProfile(source)
end)


-- ============================================================
-- SECTION 4: DEVELOPMENT MAIL TEST
-- ============================================================

RegisterCommand('mymailtest', function(source)

    if source == 0 then
        print('[reo_mail] /mymailtest must be used by an in-game player.')
        return
    end

    local characterId = GetCharacterId(source)

    if not characterId then
        return
    end

    local mailItems = REO_MAIL.Server.GetCharacterMail(characterId)

    print('============================================================')
    print(' REO DEVELOPMENT - CHARACTER MAIL TEST')
    print('============================================================')
    print((' Character ID: %s'):format(characterId))
    print((' Mail Found:   %s'):format(#mailItems))

    for i, mail in ipairs(mailItems) do
        print(
            (' [%s] %s | %s | %s | %s')
                :format(
                    i,
                    mail.tracking_number,
                    mail.sender_name,
                    mail.subject or 'No Subject',
                    mail.status
                )
        )
    end

    print('============================================================')
end, false)


-- ============================================================
-- SECTION 5: MAILBOX DATA CALLBACK
-- ============================================================

lib.callback.register('reo_mail:server:getMailbox', function(source)

    local characterId = GetCharacterId(source)

    if not characterId then
        return {}
    end

    local items = REO_MAIL.Server.GetCharacterMail(characterId)

    local mailbox = {}

    for _, mail in ipairs(items) do
        mailbox[#mailbox + 1] = {
            id = mail.id,
            trackingNumber = mail.tracking_number,
            senderName = mail.sender_name,
            subject = mail.subject or 'No Subject',
            status = mail.status,
            mailType = mail.mail_type,
            createdAt = mail.created_at,
            claimed = mail.claimed_at ~= nil
        }
    end

    if Config.Debug then
        print(
            ('[reo_mail] Sent %s mailbox item(s) to character %s.')
                :format(#mailbox, characterId)
        )
    end

    return mailbox
end)


-- ============================================================
-- SECTION 6: SECURE INDIVIDUAL MAIL CALLBACK
-- ============================================================

lib.callback.register('reo_mail:server:getMailItem', function(source, mailId)

    local characterId = GetCharacterId(source)

    if not characterId or not mailId then
        return nil
    end

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
        return nil
    end

    if Config.Debug then
        print(
            ('[reo_mail] Character %s opened mail ID %s.')
                :format(characterId, mail.id)
        )
    end

    return {
        id = mail.id,
        trackingNumber = mail.tracking_number,
        senderName = mail.sender_name,
        recipientName = mail.recipient_name,
        subject = mail.subject or 'No Subject',
        body = mail.body or '',
        status = mail.status,
        mailType = mail.mail_type,
        createdAt = mail.created_at,
        claimed = mail.claimed_at ~= nil
    }
end)


-- ============================================================
-- SECTION 7: CLAIM PHYSICAL MAIL
-- ============================================================

lib.callback.register('reo_mail:server:claimMail', function(source, mailId)

    local characterId = GetCharacterId(source)

    if not characterId or not mailId then
        return false, 'invalid_mail'
    end

    local mail = MySQL.single.await([[
        SELECT id, claimed_at
        FROM reo_mail_items
        WHERE id = ?
          AND recipient_character_id = ?
        LIMIT 1
    ]], {
        mailId,
        characterId
    })

    if not mail then
        return false, 'mail_not_found'
    end

    if mail.claimed_at then
        return false, 'already_claimed'
    end

    local created = REO_MAIL.Server.CreatePhysicalEnvelope(
        source,
        mail.id
    )

    if not created then
        return false, 'inventory_failed'
    end

    local updated = MySQL.update.await([[
        UPDATE reo_mail_items
        SET claimed_at = CURRENT_TIMESTAMP
        WHERE id = ?
          AND recipient_character_id = ?
          AND claimed_at IS NULL
    ]], {
        mail.id,
        characterId
    })

    if not updated or updated < 1 then
        print(
            ('[reo_mail] WARNING: Envelope created but claim state failed for Mail ID %s.')
                :format(mail.id)
        )

        return false, 'claim_update_failed'
    end

    if Config.Debug then
        print(
            ('[reo_mail] Character %s claimed physical Mail ID %s.')
                :format(characterId, mail.id)
        )
    end

    return true
end)


-- ============================================================
-- SECTION 8: OPEN PHYSICAL ENVELOPE
-- ============================================================

lib.callback.register('reo_mail:server:openPhysicalEnvelope', function(source, slotId)

    local characterId = GetCharacterId(source)

    if not characterId or not slotId then
        return nil, 'invalid_envelope'
    end

    -- --------------------------------------------------------
    -- Validate Inventory Item
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
    -- Validate Postal Record
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
    -- Update Physical Envelope State
    -- --------------------------------------------------------

    local wasOpened = metadata.opened == true

    if not wasOpened then

        metadata.opened = true
        metadata.label = 'Opened Envelope'

        metadata.description =
            ('Opened Mail | From: %s | Tracking: %s')
                :format(
                    mail.sender_name or 'Unknown Sender',
                    mail.tracking_number or 'Unknown'
                )

        exports.ox_inventory:SetMetadata(
            source,
            slotId,
            metadata
        )

        if Config.Debug then
            print(
                ('[reo_mail] Character %s opened physical Mail ID %s in inventory slot %s for the first time.')
                    :format(
                        characterId,
                        mail.id,
                        slotId
                    )
            )
        end

    elseif Config.Debug then

        print(
            ('[reo_mail] Character %s reopened physical Mail ID %s in inventory slot %s.')
                :format(
                    characterId,
                    mail.id,
                    slotId
                )
        )
    end

    -- --------------------------------------------------------
    -- Return Mail Information
    -- --------------------------------------------------------

    return {
        id = mail.id,
        trackingNumber = mail.tracking_number,
        senderName = mail.sender_name,
        recipientName = mail.recipient_name,
        subject = mail.subject or 'No Subject',
        body = mail.body or '',
        status = mail.status,
        mailType = mail.mail_type,
        createdAt = mail.created_at,
        claimed = mail.claimed_at ~= nil,
        firstOpen = not wasOpened
    }
end)

-- ============================================================
-- SECTION 10: PLAYER-TO-PLAYER LETTER DELIVERY
-- Development interface used by /sendmail.
-- ============================================================

local function GetCharacterDisplayName(source)
    local data = GetCharacterData(source)
    if not data then return nil end

    local charinfo = data.charinfo or {}
    local firstName = charinfo.firstname or charinfo.firstName
    local lastName = charinfo.lastname or charinfo.lastName

    local fullName = (('%s %s'):format(firstName or '', lastName or ''))
        :gsub('^%s+', '')
        :gsub('%s+$', '')

    if fullName ~= '' then return fullName end
    return data.name or data.citizenid or 'Unknown Sender'
end

lib.callback.register('reo_mail:server:sendPlayerLetter', function(source, data)
    if source == 0 or type(data) ~= 'table' then
        return { success = false, reason = 'invalid_content' }
    end

    local senderCharacterId = GetCharacterId(source)
    if not senderCharacterId then
        return { success = false, reason = 'character_unavailable' }
    end

    local poBox = tonumber(data.poBox)
    local subject = type(data.subject) == 'string' and data.subject:gsub('^%s+', ''):gsub('%s+$', '') or ''
    local body = type(data.body) == 'string' and data.body:gsub('^%s+', ''):gsub('%s+$', '') or ''

    if not poBox or subject == '' or body == '' or #subject > 100 or #body > 4000 then
        return { success = false, reason = 'invalid_content' }
    end

    local recipientProfile = MySQL.single.await(
        'SELECT character_id, po_box FROM reo_mail_profiles WHERE po_box = ? LIMIT 1',
        { poBox }
    )

    if not recipientProfile then
        return { success = false, reason = 'invalid_recipient' }
    end

    if recipientProfile.character_id == senderCharacterId then
        return { success = false, reason = 'self_mail' }
    end

    local senderName = GetCharacterDisplayName(source)
    local result = REO_MAIL.Server.CreateMail({
        recipientCharacterId = recipientProfile.character_id,
        recipientName = ('PO Box %s Recipient'):format(recipientProfile.po_box),
        senderType = REO_MAIL.SenderTypes.CHARACTER,
        senderId = senderCharacterId,
        senderName = senderName,
        mailType = REO_MAIL.Types.LETTER,
        subject = subject,
        body = body
    })

    if not result then
        return { success = false, reason = 'creation_failed' }
    end

    -- For this development stage, player letters are delivered directly
    -- to the recipient's persistent mailbox. Postal routing comes later.
    MySQL.update.await([[
        UPDATE reo_mail_items
        SET status = ?, delivered_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], { REO_MAIL.Status.DELIVERED, result.id })

    if Config.Debug then
        print(
            ('[reo_mail] %s (%s) mailed letter %s to PO Box %s (%s).')
                :format(senderName, senderCharacterId, result.trackingNumber, poBox, recipientProfile.character_id)
        )
    end

    return {
        success = true,
        mailId = result.id,
        trackingNumber = result.trackingNumber,
        poBox = recipientProfile.po_box
    }
end)
