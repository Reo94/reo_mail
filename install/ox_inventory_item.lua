-- Add these INSIDE the main return table in ox_inventory/data/items.lua

-- ============================================================
-- REO DEVELOPMENT - REO MAIL
-- PHYSICAL MAIL ITEMS - PHASE 2
-- ============================================================

['reo_envelope_sealed'] = {
    label = 'Sealed Envelope',
    weight = 25,
    stack = false,
    close = true,
    consume = 0,
    description = 'A sealed piece of mail. Open it to remove the letter inside.',
    client = {
        image = 'reo_envelope_sealed.png',
        export = 'reo_mail.openSealedEnvelope'
    }
},

['reo_envelope_opened'] = {
    label = 'Opened Envelope',
    weight = 20,
    stack = false,
    close = true,
    consume = 0,
    description = 'An opened postal envelope.',
    client = {
        image = 'reo_envelope_opened.png',
        export = 'reo_mail.inspectOpenedEnvelope'
    }
},

['reo_envelope_letter'] = {
    label = 'Letter',
    weight = 10,
    stack = false,
    close = true,
    consume = 0,
    description = 'A physical letter that can be read, stored, or handed to another person.',
    client = {
        image = 'reo_envelope_letter.png',
        export = 'reo_mail.readPhysicalLetter'
    }
},

-- ============================================================
-- REO DEVELOPMENT - REO MAIL v0.5.0
-- PHYSICAL SHIPPING BOXES
-- ============================================================

['reo_shipping_box_small'] = {
    label = 'Small Shipping Box', weight = 250, stack = false, close = true, consume = 0,
    description = 'A reusable REO Mail shipping box. Open it to pack items, then seal and address it.',
    client = { image = 'reo_shipping_box_small.png', export = 'reo_mail.useShippingBox' }
},
['reo_shipping_box_medium'] = {
    label = 'Medium Shipping Box', weight = 400, stack = false, close = true, consume = 0,
    description = 'A reusable REO Mail shipping box. Open it to pack items, then seal and address it.',
    client = { image = 'reo_shipping_box_medium.png', export = 'reo_mail.useShippingBox' }
},
['reo_shipping_box_large'] = {
    label = 'Large Shipping Box', weight = 650, stack = false, close = true, consume = 0,
    description = 'A reusable REO Mail shipping box. Open it to pack items, then seal and address it.',
    client = { image = 'reo_shipping_box_large.png', export = 'reo_mail.useShippingBox' }
},
['reo_shipping_box_xlarge'] = {
    label = 'Extra Large Shipping Box', weight = 900, stack = false, close = true, consume = 0,
    description = 'A reusable REO Mail shipping box. Open it to pack items, then seal and address it.',
    client = { image = 'reo_shipping_box_xlarge.png', export = 'reo_mail.useShippingBox' }
},


-- ============================================================
-- REO DEVELOPMENT - REO MAIL v0.7.0
-- PREPARED OUTGOING MAIL
-- ============================================================
['reo_letter_blank'] = {
    label = 'Blank Letter', weight = 5, stack = true, close = true, consume = 0,
    description = 'Blank stationery for writing physical REO Mail.',
    client = { image = 'reo_letter_blank.png', export = 'reo_mail.writeOutgoingLetter' }
},
['reo_outgoing_letter'] = {
    label = 'Prepared Letter', weight = 10, stack = false, close = true, consume = 0,
    description = 'A prepared letter. It can be mailed by itself or placed into an open envelope.',
    client = { image = 'reo_outgoing_letter.png', export = 'reo_mail.useOutgoingLetter' }
},
['reo_envelope_open'] = {
    label = 'Open Mailing Envelope', weight = 20, stack = false, close = true, consume = 0,
    description = 'An empty mailing envelope. Insert up to five prepared letters/documents, then seal it.',
    client = { image = 'reo_envelope_open.png', export = 'reo_mail.useOpenOutgoingEnvelope' }
},
['reo_outgoing_envelope'] = {
    label = 'Prepared Sealed Envelope', weight = 25, stack = false, close = true, consume = 0,
    description = 'A sealed outgoing envelope ready to be deposited at GoPostal or a public post box.',
    client = { image = 'reo_outgoing_envelope.png', export = 'reo_mail.useOutgoingEnvelope' }
},
