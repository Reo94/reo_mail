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
-- SECTION 4: PHYSICAL ENVELOPE ITEM
-- ============================================================

exports('openEnvelope', function(data, slot)

    -- --------------------------------------------------------
    -- Validate Inventory Slot
    -- --------------------------------------------------------

    if not slot
        or not slot.slot
        or not slot.metadata
        or not slot.metadata.mailId
    then

        lib.notify({
            title = 'San Andreas Postal Service',
            description = 'This envelope does not contain valid postal information.',
            type = 'error'
        })

        return
    end


    -- --------------------------------------------------------
    -- Request Envelope Information From Server
    -- --------------------------------------------------------

    local envelope, reason = lib.callback.await(
        'reo_mail:server:inspectPhysicalEnvelope',
        false,
        slot.slot
    )


    -- --------------------------------------------------------
    -- Handle Inspection Errors
    -- --------------------------------------------------------

    if not envelope then

        local message = 'Unable to inspect this envelope.'

        if reason == 'mail_not_found' then
            message = 'The postal record for this envelope could not be verified.'

        elseif reason == 'invalid_envelope' then
            message = 'This envelope does not contain valid postal information.'

        elseif reason == 'character_not_found' then
            message = 'Your postal identity could not be verified.'

        elseif reason == 'not_owner' then
            message = 'This envelope is not addressed to you.'
        end

        lib.notify({
            title = 'San Andreas Postal Service',
            description = message,
            type = 'error'
        })

        return
    end


    -- --------------------------------------------------------
    -- Envelope Inspection Menu
    -- --------------------------------------------------------

    local options = {
        {
            title = 'From',
            description = envelope.senderName or 'Unknown Sender',
            icon = 'user'
        },
        {
            title = 'To',
            description = envelope.recipientName or 'Unknown Recipient',
            icon = 'user'
        },
        {
            title = 'Subject',
            description = envelope.subject or 'No Subject',
            icon = 'envelope'
        },
        {
            title = 'Postal Information',
            description = 'View mail processing information.',
            icon = 'circle-info',

            metadata = {
                {
                    label = 'Tracking',
                    value = envelope.trackingNumber or 'Unknown'
                },
                {
                    label = 'Type',
                    value = envelope.mailType or 'Standard'
                },
                {
                    label = 'Envelope',
                    value = envelope.opened and 'Opened' or 'Sealed'
                }
            }
        }
    }


    -- ========================================================
    -- OPENED ENVELOPE ACTION
    -- ========================================================

    if envelope.opened then

        options[#options + 1] = {
            title = 'Read Letter',
            description = 'Read the contents of this letter.',
            icon = 'envelope-open-text',

            onSelect = function()

                -- --------------------------------------------
                -- Request Letter Contents
                -- --------------------------------------------

                local mail, readReason = lib.callback.await(
                    'reo_mail:server:readPhysicalEnvelope',
                    false,
                    slot.slot
                )

                if not mail then

                    local message = 'Unable to read this letter.'

                    if readReason == 'mail_not_found' then
                        message = 'The postal record for this letter could not be verified.'

                    elseif readReason == 'invalid_envelope' then
                        message = 'This envelope does not contain valid postal information.'

                    elseif readReason == 'envelope_sealed' then
                        message = 'You must open the envelope before reading the letter.'

                    elseif readReason == 'character_not_found' then
                        message = 'Your postal identity could not be verified.'

                    elseif readReason == 'not_owner' then
                        message = 'This letter is not addressed to you.'
                    end

                    lib.notify({
                        title = 'San Andreas Postal Service',
                        description = message,
                        type = 'error'
                    })

                    return
                end


                -- --------------------------------------------
                -- Build Letter Reading Menu
                -- --------------------------------------------

                local letterOptions = {
                    {
                        title = 'From',
                        description = mail.senderName or 'Unknown Sender',
                        icon = 'user'
                    },
                    {
                        title = 'To',
                        description = mail.recipientName or 'Unknown Recipient',
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
                                value = mail.mailType or 'Standard'
                            },
                            {
                                label = 'Status',
                                value = mail.status or 'Unknown'
                            },
                            {
                                label = 'Envelope',
                                value = 'Opened'
                            }
                        }
                    }
                }

                lib.registerContext({
                    id = 'reo_mail_physical_letter',
                    title = mail.subject or 'Mail',
                    menu = 'reo_mail_physical_envelope',
                    options = letterOptions
                })

                lib.showContext('reo_mail_physical_letter')
            end
        }


    -- ========================================================
    -- SEALED ENVELOPE ACTION
    -- ========================================================

    else

        options[#options + 1] = {
            title = 'Open Envelope',
            description = 'Break the seal and open this envelope.',
            icon = 'envelope-open',

            onSelect = function()

                -- --------------------------------------------
                -- Request Server To Open Physical Envelope
                -- --------------------------------------------

                local mail, openReason = lib.callback.await(
                    'reo_mail:server:openPhysicalEnvelope',
                    false,
                    slot.slot
                )

                if not mail then

                    local message = 'Unable to open this envelope.'

                    if openReason == 'mail_not_found' then
                        message = 'The postal record for this envelope could not be verified.'

                    elseif openReason == 'invalid_envelope' then
                        message = 'This envelope does not contain valid postal information.'
                    end

                    lib.notify({
                        title = 'San Andreas Postal Service',
                        description = message,
                        type = 'error'
                    })

                    return
                end


                -- --------------------------------------------
                -- Opening Successful
                -- --------------------------------------------

                lib.notify({
                    title = 'San Andreas Postal Service',
                    description = 'You opened the sealed envelope.',
                    type = 'success'
                })


                -- --------------------------------------------
                -- Refresh Inventory Slot
                -- --------------------------------------------

                local updatedSlot = exports.ox_inventory:GetSlot(
                    slot.slot
                )

                if updatedSlot then
                    exports.reo_mail:openEnvelope(
                        data,
                        updatedSlot
                    )
                end
            end
        }

    end


    -- --------------------------------------------------------
    -- Display Envelope Menu
    -- --------------------------------------------------------

    lib.registerContext({
        id = 'reo_mail_physical_envelope',
        title = envelope.subject or 'Physical Mail',
        options = options
    })

    lib.showContext('reo_mail_physical_envelope')
end)

-- ============================================================
-- SECTION 5: PLAYER-TO-PLAYER MAIL COMPOSITION
-- Development interface for proving persistent player delivery.
-- ============================================================

RegisterCommand('sendmail', function()
    local input = lib.inputDialog('San Andreas Postal Service — Write Letter', {
        {
            type = 'number',
            label = 'Recipient PO Box',
            description = 'Enter the recipient PO Box number.',
            required = true,
            min = 1
        },
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

    local result = lib.callback.await('reo_mail:server:sendPlayerLetter', false, {
        poBox = input[1],
        subject = input[2],
        body = input[3]
    })

    if not result or not result.success then
        local reason = result and result.reason or 'unknown'
        local message = 'Unable to send this letter.'

        if reason == 'invalid_recipient' then
            message = 'That PO Box could not be found.'
        elseif reason == 'self_mail' then
            message = 'You cannot send a letter to your own PO Box.'
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
        description = ('Letter mailed to PO Box %s. Tracking: %s'):format(
            tostring(result.poBox),
            result.trackingNumber or 'Unknown'
        ),
        type = 'success',
        duration = 8000
    })
end, false)
