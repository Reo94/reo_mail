-- Add this INSIDE the main return table in ox_inventory/data/items.lua

['reo_envelope'] = {
    label = 'Sealed Envelope',
    weight = 25,
    stack = false,
    close = true,
    consume = 0,
    description = 'A sealed piece of mail handled by the San Andreas Postal Service.',
    client = {
        export = 'reo_mail.openEnvelope'
    }
},
