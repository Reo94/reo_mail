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
-- SECTION 10: CHARACTER DISPLAY NAME
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


REO_MAIL.Server.GetCharacterDisplayName = GetCharacterDisplayName

-- ============================================================
-- SECTION 11: CHARACTER JOB
-- Used by business mailbox authorization.
-- ============================================================

local function GetCharacterJobName(source)
    local data = GetCharacterData(source)
    if not data or not data.job then return nil end
    return data.job.name
end

REO_MAIL.Server.GetCharacterJobName = GetCharacterJobName

-- ============================================================
-- SECTION 12: CASH HELPERS
-- Used by package postage and lost-mail recovery.
-- ============================================================

if not REO_MAIL.Server.GetCash then
    REO_MAIL.Server.GetCash = function(source)
        local data = GetCharacterData(source)
        return data and data.money and tonumber(data.money.cash) or 0
    end
end
if not REO_MAIL.Server.RemoveCash then
    REO_MAIL.Server.RemoveCash = function(source, amount, reason)
        local player = exports.qbx_core:GetPlayer(source)
        return player and player.Functions and player.Functions.RemoveMoney('cash', amount, reason or 'reo-mail') == true or false
    end
end
if not REO_MAIL.Server.AddCash then
    REO_MAIL.Server.AddCash = function(source, amount, reason)
        local player = exports.qbx_core:GetPlayer(source)
        return player and player.Functions and player.Functions.AddMoney('cash', amount, reason or 'reo-mail-refund') == true or false
    end
end
