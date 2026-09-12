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
            recipient_character_id, recipient_name, mail_type, letter_template,
            subject, body, status, destination_type, destination_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        tracking,
        data.senderType or REO_MAIL.SenderTypes.SYSTEM,
        data.senderId,
        data.senderName or (Config.PostalService and Config.PostalService.Name) or (Config.Postal and Config.Postal.defaultSender) or 'San Andreas Postal Service',
        data.recipientCharacterId,
        data.recipientName,
        data.mailType or REO_MAIL.Types.LETTER,
        data.letterTemplate or Config.DefaultMailTemplate or 'basic',
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

    local success, response = exports.ox_inventory:AddItem(source, 'reo_envelope_sealed', 1, metadata)
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
-- SECTION 9: PHYSICAL MAIL INTERACTIONS - PHASE 2
-- ============================================================

local function GetPhysicalMailRecord(mailId)
    return MySQL.single.await([[
        SELECT * FROM reo_mail_items WHERE id = ? LIMIT 1
    ]], { mailId })
end

local function BuildPhysicalMetadata(mail, itemType)
    local base = {
        mailId = mail.id,
        trackingNumber = mail.tracking_number,
        sender = mail.sender_name,
        recipient = mail.recipient_name,
        subject = mail.subject or 'No Subject'
    }

    if itemType == 'opened' then
        base.label = 'Opened Envelope'
        base.description = ('Opened Mail | From: %s | Tracking: %s'):format(
            mail.sender_name or 'Unknown Sender',
            mail.tracking_number or 'Unknown'
        )
    elseif itemType == 'letter' then
        base.label = 'Letter'
        base.description = ('Physical Letter | From: %s | Subject: %s'):format(
            mail.sender_name or 'Unknown Sender',
            mail.subject or 'No Subject'
        )
    end

    return base
end

-- ============================================================
-- SECTION 9A: OPEN SEALED ENVELOPE
-- Converts one sealed envelope into one opened envelope + letter.
-- Recipient validation occurs before the seal can be broken.
-- ============================================================

lib.callback.register('reo_mail:server:openSealedEnvelope', function(source, slotId)
    local slot = exports.ox_inventory:GetSlot(source, slotId)

    if not slot or slot.name ~= 'reo_envelope_sealed' then
        return nil, 'invalid_envelope'
    end

    local metadata = slot.metadata or {}
    local mailId = tonumber(metadata.mailId)
    if not mailId then return nil, 'invalid_envelope' end

    local characterId = REO_MAIL.Server.GetCharacterId(source)
    if not characterId then return nil, 'character_not_found' end

    local mail = MySQL.single.await('SELECT * FROM reo_mail_items WHERE id = ? LIMIT 1', { mailId })
    if not mail then return nil, 'mail_not_found' end

    local authorized = mail.recipient_character_id == characterId
    if not authorized and mail.recipient_business_id then
        authorized = REO_MAIL.Server.CanAccessBusinessMail and REO_MAIL.Server.CanAccessBusinessMail(source, mail.recipient_business_id) or false
    end
    if not authorized then return nil, 'mail_not_found' end

    local openedMetadata = BuildPhysicalMetadata(mail, 'opened')
    local letterMetadata = BuildPhysicalMetadata(mail, 'letter')

    -- Remove the exact sealed item first so the same envelope cannot be opened twice.
    local removed = exports.ox_inventory:RemoveItem(source, 'reo_envelope_sealed', 1, metadata, slotId)
    if not removed then return nil, 'remove_failed' end

    local openedAdded = exports.ox_inventory:AddItem(source, 'reo_envelope_opened', 1, openedMetadata)
    if not openedAdded then
        exports.ox_inventory:AddItem(source, 'reo_envelope_sealed', 1, metadata)
        return nil, 'inventory_full'
    end

    local letterAdded = exports.ox_inventory:AddItem(source, 'reo_envelope_letter', 1, letterMetadata)
    if not letterAdded then
        exports.ox_inventory:RemoveItem(source, 'reo_envelope_opened', 1, openedMetadata)
        exports.ox_inventory:AddItem(source, 'reo_envelope_sealed', 1, metadata)
        return nil, 'inventory_full'
    end

    return {
        mailId = mail.id,
        senderName = mail.sender_name or 'Unknown Sender',
        recipientName = mail.recipient_name or 'Unknown Recipient',
        subject = mail.subject or 'No Subject',
        trackingNumber = mail.tracking_number or 'Unknown'
    }
end)

-- ============================================================
-- SECTION 9B: INSPECT OPENED ENVELOPE
-- The envelope is now a physical keepsake and can be transferred.
-- ============================================================

lib.callback.register('reo_mail:server:inspectOpenedEnvelope', function(source, slotId)
    local slot = exports.ox_inventory:GetSlot(source, slotId)
    if not slot or slot.name ~= 'reo_envelope_opened' then
        return nil, 'invalid_envelope'
    end

    local mailId = tonumber((slot.metadata or {}).mailId)
    if not mailId then return nil, 'invalid_envelope' end

    local mail = GetPhysicalMailRecord(mailId)
    if not mail then return nil, 'mail_not_found' end

    return {
        mailId = mail.id,
        senderName = mail.sender_name or 'Unknown Sender',
        recipientName = mail.recipient_name or 'Unknown Recipient',
        subject = mail.subject or 'No Subject',
        trackingNumber = mail.tracking_number or 'Unknown',
        mailType = mail.mail_type or 'Standard',
        status = mail.status or 'Unknown',
        createdAt = mail.created_at
    }
end)

-- ============================================================
-- SECTION 9C: READ PHYSICAL LETTER
-- Possession of the physical letter grants read access, allowing
-- players to hand, store, seize, or otherwise roleplay with mail.
-- ============================================================

lib.callback.register('reo_mail:server:readPhysicalLetter', function(source, slotId)
    local slot = exports.ox_inventory:GetSlot(source, slotId)
    if not slot or slot.name ~= 'reo_envelope_letter' then
        return nil, 'invalid_letter'
    end

    local mailId = tonumber((slot.metadata or {}).mailId)
    if not mailId then return nil, 'invalid_letter' end

    local mail = GetPhysicalMailRecord(mailId)
    if not mail then return nil, 'mail_not_found' end

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



-- ============================================================
-- SECTION 10: LOST MAIL RECOVERY
-- Unlimited replacement copies. Each copy costs CASH only.
-- ============================================================

lib.callback.register('reo_mail:server:getRecoverableMail', function(source)
    if not Config.MailRecovery or not Config.MailRecovery.enabled then return {} end
    local characterId = REO_MAIL.Server.GetCharacterId(source)
    if not characterId then return {} end

    local rows = MySQL.query.await([[
        SELECT id, sender_name, subject, tracking_number, COALESCE(reissue_count, 0) AS reissue_count
        FROM reo_mail_items
        WHERE recipient_character_id = ? AND claimed_at IS NOT NULL
        ORDER BY created_at DESC
        LIMIT 50
    ]], { characterId }) or {}

    local result = {}
    for i = 1, #rows do
        result[#result + 1] = {
            id = rows[i].id,
            senderName = rows[i].sender_name,
            subject = rows[i].subject,
            trackingNumber = rows[i].tracking_number,
            reissueCount = rows[i].reissue_count
        }
    end
    return result
end)

lib.callback.register('reo_mail:server:recoverMail', function(source, mailId)
    if not Config.MailRecovery or not Config.MailRecovery.enabled then return false, 'disabled' end

    local characterId = REO_MAIL.Server.GetCharacterId(source)
    if not characterId then return false, 'character_not_found' end

    local mail = MySQL.single.await([[
        SELECT * FROM reo_mail_items
        WHERE id = ? AND recipient_character_id = ? AND claimed_at IS NOT NULL
        LIMIT 1
    ]], { tonumber(mailId), characterId })
    if not mail then return false, 'mail_not_found' end

    local cost = tonumber(Config.MailRecovery.reissueCost) or 150

    -- Check inventory BEFORE taking payment.
    if not exports.ox_inventory:CanCarryItem(source, 'reo_envelope_sealed', 1) then
        return false, 'inventory_failed'
    end

    -- Recovery is CASH ONLY.
    local cash = REO_MAIL.Server.GetCash and REO_MAIL.Server.GetCash(source) or 0
    if cash < cost then
        return false, 'not_enough_cash'
    end

    if not REO_MAIL.Server.RemoveCash or not REO_MAIL.Server.RemoveCash(source, cost, 'reo-mail-recovery') then
        return false, 'payment_failed'
    end

    local created = REO_MAIL.Server.CreatePhysicalEnvelope(source, mail.id)
    if not created then
        -- Never charge the player if the replacement cannot be issued.
        if REO_MAIL.Server.AddCash then
            REO_MAIL.Server.AddCash(source, cost, 'reo-mail-recovery-refund')
        end
        return false, 'inventory_failed'
    end

    -- Tracking only; there is intentionally NO reissue limit.
    MySQL.update.await([[
        UPDATE reo_mail_items
        SET reissue_count = COALESCE(reissue_count, 0) + 1
        WHERE id = ? AND recipient_character_id = ?
    ]], { mail.id, characterId })

    return true, nil, cost
end)


-- ============================================================
-- SECTION 11: RECIPIENT DIRECTORY + COMPOSE TEMPLATES v0.4.0
-- Qbox `players` is authoritative for persistent character search.
-- ============================================================

local function ComposeCharacterId(source)
    return REO_MAIL.Server.GetCharacterId and REO_MAIL.Server.GetCharacterId(source) or nil
end

local function ComposeDisplayName(source)
    return REO_MAIL.Server.GetCharacterDisplayName and REO_MAIL.Server.GetCharacterDisplayName(source) or nil
end

-- Package identity helper. Character ID remains primary; the permanent PO Box
-- is a safe fallback for recipient delivery records created before this fix.
local function PackageIdentity(source)
    local cid = ComposeCharacterId(source)
    if not cid then return nil, nil end
    local profile = EnsureMailProfile(cid)
    return cid, profile and tostring(profile.po_box) or nil
end

local function GetAllowedComposeTemplates(source)
    local allowed = {}
    for templateId, template in pairs(Config.MailTemplates or {}) do
        if template.access == 'public' or not template.access then
            allowed[#allowed + 1] = { id = templateId, label = template.label or templateId, description = template.description or '' }
        end
    end
    table.sort(allowed, function(a,b) return a.label < b.label end)
    return allowed
end

local function IsComposeTemplateAllowed(source, templateId)
    local template = Config.MailTemplates and Config.MailTemplates[templateId]
    return template and (template.access == 'public' or not template.access) or false
end

local function OnlineCharacterMap()
    local map = {}
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local cid = ComposeCharacterId(src)
        if cid then map[cid] = true end
    end
    return map
end

local function EnsureRecipientProfile(characterId, displayName)
    -- Qbox players.charinfo is the authoritative source for character names.
    -- reo_mail_profiles intentionally stores postal routing data only.
    -- Do not attempt to cache/update display_name here because existing
    -- REO Mail installations do not require that column.
    return REO_MAIL.Server.EnsureMailProfile(characterId)
end

local function DecodeQboxCharacterName(charinfo)
    if type(charinfo) == 'table' then
        local first = tostring(charinfo.firstname or '')
        local last = tostring(charinfo.lastname or '')
        return (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    end

    if type(charinfo) ~= 'string' or charinfo == '' then return nil end

    local ok, decoded = pcall(json.decode, charinfo)
    if not ok or type(decoded) ~= 'table' then return nil end

    local first = tostring(decoded.firstname or '')
    local last = tostring(decoded.lastname or '')
    local name = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    return name ~= '' and name or nil
end

local function SearchQboxCharacters(source, query)
    if not Config.RecipientDirectory or not Config.RecipientDirectory.enabled then return {} end

    query = type(query) == 'string' and query:gsub('^%s+', ''):gsub('%s+$', '') or ''
    local minLength = tonumber(Config.RecipientDirectory.minimumSearchLength) or 1
    if #query < minLength then return {} end

    local senderCid = ComposeCharacterId(source) or ''
    local maxResults = math.min(tonumber(Config.RecipientDirectory.maxResults) or 12, 30)
    local likeQuery = '%' .. query .. '%'

    -- v0.4.7: Query the exact Qbox structure confirmed on this server.
    -- Character names live in players.charinfo JSON under firstname/lastname.
    -- LEFT JOIN the REO Mail profile so an existing state PO Box is returned
    -- immediately without relying on a second directory/name cache.
    local rows = MySQL.query.await([[
        SELECT
            p.citizenid,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) AS firstname,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) AS lastname,
            rmp.po_box
        FROM players p
        LEFT JOIN reo_mail_profiles rmp
            ON rmp.character_id = p.citizenid
        WHERE p.citizenid <> ?
          AND (
                CONCAT(
                    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ''),
                    ' ',
                    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')), '')
                ) LIKE ?
                OR COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), '') LIKE ?
                OR COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')), '') LIKE ?
          )
        ORDER BY
            CASE
                WHEN LOWER(CONCAT(
                    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ''),
                    ' ',
                    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')), '')
                )) = LOWER(?) THEN 0
                WHEN LOWER(CONCAT(
                    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ''),
                    ' ',
                    COALESCE(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')), '')
                )) LIKE LOWER(CONCAT(?, '%')) THEN 1
                ELSE 2
            END,
            firstname ASC,
            lastname ASC
        LIMIT ?
    ]], {
        senderCid,
        likeQuery,
        likeQuery,
        likeQuery,
        query,
        query,
        maxResults
    }) or {}

    local online = OnlineCharacterMap()
    local results = {}

    for _, row in ipairs(rows) do
        local citizenId = row.citizenid
        local first = tostring(row.firstname or '')
        local last = tostring(row.lastname or '')
        local displayName = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')

        if citizenId and displayName ~= '' then
            local poBox = tonumber(row.po_box)

            -- Characters without a postal profile are automatically assigned
            -- their permanent state PO Box the first time the directory finds them.
            if not poBox then
                local profile = EnsureRecipientProfile(citizenId, displayName)
                poBox = profile and tonumber(profile.po_box) or nil
            end

            if poBox then
                results[#results + 1] = {
                    characterId = citizenId,
                    name = displayName,
                    online = online[citizenId] == true,
                    poBox = poBox,
                    postalLabel = ('PO Box %s'):format(poBox)
                }
            end
        end
    end

    return results
end

local function GetBusinessConfig(businessId)
    local business = Config.Businesses and Config.Businesses[businessId]
    if not business or business.enabled == false then return nil end
    return business
end

local function CanAccessBusiness(source, businessId)
    local business = GetBusinessConfig(businessId)
    if not business then return false end
    local job = REO_MAIL.Server.GetCharacterJobName and REO_MAIL.Server.GetCharacterJobName(source)
    return job ~= nil and job == business.job
end

lib.callback.register('reo_mail:server:getComposeTemplates', function(source)
    return GetAllowedComposeTemplates(source)
end)

lib.callback.register('reo_mail:server:getOnlineRecipients', function(source)
    local senderCid = ComposeCharacterId(source)
    local results = {}
    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        local cid = ComposeCharacterId(target)
        if cid and cid ~= senderCid then
            results[#results+1] = { characterId = cid, name = ComposeDisplayName(target) or 'Unknown Character', online = true }
        end
    end
    table.sort(results, function(a,b) return a.name < b.name end)
    return results
end)

lib.callback.register('reo_mail:server:searchRecipients', function(source, query)
    local results = SearchQboxCharacters(source, query)
    if #results > 0 then return results end

    -- v0.5.1 compatibility: if a full-name search has a small typo in one
    -- name (for example "Millie Habbie" vs "Mille Habbie"), retry the
    -- directory using each meaningful name token. This keeps the exact
    -- v0.4.9 Qbox directory query as the primary search while making package
    -- addressing less fragile.
    if type(query) == 'string' then
        local seen = {}
        for token in query:gmatch('%S+') do
            if #token >= 2 then
                local tokenResults = SearchQboxCharacters(source, token)
                for _, recipient in ipairs(tokenResults) do
                    if recipient.characterId and not seen[recipient.characterId] then
                        seen[recipient.characterId] = true
                        results[#results + 1] = recipient
                    end
                end
            end
        end
    end

    return results
end)

lib.callback.register('reo_mail:server:getBusinesses', function(source)
    local results = {}
    for id, business in pairs(Config.Businesses or {}) do
        if business.enabled ~= false then
            results[#results+1] = { id = id, name = business.label or id }
        end
    end
    table.sort(results, function(a,b) return a.name < b.name end)
    return results
end)

lib.callback.register('reo_mail:server:sendPlayerLetter', function(source, data)
    if source == 0 or type(data) ~= 'table' then return {success=false, reason='invalid_content'} end
    local senderCid = ComposeCharacterId(source)
    if not senderCid then return {success=false, reason='character_unavailable'} end
    local recipientCid = type(data.recipientCharacterId)=='string' and data.recipientCharacterId or nil
    local templateId = type(data.templateId)=='string' and data.templateId or (Config.DefaultMailTemplate or 'basic')
    local subject = type(data.subject)=='string' and data.subject:gsub('^%s+',''):gsub('%s+$','') or ''
    local body = type(data.body)=='string' and data.body:gsub('^%s+',''):gsub('%s+$','') or ''
    if not recipientCid or subject=='' or body=='' or #subject>100 or #body>4000 then return {success=false, reason='invalid_content'} end
    if not IsComposeTemplateAllowed(source, templateId) then return {success=false, reason='invalid_template'} end
    if recipientCid == senderCid then return {success=false, reason='self_mail'} end

    local row = MySQL.single.await('SELECT citizenid, charinfo FROM players WHERE citizenid = ? LIMIT 1', { recipientCid })
    if not row then return {success=false, reason='invalid_recipient'} end
    local recipientName = DecodeQboxCharacterName(row.charinfo)
    if not recipientName then return {success=false, reason='invalid_recipient'} end
    if not EnsureRecipientProfile(row.citizenid, recipientName) then return {success=false, reason='creation_failed'} end

    local result = REO_MAIL.Server.CreateMail({
        recipientCharacterId=row.citizenid, recipientName=recipientName,
        senderType=REO_MAIL.SenderTypes.CHARACTER, senderId=senderCid,
        senderName=ComposeDisplayName(source) or senderCid,
        mailType=REO_MAIL.Types.LETTER, letterTemplate=templateId, subject=subject, body=body
    })
    if not result then return {success=false, reason='creation_failed'} end
    MySQL.update.await('UPDATE reo_mail_items SET status = ?, delivered_at = CURRENT_TIMESTAMP WHERE id = ?', {REO_MAIL.Status.DELIVERED, result.id})
    return {success=true, mailId=result.id, trackingNumber=result.trackingNumber, recipientName=recipientName, templateId=templateId}
end)

lib.callback.register('reo_mail:server:sendBusinessLetter', function(source, data)
    if source == 0 or type(data) ~= 'table' then return {success=false, reason='invalid_content'} end
    local senderCid = ComposeCharacterId(source)
    if not senderCid then return {success=false, reason='character_unavailable'} end
    local businessId = type(data.businessId)=='string' and data.businessId or nil
    local business = businessId and GetBusinessConfig(businessId) or nil
    if not business then return {success=false, reason='invalid_recipient'} end
    local templateId = type(data.templateId)=='string' and data.templateId or (Config.DefaultMailTemplate or 'basic')
    local subject = type(data.subject)=='string' and data.subject:gsub('^%s+',''):gsub('%s+$','') or ''
    local body = type(data.body)=='string' and data.body:gsub('^%s+',''):gsub('%s+$','') or ''
    if subject=='' or body=='' or #subject>100 or #body>4000 then return {success=false, reason='invalid_content'} end
    if not IsComposeTemplateAllowed(source, templateId) then return {success=false, reason='invalid_template'} end

    local tracking = GenerateTrackingNumber()
    local insertId = MySQL.insert.await([[
        INSERT INTO reo_mail_items (
          tracking_number, sender_type, sender_id, sender_name,
          recipient_character_id, recipient_business_id, recipient_name,
          mail_type, letter_template, subject, body, status, destination_type, destination_id, delivered_at
        ) VALUES (?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, 'business', ?, CURRENT_TIMESTAMP)
    ]], {tracking, REO_MAIL.SenderTypes.CHARACTER, senderCid, ComposeDisplayName(source) or senderCid,
          businessId, business.label or businessId, REO_MAIL.Types.LETTER, templateId, subject, body,
          REO_MAIL.Status.DELIVERED, businessId})
    if not insertId then return {success=false, reason='creation_failed'} end
    return {success=true, mailId=insertId, trackingNumber=tracking, recipientName=business.label or businessId, templateId=templateId}
end)

lib.callback.register('reo_mail:server:getBusinessMail', function(source, businessId)
    if not CanAccessBusiness(source, businessId) then return nil, 'unauthorized' end
    return MySQL.query.await([[
        SELECT id, sender_name, subject, tracking_number, status, created_at, claimed_at
        FROM reo_mail_items WHERE recipient_business_id = ?
        ORDER BY created_at DESC, id DESC LIMIT 75
    ]], {businessId}) or {}
end)

lib.callback.register('reo_mail:server:claimBusinessMail', function(source, businessId, mailId)
    if not CanAccessBusiness(source, businessId) then return false, 'unauthorized' end
    local mail = MySQL.single.await('SELECT * FROM reo_mail_items WHERE id = ? AND recipient_business_id = ? LIMIT 1', {tonumber(mailId), businessId})
    if not mail then return false, 'mail_not_found' end
    if mail.claimed_at then return false, 'already_claimed' end
    if not exports.ox_inventory:CanCarryItem(source, 'reo_envelope_sealed', 1) then return false, 'inventory_failed' end
    if not REO_MAIL.Server.CreatePhysicalEnvelope(source, mail.id) then return false, 'inventory_failed' end
    local updated = MySQL.update.await('UPDATE reo_mail_items SET claimed_at = CURRENT_TIMESTAMP WHERE id = ? AND recipient_business_id = ? AND claimed_at IS NULL', {mail.id, businessId})
    if not updated or updated < 1 then return false, 'claim_update_failed' end
    return true
end)

-- Business authorization helper used by physical envelope opening.
REO_MAIL.Server.CanAccessBusinessMail = function(source, businessId)
    return CanAccessBusiness(source, businessId)
end

-- ============================================================
-- SECTION 14: PACKAGE SYSTEM v0.5.0
-- Open box -> pack ox_inventory stash -> seal/address/pay -> drop off -> pickup.
-- ============================================================

local function PackageConfigForItem(itemName)
    for sizeId, cfg in pairs((Config.Packages and Config.Packages.sizes) or {}) do
        if cfg.item == itemName then return sizeId, cfg end
    end
end

local function PackageTracking()
    return ('REO-PKG-%s-%06d'):format(os.time(), math.random(0, 999999))
end

local function PackagePrice(sizeId, serviceId, anonymous, signature)
    local service = Config.Packages.services[serviceId]
    if not service or not service.prices or not service.prices[sizeId] then return nil end
    local base = tonumber(service.prices[sizeId]) or 0
    local anonymousFee = anonymous and (Config.Packages.addons.anonymous.fee or 0) or 0
    local signatureFee = signature and (Config.Packages.addons.signature.fee or 0) or 0
    return base + anonymousFee + signatureFee, base, anonymousFee, signatureFee
end

local function RegisterPackageStash(row)
    local cfg = Config.Packages and Config.Packages.sizes and Config.Packages.sizes[row.box_size]
    if not cfg then return false end
    exports.ox_inventory:RegisterStash(row.stash_id, ('REO Mail - %s'):format(cfg.label), cfg.slots, cfg.maxWeight, false)
    return true
end

local function PackageRowByUuid(uuid)
    return MySQL.single.await('SELECT * FROM reo_mail_packages WHERE package_uuid = ? LIMIT 1', { uuid })
end

local function ResolvePackageFromSlot(source, slotId)
    local slot = exports.ox_inventory:GetSlot(source, tonumber(slotId))
    if not slot then return nil, nil, 'box_not_found' end
    local sizeId = PackageConfigForItem(slot.name)
    if not sizeId then return nil, nil, 'not_shipping_box' end
    return slot, sizeId
end

local function ValidateScheduledFor(value)
    if not value or value == '' then return nil end
    local row = MySQL.single.await([[
        SELECT DATE_FORMAT(STR_TO_DATE(?, '%Y-%m-%d %H:%i'), '%Y-%m-%d %H:%i:%s') AS scheduled,
               TIMESTAMPDIFF(SECOND, CURRENT_TIMESTAMP, STR_TO_DATE(?, '%Y-%m-%d %H:%i')) AS seconds_ahead
    ]], { value, value })
    if not row or not row.scheduled or not row.seconds_ahead or tonumber(row.seconds_ahead) < 60 then return false end
    return row.scheduled
end

lib.callback.register('reo_mail:server:preparePackageBox', function(source, slotId)
    if not Config.Packages or not Config.Packages.enabled then return {success=false, reason='disabled'} end
    local slot, sizeId, reason = ResolvePackageFromSlot(source, slotId)
    if not slot then return {success=false, reason=reason} end
    local metadata = slot.metadata or {}
    local row = metadata.packageUuid and PackageRowByUuid(metadata.packageUuid) or nil

    if not row then
        local cid = ComposeCharacterId(source)
        if not cid then return {success=false, reason='character_unavailable'} end
        local uuid = ('PKG-%s-%s-%04d'):format(cid, os.time(), math.random(0,9999))
        local stashId = 'reo_pkg_' .. uuid:gsub('[^%w_%-]', '')
        local id = MySQL.insert.await([[
            INSERT INTO reo_mail_packages (package_uuid, stash_id, box_size, sender_character_id, sender_name, status)
            VALUES (?, ?, ?, ?, ?, 'packing')
        ]], {uuid, stashId, sizeId, cid, ComposeDisplayName(source) or cid})
        if not id then return {success=false, reason='creation_failed'} end
        metadata.packageUuid = uuid
        metadata.packageId = id
        metadata.boxSize = sizeId
        metadata.packageStatus = 'packing'
        metadata.label = Config.Packages.sizes[sizeId].label
        metadata.description = 'Open box - add items - seal when ready.'
        exports.ox_inventory:SetMetadata(source, tonumber(slotId), metadata)
        row = PackageRowByUuid(uuid)
    end

    RegisterPackageStash(row)
    return {success=true, package=row, stashId=row.stash_id, sealed=row.status ~= 'packing'}
end)

local function SealPackage(source, data, recipient)
    if type(data) ~= 'table' then return {success=false, reason='invalid_request'} end
    local slot, _, reason = ResolvePackageFromSlot(source, data.slotId)
    if not slot then return {success=false, reason=reason} end
    local metadata = slot.metadata or {}
    local row = metadata.packageUuid and PackageRowByUuid(metadata.packageUuid) or nil
    if not row or row.status ~= 'packing' or row.sender_character_id ~= ComposeCharacterId(source) then
        return {success=false, reason='invalid_package'}
    end

    local serviceId = type(data.serviceId) == 'string' and data.serviceId or nil
    local service = serviceId and Config.Packages.services[serviceId]
    if not service then return {success=false, reason='invalid_service'} end

    local anonymous = data.anonymous == true
    local signature = data.signature == true
    local scheduledFor = ValidateScheduledFor(data.scheduledFor)
    if data.scheduledFor and data.scheduledFor ~= '' and scheduledFor == false then
        return {success=false, reason='invalid_schedule'}
    end

    local cost, baseCost, anonymousFee, signatureFee = PackagePrice(row.box_size, serviceId, anonymous, signature)
    if not cost then return {success=false, reason='invalid_service'} end
    local cash = REO_MAIL.Server.GetCash and REO_MAIL.Server.GetCash(source) or 0
    if cash < cost then return {success=false, reason='not_enough_cash', cost=cost} end
    if not REO_MAIL.Server.RemoveCash or not REO_MAIL.Server.RemoveCash(source, cost, 'reo-mail-package-postage') then
        return {success=false, reason='payment_failed'}
    end

    local tracking = PackageTracking()
    local updated = MySQL.update.await([[
        UPDATE reo_mail_packages
        SET tracking_number=?, recipient_character_id=?, recipient_business_id=?, recipient_name=?,
            destination_type=?, destination_id=?, shipping_service=?, shipping_cost=?,
            anonymous_sender=?, signature_required=?, scheduled_delivery_at=?,
            status='sealed', sealed_at=CURRENT_TIMESTAMP
        WHERE id=? AND status='packing'
    ]], {
        tracking, recipient.characterId, recipient.businessId, recipient.name,
        recipient.destinationType, recipient.destinationId, serviceId, cost,
        anonymous and 1 or 0, signature and 1 or 0, scheduledFor, row.id
    })

    if not updated or updated < 1 then
        if REO_MAIL.Server.AddCash then REO_MAIL.Server.AddCash(source, cost, 'reo-mail-package-postage-refund') end
        return {success=false, reason='seal_failed'}
    end

    metadata.packageStatus = 'sealed'
    metadata.trackingNumber = tracking
    metadata.recipient = recipient.name
    metadata.shippingService = service.label
    metadata.shippingCost = cost
    metadata.anonymousSender = anonymous
    metadata.signatureRequired = signature
    metadata.scheduledFor = scheduledFor
    metadata.label = ('Sealed %s'):format(Config.Packages.sizes[row.box_size].label)
    metadata.description = ('To: %s | %s | Tracking: %s'):format(recipient.name, service.label, tracking)
    exports.ox_inventory:SetMetadata(source, tonumber(data.slotId), metadata)

    return {
        success=true, trackingNumber=tracking, recipientName=recipient.name, cost=cost,
        baseCost=baseCost, anonymousFee=anonymousFee, signatureFee=signatureFee,
        service=service.label, anonymous=anonymous, signature=signature, scheduledFor=scheduledFor
    }
end

lib.callback.register('reo_mail:server:sealPlayerPackage', function(source, data)
    local recipientCid = type(data)=='table' and type(data.recipientCharacterId)=='string' and data.recipientCharacterId or nil
    if not recipientCid or recipientCid == ComposeCharacterId(source) then return {success=false, reason='invalid_recipient'} end
    local playerRow = MySQL.single.await('SELECT citizenid, charinfo FROM players WHERE citizenid = ? LIMIT 1', {recipientCid})
    if not playerRow then return {success=false, reason='invalid_recipient'} end
    local recipientName = DecodeQboxCharacterName(playerRow.charinfo)
    local profile = EnsureRecipientProfile(playerRow.citizenid, recipientName)
    if not profile then return {success=false, reason='invalid_recipient'} end
    return SealPackage(source, data, {
        characterId=playerRow.citizenid, businessId=nil, name=recipientName,
        destinationType='po_box', destinationId=tostring(profile.po_box)
    })
end)

lib.callback.register('reo_mail:server:sealBusinessPackage', function(source, data)
    local businessId = type(data)=='table' and type(data.businessId)=='string' and data.businessId or nil
    local business = businessId and GetBusinessConfig(businessId) or nil
    if not business then return {success=false, reason='invalid_recipient'} end
    if data.signature == true then return {success=false, reason='signature_business_unsupported'} end
    return SealPackage(source, data, {
        characterId=nil, businessId=businessId, name=business.label or businessId,
        destinationType='business', destinationId=businessId
    })
end)

lib.callback.register('reo_mail:server:dropOffPackage', function(source, slotId)
    local slot, _, reason = ResolvePackageFromSlot(source, slotId)
    if not slot then return {success=false,reason=reason} end
    local metadata = slot.metadata or {}
    local row = metadata.packageUuid and PackageRowByUuid(metadata.packageUuid) or nil
    if not row or row.status ~= 'sealed' or row.sender_character_id ~= ComposeCharacterId(source) then
        return {success=false,reason='not_ready'}
    end
    local service = Config.Packages.services[row.shipping_service]
    if not service then return {success=false,reason='invalid_service'} end

    local removed = exports.ox_inventory:RemoveItem(source, slot.name, 1, metadata, tonumber(slotId))
    if not removed then return {success=false,reason='remove_failed'} end

    MySQL.update.await([[
        UPDATE reo_mail_packages
        SET status='in_transit', dropped_off_at=CURRENT_TIMESTAMP,
            delivery_due_at=CASE
                WHEN scheduled_delivery_at IS NOT NULL AND scheduled_delivery_at > CURRENT_TIMESTAMP THEN scheduled_delivery_at
                ELSE TIMESTAMPADD(MINUTE, ?, CURRENT_TIMESTAMP)
            END
        WHERE id=?
    ]], {service.minutes,row.id})

    local updated = PackageRowByUuid(row.package_uuid)
    return {success=true,trackingNumber=row.tracking_number,minutes=service.minutes,deliveryDueAt=updated and updated.delivery_due_at}
end)

local function RefreshPackageDeliveries()
    -- Normal packages become ready for GoPostal pickup. Signature packages wait for the recipient to be online.
    MySQL.update.await([[
        UPDATE reo_mail_packages
        SET status = CASE WHEN signature_required=1 THEN 'awaiting_signature' ELSE 'ready' END,
            delivered_at = CURRENT_TIMESTAMP
        WHERE status='in_transit' AND delivery_due_at IS NOT NULL AND delivery_due_at<=CURRENT_TIMESTAMP
    ]])
    -- Refused packages return to the sender after the configured return transit.
    MySQL.update.await([[
        UPDATE reo_mail_packages
        SET status='returned_ready', returned_at=CURRENT_TIMESTAMP
        WHERE status='returning' AND return_due_at IS NOT NULL AND return_due_at<=CURRENT_TIMESTAMP
    ]])
end

lib.callback.register('reo_mail:server:getReadyPackages', function(source)
    RefreshPackageDeliveries()
    local cid, poBox=PackageIdentity(source); if not cid then return {} end
    return MySQL.query.await([[
        SELECT *,
            CASE WHEN status='returned_ready' AND sender_character_id=? THEN 'return' ELSE 'recipient' END AS pickup_role
        FROM reo_mail_packages
        WHERE ((recipient_character_id=? OR (destination_type='po_box' AND destination_id=?)) AND status='ready')
           OR (sender_character_id=? AND status='returned_ready')
        ORDER BY COALESCE(returned_at, delivered_at) ASC, id ASC
    ]],{cid,cid,poBox or '',cid}) or {}
end)

lib.callback.register('reo_mail:server:pickupPackage', function(source, packageId)
    RefreshPackageDeliveries()
    local cid, poBox=PackageIdentity(source); if not cid then return {success=false,reason='character_unavailable'} end
    local row=MySQL.single.await([[
        SELECT * FROM reo_mail_packages
        WHERE id=? AND (
            ((recipient_character_id=? OR (destination_type='po_box' AND destination_id=?)) AND status='ready')
            OR (sender_character_id=? AND status='returned_ready')
        ) LIMIT 1
    ]],{tonumber(packageId),cid,poBox or '',cid})
    if not row then return {success=false,reason='not_ready'} end

    local cfg=Config.Packages.sizes[row.box_size]; if not cfg then return {success=false,reason='invalid_package'} end
    local isReturn = row.status == 'returned_ready'
    local metadata={
        packageUuid=row.package_uuid,packageId=row.id,boxSize=row.box_size,
        packageStatus='picked_up',trackingNumber=row.tracking_number,
        recipient=row.recipient_name,shippingService=row.shipping_service,
        label=((isReturn and 'Returned ' or 'Delivered ')..cfg.label),
        description=('Tracking: %s | Open to retrieve contents.'):format(row.tracking_number)
    }
    if not exports.ox_inventory:CanCarryItem(source,cfg.item,1,metadata) then return {success=false,reason='inventory_failed'} end
    local ok=exports.ox_inventory:AddItem(source,cfg.item,1,metadata); if not ok then return {success=false,reason='inventory_failed'} end

    MySQL.update.await([[
        UPDATE reo_mail_packages
        SET status='picked_up', picked_up_at=CURRENT_TIMESTAMP
        WHERE id=? AND status IN ('ready','returned_ready')
    ]],{row.id})
    return {success=true,trackingNumber=row.tracking_number,returned=isReturn}
end)

lib.callback.register('reo_mail:server:openDeliveredPackage', function(source, slotId)
    local slot,_,reason=ResolvePackageFromSlot(source,slotId); if not slot then return {success=false,reason=reason} end
    local metadata=slot.metadata or {}; local row=metadata.packageUuid and PackageRowByUuid(metadata.packageUuid) or nil
    local cid, poBox=PackageIdentity(source)
    local recipientMatch = row and (row.recipient_character_id==cid or (row.destination_type=='po_box' and tostring(row.destination_id or '')==tostring(poBox or '')))
    if not row or row.status~='picked_up' or (not recipientMatch and row.sender_character_id~=cid) then
        return {success=false,reason='unauthorized'}
    end
    RegisterPackageStash(row)
    return {success=true,stashId=row.stash_id}
end)

lib.callback.register('reo_mail:server:getMyPackageTracking', function(source)
    RefreshPackageDeliveries()
    local cid=ComposeCharacterId(source); if not cid then return {} end
    return MySQL.query.await([[
        SELECT id, tracking_number, recipient_name, box_size, shipping_service, shipping_cost, status,
               anonymous_sender, signature_required, scheduled_delivery_at, delivery_due_at, dropped_off_at,
               delivered_at, returned_at,
               GREATEST(0, TIMESTAMPDIFF(SECOND, CURRENT_TIMESTAMP, delivery_due_at)) AS seconds_remaining
        FROM reo_mail_packages
        WHERE (sender_character_id=? OR package_uuid LIKE CONCAT('PKG-', ?, '-%'))
          AND tracking_number IS NOT NULL
        ORDER BY id DESC LIMIT 50
    ]], {cid,cid}) or {}
end)

lib.callback.register('reo_mail:server:getPackageNotifications', function(source)
    RefreshPackageDeliveries()
    local cid, poBox=PackageIdentity(source); if not cid then return {} end
    local rows=MySQL.query.await([[
        SELECT id, tracking_number, sender_name, anonymous_sender, status
        FROM reo_mail_packages
        WHERE (
            (recipient_character_id=? OR (destination_type='po_box' AND destination_id=?)) AND status='ready' AND recipient_notified=0
        ) OR (
            sender_character_id=? AND status='returned_ready' AND sender_notified=0
        )
    ]],{cid,poBox or '',cid}) or {}
    for _,row in ipairs(rows) do
        if row.status=='ready' then
            MySQL.update.await('UPDATE reo_mail_packages SET recipient_notified=1 WHERE id=?',{row.id})
        else
            MySQL.update.await('UPDATE reo_mail_packages SET sender_notified=1 WHERE id=?',{row.id})
        end
    end
    return rows
end)

lib.callback.register('reo_mail:server:getPendingSignaturePackage', function(source)
    RefreshPackageDeliveries()
    local cid, poBox=PackageIdentity(source); if not cid then return nil end
    return MySQL.single.await([[
        SELECT id, tracking_number, sender_name, anonymous_sender, recipient_name, box_size, shipping_service
        FROM reo_mail_packages
        WHERE (recipient_character_id=? OR (destination_type='po_box' AND destination_id=?))
          AND status='awaiting_signature'
        ORDER BY delivery_due_at ASC, id ASC LIMIT 1
    ]],{cid,poBox or ''})
end)

local function GiveSignaturePackage(source, row)
    local cfg=Config.Packages.sizes[row.box_size]; if not cfg then return {success=false,reason='invalid_package'} end
    local metadata={
        packageUuid=row.package_uuid,packageId=row.id,boxSize=row.box_size,packageStatus='picked_up',
        trackingNumber=row.tracking_number,recipient=row.recipient_name,shippingService=row.shipping_service,
        label=('Delivered %s'):format(cfg.label),
        description=('Signature delivery | Tracking: %s'):format(row.tracking_number)
    }
    if not exports.ox_inventory:CanCarryItem(source,cfg.item,1,metadata) then return {success=false,reason='inventory_failed'} end
    local ok=exports.ox_inventory:AddItem(source,cfg.item,1,metadata); if not ok then return {success=false,reason='inventory_failed'} end
    return {success=true}
end

lib.callback.register('reo_mail:server:respondSignatureDelivery', function(source, packageId, accepted)
    local cid, poBox=PackageIdentity(source); if not cid then return {success=false,reason='character_unavailable'} end
    local row=MySQL.single.await([[
        SELECT * FROM reo_mail_packages
        WHERE id=? AND (recipient_character_id=? OR (destination_type='po_box' AND destination_id=?))
          AND status='awaiting_signature' LIMIT 1
    ]],{tonumber(packageId),cid,poBox or ''})
    if not row then return {success=false,reason='not_available'} end

    if accepted == true then
        local result=GiveSignaturePackage(source,row)
        if not result.success then return result end
        MySQL.update.await([[
            UPDATE reo_mail_packages SET status='picked_up', signature_signed_at=CURRENT_TIMESTAMP,
                signature_signed_by=?, picked_up_at=CURRENT_TIMESTAMP WHERE id=? AND status='awaiting_signature'
        ]],{(REO_MAIL.Server.GetCharacterDisplayName and REO_MAIL.Server.GetCharacterDisplayName(source)) or 'Recipient', row.id})
        return {success=true,accepted=true,trackingNumber=row.tracking_number}
    end

    local returnMinutes=tonumber(Config.Packages.returnMinutes) or 30
    MySQL.update.await([[
        UPDATE reo_mail_packages SET status='returning', refused_at=CURRENT_TIMESTAMP,
            return_due_at=TIMESTAMPADD(MINUTE, ?, CURRENT_TIMESTAMP)
        WHERE id=? AND status='awaiting_signature'
    ]],{returnMinutes,row.id})
    return {success=true,accepted=false,trackingNumber=row.tracking_number,returnMinutes=returnMinutes}
end)

RegisterCommand('reopackagedrop',function(source)
    if source==0 or not Config.Development or not Config.Development.enabled then return end
    TriggerClientEvent('reo_mail:client:packageDropMenu',source)
end,false)

RegisterCommand('reopackagepickup',function(source)
    if source==0 or not Config.Development or not Config.Development.enabled then return end
    TriggerClientEvent('reo_mail:client:packagePickupMenu',source)
end,false)

RegisterCommand('reopackagetrack',function(source)
    if source==0 then return end
    TriggerClientEvent('reo_mail:client:packageTrackingMenu',source)
end,false)

CreateThread(function()
    while true do
        Wait(30000)
        if Config.Packages and Config.Packages.enabled then RefreshPackageDeliveries() end
    end
end)
