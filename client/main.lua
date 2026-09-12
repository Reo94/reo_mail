-- ============================================================
-- REO DEVELOPMENT
-- REO MAIL
-- Client Core
-- Version 0.1.0
-- ============================================================


-- ============================================================
-- SECTION 1: OPEN MAIL ITEM
-- ============================================================

local function OpenMailItem(mailId)

    local mail = lib.callback.await(
        'reo_mail:server:getMailItem',
        false,
        mailId
    )

    if not mail then
        lib.notify({
            title = 'San Andreas Postal Service',
            description = 'Unable to open this piece of mail.',
            type = 'error'
        })

        return
    end

    local options = {
        {
            title = 'From',
            description = mail.senderName or 'Unknown Sender',
            icon = 'user'
        },
        {
            title = 'Letter',
            description = mail.body or '',
            icon = 'envelope-open-text'
        },
        {
            title = 'Postal Information',
            description = 'Mail processing information.',
            icon = 'circle-info',

            metadata = {
                {
                    label = 'Tracking',
                    value = mail.trackingNumber or 'Unknown'
                },
                {
                    label = 'Type',
                    value = mail.mailType or 'Unknown'
                },
                {
                    label = 'Status',
                    value = mail.status or 'Unknown'
                }
            }
        }
    }

    -- --------------------------------------------------------
    -- Take Physical Envelope
    -- --------------------------------------------------------

    if not mail.claimed then

        options[#options + 1] = {
            title = 'Take Envelope',
            description = 'Take this piece of mail from your mailbox.',
            icon = 'box-archive',

            onSelect = function()

                local success, reason = lib.callback.await(
                    'reo_mail:server:claimMail',
                    false,
                    mail.id
                )

                if not success then
                    local message = 'Unable to retrieve this envelope.'

                    if reason == 'already_claimed' then
                        message = 'You have already taken this envelope.'

                    elseif reason == 'inventory_failed' then
                        message = 'You do not have enough inventory space.'
                    end

                    lib.notify({
                        title = 'San Andreas Postal Service',
                        description = message,
                        type = 'error'
                    })

                    return
                end

                lib.notify({
                    title = 'San Andreas Postal Service',
                    description = 'Envelope added to your inventory.',
                    type = 'success'
                })
            end
        }
    end

    lib.registerContext({
        id = 'reo_mail_letter',
        title = mail.subject or 'Mail',
        menu = 'reo_mail_mailbox',
        options = options
    })

    lib.showContext('reo_mail_letter')
end


-- ============================================================
-- SECTION 2: OPEN MAILBOX
-- ============================================================

local function OpenMailbox()

    local mailItems = lib.callback.await(
        'reo_mail:server:getMailbox',
        false
    )

    if not mailItems then
        lib.notify({
            title = 'San Andreas Postal Service',
            description = 'Unable to retrieve your mail.',
            type = 'error'
        })

        return
    end

    if #mailItems == 0 then
        lib.notify({
            title = 'San Andreas Postal Service',
            description = 'You currently have no mail.',
            type = 'inform'
        })

        return
    end

    local options = {}

    for _, mail in ipairs(mailItems) do

        local mailId = mail.id

        options[#options + 1] = {
            title = mail.subject or 'No Subject',

            description = ('From: %s | Status: %s'):format(
                mail.senderName or 'Unknown Sender',
                mail.status or 'Unknown'
            ),

            icon = mail.claimed and 'envelope-open' or 'envelope',

            metadata = {
                {
                    label = 'Tracking',
                    value = mail.trackingNumber or 'Unknown'
                },
                {
                    label = 'Mail Type',
                    value = mail.mailType or 'Unknown'
                },
                {
                    label = 'Status',
                    value = mail.status or 'Unknown'
                }
            },

            onSelect = function()
                OpenMailItem(mailId)
            end
        }
    end

    lib.registerContext({
        id = 'reo_mail_mailbox',
        title = 'San Andreas Postal Service',
        options = options
    })

    lib.showContext('reo_mail_mailbox')
end


-- ============================================================
-- SECTION 3: MAILBOX COMMAND
-- ============================================================

RegisterCommand('mymail', function()
    OpenMailbox()
end, false)


-- ============================================================
-- SECTION 4: PHYSICAL MAIL ITEMS - PHASE 2
-- ============================================================

local function PhysicalMailError(reason, itemType)
    local message = itemType == 'letter'
        and 'Unable to read this letter.'
        or 'Unable to use this envelope.'

    if reason == 'mail_not_found' then
        message = 'The postal record for this item could not be verified.'
    elseif reason == 'invalid_envelope' then
        message = 'This envelope does not contain valid postal information.'
    elseif reason == 'invalid_letter' then
        message = 'This letter does not contain valid postal information.'
    elseif reason == 'character_not_found' then
        message = 'Your postal identity could not be verified.'
    elseif reason == 'inventory_full' then
        message = 'You need enough inventory space for the opened envelope and letter.'
    elseif reason == 'remove_failed' then
        message = 'The sealed envelope could not be removed from your inventory.'
    end

    lib.notify({
        title = 'San Andreas Postal Service',
        description = message,
        type = 'error'
    })
end

-- ============================================================
-- SECTION 4A: SEALED ENVELOPE
-- Using the item physically breaks it into an opened envelope
-- and a separate readable letter.
-- ============================================================

exports('openSealedEnvelope', function(data, slot)
    if not slot or not slot.slot or not slot.metadata or not slot.metadata.mailId then
        PhysicalMailError('invalid_envelope', 'envelope')
        return
    end

    local mail, reason = lib.callback.await(
        'reo_mail:server:openSealedEnvelope',
        false,
        slot.slot
    )

    if not mail then
        PhysicalMailError(reason, 'envelope')
        return
    end

    lib.notify({
        title = 'San Andreas Postal Service',
        description = 'You opened the envelope and removed the letter inside.',
        type = 'success'
    })
end)

-- ============================================================
-- SECTION 4B: OPENED ENVELOPE
-- The opened envelope remains as a separate physical item.
-- ============================================================

exports('inspectOpenedEnvelope', function(data, slot)
    if not slot or not slot.slot or not slot.metadata or not slot.metadata.mailId then
        PhysicalMailError('invalid_envelope', 'envelope')
        return
    end

    local envelope, reason = lib.callback.await(
        'reo_mail:server:inspectOpenedEnvelope',
        false,
        slot.slot
    )

    if not envelope then
        PhysicalMailError(reason, 'envelope')
        return
    end

    lib.registerContext({
        id = 'reo_mail_opened_envelope',
        title = 'Opened Envelope',
        options = {
            {
                title = 'From',
                description = envelope.senderName,
                icon = 'user'
            },
            {
                title = 'To',
                description = envelope.recipientName,
                icon = 'user'
            },
            {
                title = 'Subject',
                description = envelope.subject,
                icon = 'envelope'
            },
            {
                title = 'Postal Information',
                icon = 'circle-info',
                metadata = {
                    { label = 'Tracking', value = envelope.trackingNumber },
                    { label = 'Type', value = envelope.mailType },
                    { label = 'Status', value = envelope.status }
                }
            }
        }
    })

    lib.showContext('reo_mail_opened_envelope')
end)

-- ============================================================
-- SECTION 4C: PHYSICAL LETTER READER
-- Walkable reader, LEFT ALT mouse toggle, and reading animation.
-- ============================================================

local letterReaderOpen = false
local letterReaderReady = false
local letterReaderSession = 0
local letterMouseEnabled = false
local letterAnimActive = false
local letterProp = nil

local LETTER_ANIM_DICT = 'amb@world_human_clipboard@male@base'
local LETTER_ANIM_NAME = 'base'

local function SetLetterMouse(enabled)
    letterMouseEnabled = enabled == true

    if letterMouseEnabled then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
    else
        -- Keep the NUI visible, but return mouse/camera control to gameplay.
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end

    SendNUIMessage({
        action = 'setMouseMode',
        enabled = letterMouseEnabled
    })
end

local function StartLetterAnimation()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then
        return
    end

    RequestAnimDict(LETTER_ANIM_DICT)
    local timeout = GetGameTimer() + 3000

    while not HasAnimDictLoaded(LETTER_ANIM_DICT) and GetGameTimer() < timeout do
        Wait(0)
    end

    if not HasAnimDictLoaded(LETTER_ANIM_DICT) then
        return
    end

    -- Upper-body only so the player can continue walking while reading.
    TaskPlayAnim(ped, LETTER_ANIM_DICT, LETTER_ANIM_NAME, 3.0, 3.0, -1, 49, 0.0, false, false, false)
    letterAnimActive = true
end

local function DeleteLetterProp()
    if letterProp and DoesEntityExist(letterProp) then
        DeleteEntity(letterProp)
    end
    letterProp = nil
end

local function CreateLetterProp()
    DeleteLetterProp()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    local cfg = Config.LetterReader or {}
    local model = joaat(cfg.prop or 'prop_cs_document_01')
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        model = joaat(cfg.fallbackProp or 'prop_notepad_01')
    end

    RequestModel(model)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(model) then return end

    local pos = cfg.position or vec3(0.12, 0.02, -0.02)
    local rot = cfg.rotation or vec3(-90.0, 0.0, 10.0)
    letterProp = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(letterProp, ped, GetPedBoneIndex(ped, cfg.bone or 57005),
        pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
end

local function StopLetterAnimation()
    local ped = PlayerPedId()
    if letterAnimActive and DoesEntityExist(ped) then
        StopAnimTask(ped, LETTER_ANIM_DICT, LETTER_ANIM_NAME, 1.5)
    end
    letterAnimActive = false
    DeleteLetterProp()
end

local function ClosePhysicalLetter()
    letterReaderOpen = false
    letterReaderSession = letterReaderSession + 1
    SetLetterMouse(false)
    StopLetterAnimation()
    SendNUIMessage({ action = 'closeLetter' })
end

RegisterNUICallback('readerReady', function(_, cb)
    letterReaderReady = true
    cb({ ok = true })
end)

RegisterNUICallback('closeLetter', function(_, cb)
    ClosePhysicalLetter()
    cb({ ok = true })
end)

RegisterCommand('reomailcloseletter', function()
    ClosePhysicalLetter()
end, false)

-- LEFT ALT toggles mouse mode while the letter is open.
-- ESC / BACKSPACE always closes the letter.
CreateThread(function()
    while true do
        if letterReaderOpen then
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim
            DisableControlAction(0, 37, true)  -- Weapon wheel
            DisableControlAction(0, 44, true)  -- Cover
            DisableControlAction(0, 45, true)  -- Reload
            DisableControlAction(0, 140, true) -- Melee light
            DisableControlAction(0, 141, true) -- Melee heavy
            DisableControlAction(0, 142, true) -- Melee alternate
            DisableControlAction(0, 200, true) -- ESC / pause
            DisableControlAction(0, 177, true) -- BACKSPACE

            -- INPUT_CHARACTER_WHEEL (19) is LEFT ALT by default.
            if IsControlJustPressed(0, 19) or IsDisabledControlJustPressed(0, 19) then
                SetLetterMouse(not letterMouseEnabled)
            end

            if IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 177) then
                ClosePhysicalLetter()
            end

            -- Re-apply the upper-body reading pose if gameplay interrupts it.
            if letterAnimActive and not IsEntityPlayingAnim(PlayerPedId(), LETTER_ANIM_DICT, LETTER_ANIM_NAME, 3) then
                StartLetterAnimation()
            end

            Wait(0)
        else
            Wait(250)
        end
    end
end)

exports('readPhysicalLetter', function(data, slot)
    if not slot or not slot.slot or not slot.metadata or not slot.metadata.mailId then
        PhysicalMailError('invalid_letter', 'letter')
        return
    end

    local mail, reason = lib.callback.await(
        'reo_mail:server:readPhysicalLetter',
        false,
        slot.slot
    )

    if not mail then
        PhysicalMailError(reason, 'letter')
        return
    end

    SendNUIMessage({ action = 'pingReader' })
    Wait(100)

    letterReaderOpen = true
    letterReaderSession = letterReaderSession + 1
    local thisSession = letterReaderSession

    SendNUIMessage({
        action = 'openLetter',
        letter = mail
    })

    -- Reader starts mouse-free so the player can immediately walk/look around.
    SetLetterMouse(false)
    StartLetterAnimation()
    CreateLetterProp()

    SetTimeout(2000, function()
        if letterReaderOpen and thisSession == letterReaderSession and not letterReaderReady then
            ClosePhysicalLetter()
            lib.notify({
                title = 'REO Mail',
                description = 'Letter reader failed to load. Controls were restored automatically.',
                type = 'error'
            })
        end
    end)
end)

-- Clean up focus/animation if the resource is restarted while a letter is open.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    StopLetterAnimation()
end)

-- ============================================================
-- SECTION 4D: LOST MAIL RECOVERY COUNTER
-- Physical location where a player can request one replacement
-- for mail previously removed from their mailbox.
-- ============================================================

local function OpenMailRecovery()
    local items = lib.callback.await('reo_mail:server:getRecoverableMail', false)
    if not items or #items == 0 then
        lib.notify({ title = 'REO Mail Recovery', description = 'You have no mail eligible for recovery.', type = 'inform' })
        return
    end

    local options = {}
    for _, mail in ipairs(items) do
        local mailId = mail.id
        options[#options + 1] = {
            title = mail.subject or 'No Subject',
            description = ('From: %s | Tracking: %s | Replacement: $%s CASH'):format(mail.senderName or 'Unknown', mail.trackingNumber or 'Unknown', Config.MailRecovery.reissueCost or 150),
            icon = 'rotate-left',
            onSelect = function()
                local cost = Config.MailRecovery.reissueCost or 150
                local confirm = lib.alertDialog({
                    header = 'Recover Lost Mail',
                    content = ('Purchase another sealed copy for **$%s cash**?'):format(cost),
                    centered = true,
                    cancel = true
                })
                if confirm ~= 'confirm' then return end

                local success, reason = lib.callback.await('reo_mail:server:recoverMail', false, mailId)
                if success then
                    lib.notify({ title = 'REO Mail Recovery', description = ('Replacement issued for $%s cash.'):format(Config.MailRecovery.reissueCost or 150), type = 'success' })
                else
                    local msg = reason == 'not_enough_cash' and ('You need $%s cash to recover this mail.'):format(Config.MailRecovery.reissueCost or 150)
                        or reason == 'inventory_failed' and 'You do not have enough inventory space.'
                        or reason == 'payment_failed' and 'The cash payment could not be processed.'
                        or 'Unable to recover this mail.'
                    lib.notify({ title = 'REO Mail Recovery', description = msg, type = 'error' })
                end
            end
        }
    end

    lib.registerContext({ id = 'reo_mail_recovery', title = 'REO Mail — Lost Mail Recovery', options = options })
    lib.showContext('reo_mail_recovery')
end

-- Lost Mail Recovery is now opened from the unified Postal Services counter.


-- ============================================================
-- SECTION 8: PLAYER-TO-PLAYER MAIL COMPOSITION v0.3.8
-- Template -> Recipient Directory -> Letter
-- ============================================================

local ComposeState = {
    templateId = nil,
    templateLabel = nil
}

local function SendComposedLetter(recipient)
    if not recipient or not recipient.characterId then return end

    local input = lib.inputDialog(('Write Letter — %s'):format(recipient.name or 'Recipient'), {
        {
            type = 'input',
            label = 'Subject',
            description = 'Enter a subject for the letter.',
            required = true,
            min = 1,
            max = 100
        },
        {
            type = 'textarea',
            label = 'Letter',
            description = 'Write the contents of your letter.',
            required = true,
            min = 1,
            max = 4000,
            autosize = true
        }
    })

    if not input then return end

    local confirm = lib.alertDialog({
        header = 'Mail This Letter?',
        content = ('**Template:** %s\n\n**To:** %s\n\n**Subject:** %s'):format(
            ComposeState.templateLabel or 'Basic Mail',
            recipient.name or 'Recipient',
            input[1]
        ),
        centered = true,
        cancel = true,
        labels = { confirm = 'Send Letter', cancel = 'Cancel' }
    })

    if confirm ~= 'confirm' then return end

    local result = lib.callback.await('reo_mail:server:sendPlayerLetter', false, {
        recipientCharacterId = recipient.characterId,
        templateId = ComposeState.templateId or 'basic',
        subject = input[1],
        body = input[2]
    })

    if not result or not result.success then
        local reason = result and result.reason or 'unknown'
        local message = 'Unable to send this letter.'

        if reason == 'invalid_recipient' then
            message = 'That recipient could not be found.'
        elseif reason == 'self_mail' then
            message = 'You cannot send a letter to yourself.'
        elseif reason == 'invalid_template' then
            message = 'You are not authorized to use that mail template.'
        elseif reason == 'invalid_content' then
            message = 'The subject or letter contents are invalid.'
        elseif reason == 'character_unavailable' then
            message = 'Your postal identity could not be verified.'
        end

        lib.notify({
            title = 'San Andreas Postal Service',
            description = message,
            type = 'error'
        })
        return
    end

    lib.notify({
        title = 'San Andreas Postal Service',
        description = ('Letter mailed to %s. Tracking: %s'):format(
            result.recipientName or recipient.name or 'Recipient',
            result.trackingNumber or 'Unknown'
        ),
        type = 'success',
        duration = 8000
    })
end

local function ShowRecipientResults(recipients, title)
    if not recipients or #recipients == 0 then
        lib.notify({
            title = 'REO Mail Recipient Directory',
            description = 'No matching recipients were found.',
            type = 'inform'
        })
        return
    end

    local options = {}
    for _, recipient in ipairs(recipients) do
        local selected = recipient
        options[#options + 1] = {
            title = selected.name or 'Unknown Character',
            description = selected.online and 'Online now' or 'REO Mail directory',
            icon = selected.online and 'circle-user' or 'address-card',
            onSelect = function()
                SendComposedLetter(selected)
            end
        }
    end

    lib.registerContext({
        id = 'reo_mail_recipient_results',
        title = title or 'Select Recipient',
        menu = 'reo_mail_recipient_directory',
        options = options
    })
    lib.showContext('reo_mail_recipient_results')
end

local function SearchRecipientDirectory()
    local input = lib.inputDialog('Search REO Mail Directory', {
        {
            type = 'input',
            label = 'Character Name',
            description = 'Search by first name, last name, or full name.',
            required = true,
            min = (Config.RecipientDirectory and Config.RecipientDirectory.minimumSearchLength) or 2,
            max = 80
        }
    })
    if not input then return end

    local recipients = lib.callback.await('reo_mail:server:searchRecipients', false, input[1]) or {}
    ShowRecipientResults(recipients, ('Search: %s'):format(input[1]))
end

local function OpenRecipientDirectory()
    local online = lib.callback.await('reo_mail:server:getOnlineRecipients', false) or {}
    local businesses = lib.callback.await('reo_mail:server:getBusinesses', false) or {}
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openDirectory', online = online, businesses = businesses })
end

local function SendComposedBusinessLetter(business)
    if not business or not business.id then return end
    local input = lib.inputDialog(('Write Letter — %s'):format(business.name or 'Business'), {
        { type='input', label='Subject', required=true, min=1, max=100 },
        { type='textarea', label='Letter', required=true, min=1, max=4000, autosize=true }
    })
    if not input then return end
    local confirm = lib.alertDialog({
        header='Mail This Letter?',
        content=('**Template:** %s\n\n**Business:** %s\n\n**Subject:** %s'):format(ComposeState.templateLabel or 'Basic Mail', business.name or 'Business', input[1]),
        centered=true, cancel=true, labels={confirm='Send Letter', cancel='Cancel'}
    })
    if confirm ~= 'confirm' then return end
    local result = lib.callback.await('reo_mail:server:sendBusinessLetter', false, {
        businessId=business.id, templateId=ComposeState.templateId or 'basic', subject=input[1], body=input[2]
    })
    if result and result.success then
        lib.notify({title='San Andreas Postal Service', description=('Letter mailed to %s. Tracking: %s'):format(result.recipientName or business.name, result.trackingNumber or 'Unknown'), type='success', duration=8000})
    else
        lib.notify({title='San Andreas Postal Service', description='Unable to send this business letter.', type='error'})
    end
end

RegisterNUICallback('directorySearch', function(data, cb)
    local query = type(data) == 'table' and tostring(data.query or '') or ''
    local results = lib.callback.await('reo_mail:server:searchRecipients', false, query) or {}

    -- Return the matches directly to the browser request. This keeps live search
    -- responses paired with the text that triggered them and prevents older
    -- asynchronous results from replacing newer suggestions.
    cb({ ok = true, results = results })
end)

RegisterNUICallback('closeDirectory', function(_, cb)
    SetNuiFocus(false, false)
    cb({ok=true})
end)

RegisterNUICallback('selectDirectoryRecipient', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({action='closeDirectory'})
    cb({ok=true})
    CreateThread(function()
        Wait(50)
        if data and data.type == 'business' then SendComposedBusinessLetter(data.item)
        elseif data and data.item then SendComposedLetter(data.item) end
    end)
end)

local function OpenTemplateSelector()
    local templates = lib.callback.await('reo_mail:server:getComposeTemplates', false) or {}
    if #templates == 0 then
        lib.notify({
            title = 'San Andreas Postal Service',
            description = 'No mail templates are currently available to you.',
            type = 'error'
        })
        return
    end

    local options = {}
    for _, template in ipairs(templates) do
        local selected = template
        options[#options + 1] = {
            title = selected.label,
            description = selected.description or '',
            icon = 'file-lines',
            onSelect = function()
                ComposeState.templateId = selected.id
                ComposeState.templateLabel = selected.label
                OpenRecipientDirectory()
            end
        }
    end

    lib.registerContext({
        id = 'reo_mail_template_selector',
        title = 'Choose Mail Template',
        options = options
    })
    lib.showContext('reo_mail_template_selector')
end

RegisterCommand('sendmail', function()
    OpenTemplateSelector()
end, false)



-- ============================================================
-- SECTION 9: BUSINESS MAILBOXES v0.4.0
-- Each configured business gets a physical, job-restricted mailbox.
-- ============================================================

local function OpenBusinessMailbox(businessId, business)
    local mail, reason = lib.callback.await('reo_mail:server:getBusinessMail', false, businessId)
    if not mail then
        lib.notify({title='REO Mail Business Mailbox', description=reason == 'unauthorized' and 'You are not authorized to access this business mailbox.' or 'Unable to load business mail.', type='error'})
        return
    end
    local options = {}
    for _, item in ipairs(mail) do
        local row = item
        options[#options+1] = {
            title=row.subject or 'No Subject',
            description=('From: %s | %s'):format(row.sender_name or 'Unknown', row.claimed_at and 'Already collected' or 'Ready for pickup'),
            icon=row.claimed_at and 'envelope-open' or 'envelope',
            disabled=row.claimed_at ~= nil,
            onSelect=function()
                local ok, why = lib.callback.await('reo_mail:server:claimBusinessMail', false, businessId, row.id)
                if ok then lib.notify({title=business.label or 'Business Mail', description='Sealed envelope collected.', type='success'})
                else lib.notify({title=business.label or 'Business Mail', description=why == 'inventory_failed' and 'Not enough inventory space.' or 'Unable to collect this mail.', type='error'}) end
            end
        }
    end
    if #options == 0 then options[1] = {title='No Mail', description='This business mailbox is empty.', disabled=true} end
    lib.registerContext({id='reo_mail_business_mailbox_'..businessId, title=(business.label or businessId)..' — Mailbox', options=options})
    lib.showContext('reo_mail_business_mailbox_'..businessId)
end

CreateThread(function()
    for businessId, business in pairs(Config.Businesses or {}) do
        if business.enabled ~= false and business.mailbox then
            local id, cfg = businessId, business
            local point = lib.points.new({coords=cfg.mailbox, distance=cfg.drawDistance or 15.0})
            function point:nearby()
                if self.currentDistance <= (cfg.radius or 1.75) then
                    DrawMarker(2, self.coords.x, self.coords.y, self.coords.z + 0.25, 0,0,0, 0,180.0,0, .18,.18,.18, 255,255,255,180, false,true,2,false,nil,nil,false)
                    if not lib.isTextUIOpen() then lib.showTextUI(('[E] Check %s Mail'):format(cfg.label or id)) end
                    if IsControlJustReleased(0,38) then lib.hideTextUI(); OpenBusinessMailbox(id,cfg) end
                elseif lib.isTextUIOpen() then lib.hideTextUI() end
            end
            function point:onExit() if lib.isTextUIOpen() then lib.hideTextUI() end end
        end
    end
end)

-- ============================================================
-- SECTION 10: PACKAGE SYSTEM v0.6.0
-- ============================================================

local PackageState = { slotId=nil, package=nil }
local CourierState = { active=false, ped=nil, packageId=nil }

local function PackageNotify(message, kind)
    lib.notify({title='San Andreas Postal Service',description=message,type=kind or 'inform',duration=8000})
end

local function ServiceOptions()
    local options={}
    for id,cfg in pairs((Config.Packages and Config.Packages.services) or {}) do
        options[#options+1]={value=id,label=('%s — %s min'):format(cfg.label,cfg.minutes)}
    end
    table.sort(options,function(a,b) return a.label<b.label end)
    return options
end

local function CheckoutPackage(slotId, recipientType, recipientId, recipientName)
    local input=lib.inputDialog(('Ship to %s'):format(recipientName),{
        {type='select',label='Shipping Service',required=true,options=ServiceOptions()},
        {type='checkbox',label=('Anonymous Sender (+$%s)'):format(Config.Packages.addons.anonymous.fee or 0)},
        {type='checkbox',label=('Signature Required (+$%s)'):format(Config.Packages.addons.signature.fee or 0)},
        {type='input',label='Scheduled Delivery (optional)',description='Leave blank for normal delivery. Format: YYYY-MM-DD HH:MM',placeholder='2026-09-10 20:00'}
    })
    if not input then return end

    local data={
        slotId=slotId,
        serviceId=input[1],
        anonymous=input[2] == true,
        signature=input[3] == true,
        scheduledFor=(input[4] and input[4]~='') and input[4] or nil
    }
    local callback
    if recipientType=='person' then
        callback='reo_mail:server:sealPlayerPackage'
        data.recipientCharacterId=recipientId
    else
        callback='reo_mail:server:sealBusinessPackage'
        data.businessId=recipientId
    end

    local result=lib.callback.await(callback,false,data)
    if result and result.success then
        local extras={}
        if result.anonymousFee and result.anonymousFee>0 then extras[#extras+1]=('Anonymous +$%s'):format(result.anonymousFee) end
        if result.signatureFee and result.signatureFee>0 then extras[#extras+1]=('Signature +$%s'):format(result.signatureFee) end
        if result.scheduledFor then extras[#extras+1]=('Scheduled: %s'):format(result.scheduledFor) end
        PackageNotify(('Package sealed for %s.\n%s | Total: $%s\n%sTracking: %s'):format(
            result.recipientName,result.service,result.cost,#extras>0 and (table.concat(extras,' | ')..'\n') or '',result.trackingNumber
        ),'success')
    else
        local reason=result and result.reason or 'unknown error'
        if reason=='not_enough_cash' then
            PackageNotify(('Not enough cash. Total postage is $%s.'):format(result.cost or '?'),'error')
        elseif reason=='invalid_schedule' then
            PackageNotify('Scheduled delivery must use YYYY-MM-DD HH:MM and be a future time.','error')
        elseif reason=='signature_business_unsupported' then
            PackageNotify('Signature Required is currently available for character recipients only.','error')
        else
            PackageNotify('Unable to seal package: '..tostring(reason),'error')
        end
    end
end

local function SearchPackageRecipient(slotId)
    local input=lib.inputDialog('Address Package — Search People',{{type='input',label='Character Name',required=true,min=1}})
    if not input or not input[1] then return end
    local recipients=lib.callback.await('reo_mail:server:searchRecipients',false,input[1]) or {}
    local options={}
    for _,r in ipairs(recipients) do
        local recipient=r
        options[#options+1]={
            title=recipient.name,description=recipient.postalLabel or 'PO Box',icon='user',
            onSelect=function() CheckoutPackage(slotId,'person',recipient.characterId,recipient.name) end
        }
    end
    if #options==0 then options[1]={title='No Results',disabled=true} end
    lib.registerContext({id='reo_mail_package_people',title='Package Recipient',options=options})
    lib.showContext('reo_mail_package_people')
end

local function PackageBusinessRecipient(slotId)
    local businesses=lib.callback.await('reo_mail:server:getBusinesses',false) or {}
    local options={}
    for _,b in ipairs(businesses) do
        local business=b
        options[#options+1]={
            title=business.name,icon='building',
            onSelect=function() CheckoutPackage(slotId,'business',business.id,business.name) end
        }
    end
    lib.registerContext({id='reo_mail_package_businesses',title='Business Recipient',options=options})
    lib.showContext('reo_mail_package_businesses')
end

local function SealPackageMenu(slotId)
    lib.registerContext({id='reo_mail_package_address',title='Seal & Address Package',options={
        {title='Send to Person',description='Search the REO Mail character directory.',icon='user',onSelect=function() SearchPackageRecipient(slotId) end},
        {title='Send to Business',description='Choose from the REO Mail business directory.',icon='building',onSelect=function() PackageBusinessRecipient(slotId) end}
    }})
    lib.showContext('reo_mail_package_address')
end

exports('useShippingBox',function(data,slot)
    local slotId=type(slot)=='number' and slot or (type(data)=='table' and (data.slot or data.slotId))
    if not slotId then PackageNotify('Unable to determine the shipping box inventory slot.','error'); return end
    local result=lib.callback.await('reo_mail:server:preparePackageBox',false,slotId)
    if not result or not result.success then PackageNotify('Unable to prepare shipping box: '..tostring(result and result.reason or 'unknown error'),'error'); return end
    if result.package.status=='packing' then
        lib.registerContext({id='reo_mail_package_box',title='Shipping Box',options={
            {title='Open Box',description='Place or remove items from this box.',icon='box-open',onSelect=function() exports.ox_inventory:openInventory('stash',result.stashId) end},
            {title='Seal & Address Package',description='Choose recipient, shipping speed and optional services.',icon='box',onSelect=function() SealPackageMenu(slotId) end}
        }})
        lib.showContext('reo_mail_package_box')
    elseif result.package.status=='picked_up' then
        local opened=lib.callback.await('reo_mail:server:openDeliveredPackage',false,slotId)
        if opened and opened.success then exports.ox_inventory:openInventory('stash',opened.stashId) else PackageNotify('This package cannot be opened.','error') end
    else
        PackageNotify(('Package status: %s%s'):format(result.package.status,result.package.tracking_number and (' | '..result.package.tracking_number) or ''),'inform')
    end
end)

local function PackageDropMenu()
    local boxes={'reo_shipping_box_small','reo_shipping_box_medium','reo_shipping_box_large','reo_shipping_box_xlarge'}
    local options={}
    for _,item in ipairs(boxes) do
        local slots=exports.ox_inventory:Search('slots',item) or {}
        for _,slot in pairs(slots) do
            local md=slot.metadata or {}
            if md.packageStatus=='sealed' then
                local s=slot
                options[#options+1]={
                    title=md.label or 'Sealed Package',description=md.description or md.trackingNumber,icon='box',
                    onSelect=function()
                        local result=lib.callback.await('reo_mail:server:dropOffPackage',false,s.slot)
                        if result and result.success then
                            local eta=result.deliveryDueAt and (' Delivery due: '..tostring(result.deliveryDueAt)..'.') or ''
                            PackageNotify(('Package accepted.%s Tracking: %s'):format(eta,result.trackingNumber),'success')
                        else
                            PackageNotify('Unable to drop off package: '..tostring(result and result.reason or 'unknown error'),'error')
                        end
                    end
                }
            end
        end
    end
    if #options==0 then options[1]={title='No Ready Packages',description='Seal and address a package first.',disabled=true} end
    lib.registerContext({id='reo_mail_package_dropoff',title='GoPostal — Package Drop Off',options=options})
    lib.showContext('reo_mail_package_dropoff')
end

local function PackagePickupMenu()
    local packages=lib.callback.await('reo_mail:server:getReadyPackages',false) or {}
    local options={}
    for _,p in ipairs(packages) do
        local row=p
        local sender=(tonumber(row.anonymous_sender)==1 and row.pickup_role~='return') and 'Anonymous Sender' or (row.sender_name or 'Unknown')
        local prefix=row.pickup_role=='return' and 'RETURNED — ' or ''
        options[#options+1]={
            title=prefix..(row.tracking_number or 'Package'),
            description=(row.pickup_role=='return' and 'Returned to you' or ('From: '..sender))..' | '..(row.shipping_service or 'Standard'),
            icon='box',
            onSelect=function()
                local result=lib.callback.await('reo_mail:server:pickupPackage',false,row.id)
                if result and result.success then
                    PackageNotify(((result.returned and 'Returned package collected. ' or 'Package collected. ')..'Tracking: '..result.trackingNumber),'success')
                else
                    PackageNotify('Unable to collect package: '..tostring(result and result.reason or 'unknown error'),'error')
                end
            end
        }
    end
    if #options==0 then options[1]={title='No Packages Ready',disabled=true} end
    lib.registerContext({id='reo_mail_package_pickup',title='GoPostal — Package Pickup',options=options})
    lib.showContext('reo_mail_package_pickup')
end

local StatusLabels={
    sealed='Awaiting Drop Off',in_transit='In Transit',ready='Ready for Pickup',
    awaiting_signature='Awaiting Signature Delivery',picked_up='Delivered / Collected',
    returning='Returning to Sender',returned_ready='Returned — Ready for Pickup'
}

local function FormatRemaining(seconds)
    seconds=tonumber(seconds) or 0
    if seconds<=0 then return 'Due now' end
    local h=math.floor(seconds/3600)
    local m=math.ceil((seconds%3600)/60)
    if h>0 then return ('%sh %sm'):format(h,m) end
    return ('%s min'):format(m)
end

local function PackageTrackingMenu()
    local packages=lib.callback.await('reo_mail:server:getMyPackageTracking',false) or {}
    local options={}
    for _,p in ipairs(packages) do
        local sizeCfg=Config.Packages.sizes[p.box_size] or {}
        local serviceCfg=Config.Packages.services[p.shipping_service] or {}
        local details={
            ('To: %s'):format(p.recipient_name or 'Unknown'),
            ('%s • %s'):format(sizeCfg.label or p.box_size or 'Package',serviceCfg.label or p.shipping_service or 'Unknown'),
            ('Status: %s'):format(StatusLabels[p.status] or p.status),
            ('Postage: $%s'):format(p.shipping_cost or 0)
        }
        if p.status=='in_transit' then details[#details+1]=('Time Remaining: %s'):format(FormatRemaining(p.seconds_remaining)) end
        if p.delivery_due_at then details[#details+1]=('Estimated/Scheduled Arrival: %s'):format(tostring(p.delivery_due_at)) end
        if tonumber(p.anonymous_sender)==1 then details[#details+1]='Anonymous Sender: Yes' end
        if tonumber(p.signature_required)==1 then details[#details+1]='Signature Required: Yes' end
        options[#options+1]={title=p.tracking_number or 'Package',description=table.concat(details,'\n'),icon='location-dot'}
    end
    if #options==0 then options[1]={title='No Tracked Packages',description='Packages you send will appear here.',disabled=true} end
    lib.registerContext({id='reo_mail_package_tracking',title='Track My Packages',options=options})
    lib.showContext('reo_mail_package_tracking')
end

local function GoPostalMenu()
    -- Pull live counts so the main counter gives the player useful information
    -- before they open a submenu.
    local readyPackages = lib.callback.await('reo_mail:server:getReadyPackages', false) or {}
    local trackedPackages = lib.callback.await('reo_mail:server:getMyPackageTracking', false) or {}

    local readyCount = #readyPackages
    local inTransitCount = 0
    for _, package in ipairs(trackedPackages) do
        if package.status == 'in_transit' or package.status == 'awaiting_signature' or package.status == 'returning' then
            inTransitCount = inTransitCount + 1
        end
    end

    lib.registerContext({
        id = 'reo_mail_gopostal',
        title = 'San Andreas Postal Service',
        options = {
            {
                title = 'Postal Supplies',
                description = 'Purchase blank letters and mailing envelopes.',
                icon = 'pen-to-square',
                onSelect = function() TriggerEvent('reo_mail:client:postalSuppliesShop') end
            },
            {
                title = 'Drop Off Prepared Mail',
                description = 'Deposit a prepared letter or sealed multi-document envelope.',
                icon = 'envelope-circle-check',
                onSelect = function() TriggerEvent('reo_mail:client:preparedMailDrop') end
            },
            {
                title = 'Send a Letter (Legacy)',
                description = 'Original direct letter workflow retained during v0.7 testing.',
                icon = 'envelope',
                onSelect = OpenTemplateSelector
            },
            {
                title = 'Drop Off Package',
                description = 'Hand over a sealed and addressed package for delivery.',
                icon = 'box',
                onSelect = PackageDropMenu
            },
            {
                title = 'Package Pickup',
                description = readyCount > 0 and ('%s package%s ready for pickup.'):format(readyCount, readyCount == 1 and '' or 's') or 'No packages currently ready for pickup.',
                icon = 'box-open',
                onSelect = PackagePickupMenu
            },
            {
                title = 'Track My Packages',
                description = inTransitCount > 0 and ('%s active shipment%s in transit.'):format(inTransitCount, inTransitCount == 1 and '' or 's') or 'View shipments, status, and remaining delivery time.',
                icon = 'location-dot',
                onSelect = PackageTrackingMenu
            },
            {
                title = 'Check My PO Box',
                description = 'View letters currently waiting in your postal mailbox.',
                icon = 'inbox',
                onSelect = OpenMailbox
            },
            {
                title = 'Lost Mail Recovery',
                description = ('Recover previously claimed mail. Replacement copies are $%s cash.'):format(Config.MailRecovery.reissueCost or 150),
                icon = 'rotate-left',
                onSelect = OpenMailRecovery
            }
        }
    })
    lib.showContext('reo_mail_gopostal')
end

RegisterNetEvent('reo_mail:client:packageDropMenu',PackageDropMenu)
RegisterNetEvent('reo_mail:client:packagePickupMenu',PackagePickupMenu)
RegisterNetEvent('reo_mail:client:packageTrackingMenu',PackageTrackingMenu)

local function CleanupCourier()
    if CourierState.ped and DoesEntityExist(CourierState.ped) then DeleteEntity(CourierState.ped) end
    CourierState={active=false,ped=nil,packageId=nil}
end

local function StartSignatureCourier(pkg)
    if CourierState.active or not pkg then return end
    CourierState.active=true
    CourierState.packageId=pkg.id

    local ped=PlayerPedId()
    if IsEntityDead(ped) or IsPedInAnyVehicle(ped,false) then CleanupCourier(); return end

    local model=joaat(Config.Packages.courier.model or 's_m_m_postal_01')
    lib.requestModel(model)
    local origin=GetEntityCoords(ped)
    local angle=math.random()*math.pi*2
    local radius=(Config.Packages.courier.spawnMinRadius or 18.0)+math.random()*((Config.Packages.courier.spawnMaxRadius or 28.0)-(Config.Packages.courier.spawnMinRadius or 18.0))
    local sx=origin.x+math.cos(angle)*radius
    local sy=origin.y+math.sin(angle)*radius
    local sz=origin.z+5.0
    local found,ground=GetGroundZFor_3dCoord(sx,sy,sz,false)
    if found then sz=ground end

    local courier=CreatePed(4,model,sx,sy,sz,0.0,false,true)
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(courier) then CleanupCourier(); return end
    CourierState.ped=courier
    SetEntityAsMissionEntity(courier,true,true)
    SetBlockingOfNonTemporaryEvents(courier,true)
    SetPedCanRagdoll(courier,false)
    TaskGoToEntity(courier,ped,-1,Config.Packages.courier.approachDistance or 2.25,1.2,1073741824,0)

    PackageNotify('A GoPostal courier is approaching with a signature-required package.','inform')

    local started=GetGameTimer()
    while CourierState.active and DoesEntityExist(courier) do
        Wait(500)
        ped=PlayerPedId()
        if IsEntityDead(ped) or IsPedInAnyVehicle(ped,false) then CleanupCourier(); return end
        local dist=#(GetEntityCoords(courier)-GetEntityCoords(ped))
        if dist <= (Config.Packages.courier.approachDistance or 2.25)+0.5 then break end
        if GetGameTimer()-started > (Config.Packages.courier.timeoutSeconds or 90)*1000 then
            PackageNotify('GoPostal could not complete the delivery attempt. They will try again later.','inform')
            CleanupCourier()
            return
        end
    end
    if not CourierState.active or not DoesEntityExist(courier) then return end

    TaskTurnPedToFaceEntity(courier,ped,1000)
    Wait(750)
    local sender=tonumber(pkg.anonymous_sender)==1 and 'Anonymous Sender' or (pkg.sender_name or 'Unknown Sender')
    local answer=lib.alertDialog({
        header='GoPostal — Signature Required',
        content=('Package for **%s**\n\nFrom: **%s**\nTracking: `%s`\n\nAccept and sign for this package?'):format(pkg.recipient_name or 'Recipient',sender,pkg.tracking_number or 'Unknown'),
        centered=true,cancel=true,
        labels={confirm='Sign & Accept',cancel='Refuse Package'}
    })
    local accepted=answer=='confirm'
    local result=lib.callback.await('reo_mail:server:respondSignatureDelivery',false,pkg.id,accepted)
    if result and result.success then
        if result.accepted then
            PackageNotify(('Package signed for and delivered. Tracking: %s'):format(result.trackingNumber),'success')
        else
            PackageNotify(('Package refused. It is being returned to the sender. Tracking: %s'):format(result.trackingNumber),'inform')
        end
    else
        PackageNotify('Unable to complete signature delivery: '..tostring(result and result.reason or 'unknown error'),'error')
    end
    CleanupCourier()
end

CreateThread(function()
    local gp=Config.Packages and Config.Packages.goPostal
    if gp and gp.enabled then
        if gp.blip and gp.blip.enabled then
            local blip=AddBlipForCoord(gp.coords.x,gp.coords.y,gp.coords.z)
            SetBlipSprite(blip,gp.blip.sprite or 478)
            SetBlipColour(blip,gp.blip.colour or 1)
            SetBlipScale(blip,gp.blip.scale or 0.75)
            SetBlipAsShortRange(blip,true)
            BeginTextCommandSetBlipName('STRING'); AddTextComponentString(gp.blip.label or 'GoPostal'); EndTextCommandSetBlipName(blip)
        end
        if not (Config.PostalClerk and Config.PostalClerk.enabled) then
        local point=lib.points.new({coords=gp.coords,distance=gp.drawDistance or 20.0})
        function point:nearby()
            if self.currentDistance <= (gp.radius or 2.0) then
                DrawMarker(2,self.coords.x,self.coords.y,self.coords.z+0.2,0,0,0,0,180.0,0,.20,.20,.20,255,255,255,180,false,true,2,false,nil,nil,false)
                if not lib.isTextUIOpen() then lib.showTextUI('[E] Postal Services') end
                if IsControlJustReleased(0,38) then lib.hideTextUI(); GoPostalMenu() end
            elseif lib.isTextUIOpen() then lib.hideTextUI() end
        end
        function point:onExit() if lib.isTextUIOpen() then lib.hideTextUI() end end
        end -- legacy GoPostal interaction disabled when Postal Clerk terminal is enabled
    end
end)

-- Arrival/login notifications and signature delivery watcher.
CreateThread(function()
    Wait(10000)
    while true do
        if Config.Packages and Config.Packages.enabled then
            local notices=lib.callback.await('reo_mail:server:getPackageNotifications',false) or {}
            for _,n in ipairs(notices) do
                if n.status=='ready' then
                    local sender=tonumber(n.anonymous_sender)==1 and 'Anonymous Sender' or (n.sender_name or 'Unknown Sender')
                    PackageNotify(('You have a package ready for pickup at GoPostal.\nFrom: %s\nTracking: %s'):format(sender,n.tracking_number or 'Unknown'),'success')
                elseif n.status=='returned_ready' then
                    PackageNotify(('A refused package has been returned to you and is ready for pickup at GoPostal.\nTracking: %s'):format(n.tracking_number or 'Unknown'),'inform')
                end
            end

            if not CourierState.active and Config.Packages.courier and Config.Packages.courier.enabled then
                local pkg=lib.callback.await('reo_mail:server:getPendingSignaturePackage',false)
                if pkg then StartSignatureCourier(pkg) end
            end
        end
        Wait(60000)
    end
end)



-- ============================================================
-- REO DEVELOPMENT - SECTION: NON-LOCKING POSTAL TERMINAL UI v0.10.0
-- REO Mail unified front-end. Existing backend/menu
-- functions remain authoritative while the new NUI acts as the hub.
-- ============================================================
local PostalTerminalOpen = false
local PostalTerminalMouse = false
local PostalClerkPed = nil

local function ClosePostalTerminal()
    -- Always release focus, even if Lua/UI state became desynchronized.
    PostalTerminalOpen = false
    PostalTerminalMouse = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'closePostalTerminal' })
end

local function OpenPostalTerminal()
    if PostalTerminalOpen then return end
    PostalTerminalOpen = true
    PostalTerminalMouse = false
    -- v0.10: terminal is visible without taking exclusive keyboard/mouse focus.
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'openPostalTerminal',
        station = (Config.Packages and Config.Packages.goPostal and Config.Packages.goPostal.label) or 'San Andreas Postal Service'
    })
end

RegisterNUICallback('closePostalTerminal', function(_, cb)
    ClosePostalTerminal()
    cb({ success = true })
end)


RegisterNUICallback('togglePostalFocus', function(_, cb)
    if PostalTerminalOpen then
        PostalTerminalMouse = not PostalTerminalMouse
        SetNuiFocus(PostalTerminalMouse, PostalTerminalMouse)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ action = 'setPostalTerminalMouse', enabled = PostalTerminalMouse })
    end
    cb({ success = true, focused = PostalTerminalMouse })
end)

RegisterNUICallback('postalTerminalAction', function(data, cb)
    local action = data and data.action

    if action == 'supplies' then
        local catalog = lib.callback.await('reo_mail:server:getPostalSupplyCatalog', false)
        SendNUIMessage({ action = 'openPostalSupplyShop', catalog = catalog })
        cb({ success = true })
        return
    end

    ClosePostalTerminal()
    Wait(100)

    if action == 'prepared_mail' then
        TriggerEvent('reo_mail:client:preparedMailDrop')
    elseif action == 'package_drop' then
        PackageDropMenu()
    elseif action == 'package_pickup' then
        PackagePickupMenu()
    elseif action == 'tracking' then
        PackageTrackingMenu()
    elseif action == 'mailbox' then
        OpenMailbox()
    elseif action == 'recovery' then
        OpenMailRecovery()
    elseif action == 'legacy_letter' then
        OpenTemplateSelector()
    else
        PackageNotify('That postal service is not available yet.', 'inform')
    end
    cb({ success = true })
end)



-- ============================================================
-- REO DEVELOPMENT - v0.12.0 FULL UNIFIED TERMINAL DATA BRIDGE
-- All visible counter submenus stay inside the REO terminal.
-- ============================================================
local function terminalItem(title, description, badge, action, id, slot, actionLabel)
    return {title=title,description=description,badge=badge,action=action,id=id,slot=slot,actionLabel=actionLabel}
end

RegisterNUICallback('postalTerminalData', function(data, cb)
    local action=data and data.action; local items={}
    if action=='prepared_mail' then
        for _,s in pairs(exports.ox_inventory:GetPlayerItems() or {}) do
            if s.name==Config.PreparedMail.items.outgoingLetter or s.name==Config.PreparedMail.items.sealedEnvelope then local m=s.metadata or {}; items[#items+1]=terminalItem(m.label or 'Prepared Mail',m.description or ('To: '..tostring(m.recipientName or 'Unknown')),'READY TO MAIL','deposit_prepared',nil,s.slot,'SELECT SERVICE') end
        end
        cb({items=items,empty='NO PREPARED MAIL IN INVENTORY'}); return
    elseif action=='package_drop' then
        for _,s in pairs(exports.ox_inventory:GetPlayerItems() or {}) do local m=s.metadata or {}; if m.reoPackageId or m.packageId or m.trackingNumber then items[#items+1]=terminalItem(m.label or 'Prepared Package',m.description or tostring(m.trackingNumber or ''),'PACKAGE DROP-OFF','drop_package',nil,s.slot,'DROP OFF') end end
        cb({items=items,empty='NO PREPARED PACKAGES READY FOR DROP-OFF'}); return
    elseif action=='package_pickup' then
        for _,p in ipairs(lib.callback.await('reo_mail:server:getReadyPackages',false) or {}) do local sender=(tonumber(p.anonymous_sender)==1 and p.pickup_role~='return') and 'Anonymous Sender' or (p.sender_name or 'Unknown'); items[#items+1]=terminalItem(p.tracking_number or 'Package',('From: %s\nService: %s'):format(sender,p.shipping_service or 'Standard'),'READY FOR PICKUP','pickup_package',p.id,nil,'PICK UP') end
        cb({items=items,empty='NO PACKAGES READY FOR PICKUP'}); return
    elseif action=='tracking' then
        for _,p in ipairs(lib.callback.await('reo_mail:server:getMyPackageTracking',false) or {}) do items[#items+1]=terminalItem(p.tracking_number or 'Package',('To: %s\nService: %s\nStatus: %s\nPostage: $%s'):format(p.recipient_name or 'Unknown',p.shipping_service or 'Standard',StatusLabels[p.status] or p.status or 'Unknown',p.shipping_cost or 0),'TRACKING') end
        cb({items=items,empty='NO TRACKED SHIPMENTS'}); return
    elseif action=='mailbox' then
        for _,m in ipairs(lib.callback.await('reo_mail:server:getMailbox',false) or {}) do items[#items+1]=terminalItem(m.subject or 'Mail',('From: %s\nStatus: %s\nTracking: %s'):format(m.senderName or 'Unknown Sender',m.status or 'Unknown',m.trackingNumber or 'Unknown'),'MAILBOX','claim_mail',m.id,nil,m.claimed and 'CLAIMED' or 'TAKE ENVELOPE') end
        cb({items=items,empty='YOUR MAILBOX IS EMPTY'}); return
    elseif action=='recovery' then
        for _,m in ipairs(lib.callback.await('reo_mail:server:getRecoverableMail',false) or {}) do items[#items+1]=terminalItem(m.subject or 'Recoverable Mail',('From: %s\nTracking: %s\nRecovery Fee: $150'):format(m.senderName or m.sender_name or 'Unknown',m.trackingNumber or m.tracking_number or 'Unknown'),'LOST MAIL','recover_mail',m.id,nil,'RECOVER $150') end
        cb({items=items,empty='NO MAIL ELIGIBLE FOR RECOVERY'}); return
    elseif action=='legacy_letter' then cb({items={},empty='USE PREPARE MAIL / PHYSICAL LETTER ITEMS FOR THE CURRENT REO MAIL WORKFLOW'}); return end
    cb({items={},empty='SERVICE READY'} )
end)

RegisterNUICallback('postalTerminalItemAction', function(data, cb)
    local a=data and data.action; local result
    if a=='pickup_package' then result=lib.callback.await('reo_mail:server:pickupPackage',false,data.id)
    elseif a=='claim_mail' then result=lib.callback.await('reo_mail:server:claimMail',false,data.id)
    elseif a=='recover_mail' then result=lib.callback.await('reo_mail:server:recoverMail',false,data.id)
    elseif a=='drop_package' then result=lib.callback.await('reo_mail:server:dropOffPackage',false,data.slot)
    elseif a=='deposit_prepared' then
        -- Keep terminal visible; service/add-on selection is the one remaining structured input dialog.
        TriggerEvent('reo_mail:client:terminalPreparedDeposit',data.slot); result={success=true,refresh=false}
    else result={success=false,reason='unknown_action'} end
    if result and result.success then PackageNotify('Postal transaction completed.','success') else PackageNotify('Unable to complete transaction: '..tostring(result and result.reason or 'unknown'),'error') end
    cb({success=result and result.success or false,refresh=a~='deposit_prepared'})
end)

RegisterNUICallback('purchasePostalSupplies', function(data, cb)
    local result = lib.callback.await('reo_mail:server:purchasePostalSupplies', false, data and data.order or {})
    if result and result.success then
        PackageNotify(('Postal supplies purchased for $%s.'):format(result.total or 0), 'success')
    else
        local reason = result and result.reason or 'unknown'
        local messages = {
            empty_order = 'Select at least one postal supply.',
            inventory_full = 'You do not have enough inventory space.',
            not_enough_cash = 'You do not have enough cash.',
            quantity_too_high = 'That quantity is above the purchase limit.',
            payment_failed = 'Payment could not be processed.',
            inventory_failed = 'The supplies could not be added to your inventory.'
        }
        PackageNotify(messages[reason] or ('Purchase failed: '..tostring(reason)), 'error')
    end
    cb(result or { success=false, reason='unknown' })
end)

RegisterNetEvent('reo_mail:client:openPostalTerminal', OpenPostalTerminal)
RegisterCommand('reoterminal', function() OpenPostalTerminal() end, false)

-- Emergency NUI failsafe. This intentionally does not depend on PostalTerminalOpen.
RegisterCommand('reomailclose', function()
    ClosePostalTerminal()
    SendNUIMessage({ action = 'closeDirectory' })
    SendNUIMessage({ action = 'closeLetter' })
end, false)

-- Native Lua safety controls. These continue working even if the browser UI crashes.
-- LEFT ALT toggles exclusive terminal focus. ALT again returns focus to gameplay/camera. ESC and F10 force-close.
RegisterKeyMapping('reomailclose', 'Emergency close REO Mail terminal', 'keyboard', 'F10')

CreateThread(function()
    while true do
        if PostalTerminalOpen then
            Wait(0)

            local altPressed = IsControlJustPressed(0, 19) or IsDisabledControlJustPressed(0, 19)
            if altPressed then
                PostalTerminalMouse = not PostalTerminalMouse
                SetNuiFocus(PostalTerminalMouse, PostalTerminalMouse)
                SetNuiFocusKeepInput(false)
                SendNUIMessage({ action = 'setPostalTerminalMouse', enabled = PostalTerminalMouse })
            end

            local escapePressed = IsControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 200)
            if escapePressed then
                ClosePostalTerminal()
                Wait(250)
            end
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    local cfg = Config.PostalClerk
    if not cfg or not cfg.enabled then return end

    local model = joaat(cfg.model or 's_m_m_postal_01')
    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(50) end
    if not HasModelLoaded(model) then return end

    PostalClerkPed = CreatePed(4, model, cfg.coords.x, cfg.coords.y, cfg.coords.z, cfg.coords.w or 0.0, false, true)
    SetEntityAsMissionEntity(PostalClerkPed, true, true)
    SetEntityInvincible(PostalClerkPed, true)
    FreezeEntityPosition(PostalClerkPed, true)
    SetBlockingOfNonTemporaryEvents(PostalClerkPed, true)
    SetPedCanRagdoll(PostalClerkPed, false)
    if cfg.scenario and cfg.scenario ~= '' then
        TaskStartScenarioInPlace(PostalClerkPed, cfg.scenario, 0, true)
    end
    SetModelAsNoLongerNeeded(model)

    while DoesEntityExist(PostalClerkPed) do
        local sleep = 750
        local player = PlayerPedId()
        local dist = #(GetEntityCoords(player) - GetEntityCoords(PostalClerkPed))
        if dist <= (cfg.drawDistance or 25.0) then
            sleep = 0
            if dist <= (cfg.interactDistance or 2.25) and not PostalTerminalOpen then
                if not lib.isTextUIOpen() then
                    lib.showTextUI(('[E] %s'):format(cfg.label or 'Talk to Postal Clerk'))
                end
                if IsControlJustReleased(0, 38) then
                    lib.hideTextUI()
                    OpenPostalTerminal()
                end
            elseif lib.isTextUIOpen() and dist > (cfg.interactDistance or 2.25) then
                lib.hideTextUI()
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    PostalTerminalOpen = false
    PostalTerminalMouse = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    if PostalClerkPed and DoesEntityExist(PostalClerkPed) then DeleteEntity(PostalClerkPed) end
end)

RegisterCommand('reogopostal',function() GoPostalMenu() end,false)
