-- ============================================================
-- REO DEVELOPMENT
-- REO MAIL
-- Qbox Framework Bridge
-- Version 0.1.0
-- ============================================================


-- ============================================================
-- SECTION 1: FRAMEWORK CHECK
-- ============================================================

if Config.Framework ~= 'qbx' then
    return
end

print('[reo_mail] Qbox bridge loaded successfully.')


-- ============================================================
-- SECTION 2: GET QBOX PLAYER DATA
-- ============================================================

local function GetCharacterData(source)
    local player = exports.qbx_core:GetPlayer(source)

    if not player then
        print(
            ('[reo_mail] Unable to find Qbox player for source %s.')
            :format(source)
        )

        return nil
    end

    if not player.PlayerData then
        print(
            ('[reo_mail] Qbox PlayerData missing for source %s.')
            :format(source)
        )

        return nil
    end

    return player.PlayerData
end


-- ============================================================
-- SECTION 3: GET CHARACTER ID
-- ============================================================

local function GetCharacterId(source)
    local playerData = GetCharacterData(source)

    if not playerData then
        return nil
    end

    if not playerData.citizenid then
        print(
            ('[reo_mail] Citizen ID missing for source %s.')
            :format(source)
        )

        return nil
    end

    return playerData.citizenid
end


-- ============================================================
-- SECTION 4: ENSURE PLAYER MAIL PROFILE
-- ============================================================

local function EnsurePlayerMailProfile(source)
    local characterId = GetCharacterId(source)

    if not characterId then
        return nil
    end

    local profile = REO_MAIL.Server.EnsureMailProfile(characterId)

    if not profile then
        print(
            ('[reo_mail] Failed to create/load postal profile for %s.')
            :format(characterId)
        )

        return nil
    end

    if Config.Debug then
        print(
            ('[reo_mail] Character %s resolved to PO Box %s.')
            :format(
                characterId,
                profile.po_box
            )
        )
    end

    return profile
end




-- ============================================================
-- SECTION 5: CASH PAYMENT HELPERS
-- Lost Mail Recovery is intentionally CASH ONLY.
-- ============================================================

local function GetCash(source)
    local playerData = GetCharacterData(source)
    if not playerData or not playerData.money then return 0 end
    return tonumber(playerData.money.cash) or 0
end

local function RemoveCash(source, amount, reason)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or not player.Functions then return false end
    return player.Functions.RemoveMoney('cash', amount, reason or 'reo-mail-recovery') == true
end

local function AddCash(source, amount, reason)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or not player.Functions then return false end
    return player.Functions.AddMoney('cash', amount, reason or 'reo-mail-recovery-refund') == true
end

REO_MAIL.Server.GetCash = GetCash
REO_MAIL.Server.RemoveCash = RemoveCash
REO_MAIL.Server.AddCash = AddCash

-- ============================================================
-- SECTION 5: MY PO BOX COMMAND
-- ============================================================

RegisterCommand('mypobox', function(source)
    if source == 0 then
        print(
            '[reo_mail] /mypobox must be used by an in-game player.'
        )

        return
    end

    local profile = EnsurePlayerMailProfile(source)

    if not profile then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'San Andreas Postal Service',
            description = 'Unable to retrieve your mailing address.',
            type = 'error'
        })

        return
    end

    TriggerClientEvent('ox_lib:notify', source, {
        title = 'San Andreas Postal Service',
        description = (
            'Your permanent mailing address is %s %s.'
        ):format(
            Config.POBox.Prefix,
            profile.po_box
        ),
        type = 'success'
    })
end, false)

-- ============================================================
-- SECTION 6: CHARACTER LOAD HANDLER
-- ============================================================

RegisterNetEvent('QBCore:Server:OnPlayerLoaded')

AddEventHandler('QBCore:Server:OnPlayerLoaded', function()
    local source = source

    if not source or source == 0 then
        return
    end

    local profile = EnsurePlayerMailProfile(source)

    if not profile then
        print(
            ('[reo_mail] Failed to initialize postal profile for source %s.')
            :format(source)
        )

        return
    end

    if Config.Debug then
        print(
            ('[reo_mail] Postal profile initialized for source %s with PO Box %s.')
            :format(
                source,
                profile.po_box
            )
        )
    end
end)

-- ============================================================
-- SECTION 4: EXPOSE CHARACTER ID FUNCTION
-- ============================================================

REO_MAIL.Server.GetCharacterId = GetCharacterId

-- ============================================================
-- SECTION 7: MY MAIL TEST COMMAND
-- ============================================================

RegisterCommand('mymailtest', function(source)
    if source == 0 then
        print(
            '[reo_mail] /mymailtest must be used by an in-game player.'
        )

        return
    end

    local characterId = GetCharacterId(source)

    if not characterId then
        print(
            ('[reo_mail] Unable to resolve character for source %s.')
            :format(source)
        )

        return
    end

    local mailItems = REO_MAIL.Server.GetCharacterMail(
        characterId
    )

    print(' ')
    print('============================================================')
    print(' REO DEVELOPMENT - CHARACTER MAIL TEST')
    print('============================================================')
    print((' Character ID: %s'):format(characterId))
    print((' Mail Found:   %s'):format(#mailItems))
    print('============================================================')

    for index, mail in ipairs(mailItems) do
        print(
            (' [%s] %s | %s | %s | %s')
            :format(
                index,
                mail.tracking_number,
                mail.sender_name,
                mail.subject or 'No Subject',
                mail.status
            )
        )
    end

    print('============================================================')
    print(' ')
end, false)

-- ============================================================
-- SECTION 10: CLAIM PHYSICAL MAIL
-- ============================================================

lib.callback.register('reo_mail:server:claimMail', function(source, mailId)
    if not mailId then
        return false, 'invalid_mail'
    end

    local characterId = GetCharacterId(source)

    if not characterId then
        return false, 'character_not_found'
    end

    -- ========================================================
    -- SECURITY CHECK
    -- Verify ownership and current claim state.
    -- ========================================================

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
        print(
            ('[reo_mail] Physical mail claim denied. Character: %s | Mail ID: %s')
            :format(
                characterId,
                tostring(mailId)
            )
        )

        return false, 'mail_not_found'
    end

    if mail.claimed_at then
        return false, 'already_claimed'
    end

    -- ========================================================
    -- CREATE PHYSICAL ITEM FIRST
    -- Do not mark claimed if ox_inventory fails.
    -- ========================================================

    local envelopeCreated =
        REO_MAIL.Server.CreatePhysicalEnvelope(
            source,
            mail.id
        )

    if not envelopeCreated then
        return false, 'inventory_failed'
    end

    -- ========================================================
    -- MARK MAIL AS CLAIMED
    -- ========================================================

    local updatedRows = MySQL.update.await([[
        UPDATE reo_mail_items
        SET claimed_at = CURRENT_TIMESTAMP
        WHERE id = ?
        AND recipient_character_id = ?
        AND claimed_at IS NULL
    ]], {
        mail.id,
        characterId
    })

    if not updatedRows or updatedRows < 1 then
        print(
            ('[reo_mail] WARNING: Envelope created but claim state failed for Mail ID %s.')
            :format(mail.id)
        )

        return false, 'claim_update_failed'
    end

    if Config.Debug then
        print(
            ('[reo_mail] Character %s claimed physical Mail ID %s.')
            :format(
                characterId,
                mail.id
            )
        )
    end

    return true
end)

-- ============================================================
-- SECTION 9: GET INDIVIDUAL MAIL ITEM
-- ============================================================

lib.callback.register('reo_mail:server:getMailItem', function(source, mailId)
    if not mailId then
        return nil
    end

    local characterId = GetCharacterId(source)

    if not characterId then
        print(
            ('[reo_mail] Unable to resolve character for mail request from source %s.')
            :format(source)
        )

        return nil
    end

    -- ========================================================
    -- SECURITY CHECK
    -- Mail ID AND recipient character must match.
    -- ========================================================

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
        print(
            ('[reo_mail] Mail access denied or mail not found. Source: %s | Character: %s | Mail ID: %s')
            :format(
                source,
                characterId,
                tostring(mailId)
            )
        )

        return nil
    end

    if Config.Debug then
        print(
            ('[reo_mail] Character %s opened mail ID %s.')
            :format(
                characterId,
                mail.id
            )
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
        createdAt = mail.created_at
    }
end)

-- ============================================================
-- SECTION 10: CLAIM PHYSICAL MAIL
-- ============================================================

lib.callback.register('reo_mail:server:claimMail', function(source, mailId)
    if not mailId then
        return false
    end

    local characterId = GetCharacterId(source)

    if not characterId then
        return false
    end

    -- ========================================================
    -- SECURITY CHECK
    -- Verify this mail belongs to this character.
    -- ========================================================

    local mail = MySQL.single.await([[
        SELECT id
        FROM reo_mail_items
        WHERE id = ?
        AND recipient_character_id = ?
        LIMIT 1
    ]], {
        mailId,
        characterId
    })

    if not mail then
        print(
            ('[reo_mail] Physical mail claim denied. Character: %s | Mail ID: %s')
            :format(
                characterId,
                tostring(mailId)
            )
        )

        return false
    end

    return REO_MAIL.Server.CreatePhysicalEnvelope(
        source,
        mail.id
    )
end)