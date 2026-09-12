-- ============================================================
-- REO DEVELOPMENT - REO MAIL v0.7.0
-- PREPARED OUTGOING MAIL / SIGNATURE RECEIPTS
-- ============================================================
local function cid(src) return REO_MAIL.Server.GetCharacterId and REO_MAIL.Server.GetCharacterId(src) end
local function cname(src) return (REO_MAIL.Server.GetCharacterDisplayName and REO_MAIL.Server.GetCharacterDisplayName(src)) or 'Unknown Sender' end
local function tracking() return ('REO-LTR-%s-%06d'):format(os.time(), math.random(0,999999)) end
local function item(name) return Config.PreparedMail.items[name] end

lib.callback.register('reo_mail:server:getPostalSupplyCatalog', function(source)
    local cfg = Config.PostalSupplies or {}
    local catalog = {}
    for _, supply in ipairs(cfg.items or {}) do
        catalog[#catalog + 1] = {
            key = supply.key,
            label = supply.label,
            description = supply.description,
            price = tonumber(supply.price) or 0,
            image = supply.image
        }
    end
    return { success = true, items = catalog, maxQuantity = cfg.maxQuantityPerItem or 50 }
end)

lib.callback.register('reo_mail:server:purchasePostalSupplies', function(source, order)
    local cfg = Config.PostalSupplies or {}
    local byKey = {}
    for _, supply in ipairs(cfg.items or {}) do byKey[supply.key] = supply end

    local requested = {}
    local total = 0
    local maxQty = tonumber(cfg.maxQuantityPerItem) or 50
    for _, row in ipairs(type(order) == 'table' and order or {}) do
        local supply = byKey[tostring(row.key or '')]
        local qty = math.floor(tonumber(row.quantity) or 0)
        if supply and qty > 0 then
            if qty > maxQty then return { success=false, reason='quantity_too_high' } end
            requested[#requested + 1] = { supply=supply, quantity=qty }
            total = total + ((tonumber(supply.price) or 0) * qty)
        end
    end
    if #requested == 0 then return { success=false, reason='empty_order' } end

    for _, row in ipairs(requested) do
        if not exports.ox_inventory:CanCarryItem(source, row.supply.item, row.quantity, row.supply.metadata) then
            return { success=false, reason='inventory_full' }
        end
    end

    local cash = REO_MAIL.Server.GetCash and REO_MAIL.Server.GetCash(source) or 0
    if cash < total then return { success=false, reason='not_enough_cash', total=total, cash=cash } end
    if total > 0 and (not REO_MAIL.Server.RemoveCash or not REO_MAIL.Server.RemoveCash(source, total, 'reo-mail-postal-supplies')) then
        return { success=false, reason='payment_failed' }
    end

    local added = {}
    for _, row in ipairs(requested) do
        local ok = exports.ox_inventory:AddItem(source, row.supply.item, row.quantity, row.supply.metadata)
        if not ok then
            for _, rollback in ipairs(added) do
                exports.ox_inventory:RemoveItem(source, rollback.item, rollback.quantity, rollback.metadata)
            end
            if total > 0 and REO_MAIL.Server.AddCash then REO_MAIL.Server.AddCash(source, total, 'reo-mail-postal-supplies-refund') end
            return { success=false, reason='inventory_failed' }
        end
        added[#added + 1] = { item=row.supply.item, quantity=row.quantity, metadata=row.supply.metadata }
    end

    return { success=true, total=total }
end)

lib.callback.register('reo_mail:server:prepareOutgoingLetter', function(source, slotId, data)
    local slot=exports.ox_inventory:GetSlot(source,slotId)
    if not slot or slot.name~=item('blankLetter') then return {success=false,reason='invalid_letter'} end
    if not data or not data.recipientCharacterId or not data.body or data.body=='' then return {success=false,reason='missing_fields'} end
    local md={
        senderCharacterId=cid(source), senderName=cname(source), recipientCharacterId=data.recipientCharacterId,
        recipientName=data.recipientName or 'Recipient', subject=data.subject or 'Letter', body=data.body,
        prepared=true, trackingNumber=tracking(), label='Prepared Letter',
        description=('To: %s | Ready to mail'):format(data.recipientName or 'Recipient')
    }
    if not exports.ox_inventory:RemoveItem(source,item('blankLetter'),1,nil,slotId) then return {success=false,reason='remove_failed'} end
    local ok=exports.ox_inventory:AddItem(source,item('outgoingLetter'),1,md)
    if not ok then exports.ox_inventory:AddItem(source,item('blankLetter'),1); return {success=false,reason='inventory_failed'} end
    return {success=true,trackingNumber=md.trackingNumber}
end)

lib.callback.register('reo_mail:server:addLetterToEnvelope', function(source, envelopeSlot, letterSlot)
    local env=exports.ox_inventory:GetSlot(source,envelopeSlot); local letter=exports.ox_inventory:GetSlot(source,letterSlot)
    if not env or env.name~=item('openEnvelope') or not letter or letter.name~=item('outgoingLetter') then return {success=false,reason='invalid_items'} end
    local emd=env.metadata or {}; local contents=emd.contents or {}
    if #contents >= (Config.PreparedMail.maxEnvelopeDocuments or 5) then return {success=false,reason='full'} end
    local lmd=letter.metadata or {}; contents[#contents+1]=lmd
    if not exports.ox_inventory:RemoveItem(source,item('outgoingLetter'),1,lmd,letterSlot) then return {success=false,reason='remove_failed'} end
    emd.contents=contents; emd.documentCount=#contents; emd.label='Open Mailing Envelope'; emd.description=('%s document(s) inside'):format(#contents)
    exports.ox_inventory:SetMetadata(source,envelopeSlot,emd)
    return {success=true,count=#contents}
end)

lib.callback.register('reo_mail:server:getOutgoingEnvelopeContents', function(source, envelopeSlot)
    local env = exports.ox_inventory:GetSlot(source, envelopeSlot)
    if not env or env.name ~= item('openEnvelope') then
        return { success = false, reason = 'invalid_envelope', contents = {}, count = 0 }
    end

    local md = env.metadata or {}
    local contents = md.contents or {}
    local result = {}

    for index, doc in ipairs(contents) do
        result[#result + 1] = {
            index = index,
            subject = doc.subject or 'Letter',
            recipientName = doc.recipientName or 'Unknown',
            senderName = doc.senderName or 'Unknown Sender',
            trackingNumber = doc.trackingNumber,
            description = doc.description
        }
    end

    return {
        success = true,
        contents = result,
        count = #contents,
        max = Config.PreparedMail.maxEnvelopeDocuments or 5
    }
end)

lib.callback.register('reo_mail:server:removeLetterFromEnvelope', function(source, envelopeSlot, documentIndex)
    local env = exports.ox_inventory:GetSlot(source, envelopeSlot)
    if not env or env.name ~= item('openEnvelope') then
        return { success = false, reason = 'invalid_envelope' }
    end

    local md = env.metadata or {}
    local contents = md.contents or {}
    local index = tonumber(documentIndex)
    if not index or not contents[index] then
        return { success = false, reason = 'invalid_document' }
    end

    local document = contents[index]
    local added = exports.ox_inventory:AddItem(source, item('outgoingLetter'), 1, document)
    if not added then
        return { success = false, reason = 'inventory_full' }
    end

    table.remove(contents, index)
    md.contents = contents
    md.documentCount = #contents
    md.label = 'Open Mailing Envelope'
    md.description = ('%s document(s) inside'):format(#contents)
    exports.ox_inventory:SetMetadata(source, envelopeSlot, md)

    return { success = true, count = #contents }
end)

lib.callback.register('reo_mail:server:sealOutgoingEnvelope', function(source,envelopeSlot)
    local env=exports.ox_inventory:GetSlot(source,envelopeSlot)
    if not env or env.name~=item('openEnvelope') then return {success=false,reason='invalid_envelope'} end
    local md=env.metadata or {}; local contents=md.contents or {}
    if #contents<1 then return {success=false,reason='empty'} end
    local recipientId,recipientName=contents[1].recipientCharacterId,contents[1].recipientName
    for _,doc in ipairs(contents) do if doc.recipientCharacterId~=recipientId then return {success=false,reason='mixed_recipients'} end end
    -- Preserve the original open-envelope metadata before creating the sealed copy.
    -- ox_inventory can fail strict metadata matching on nested tables (contents), so
    -- remove the validated item from its exact slot without supplying metadata.
    local originalMd = env.metadata or {}
    local sealedMd = {}
    for key, value in pairs(originalMd) do sealedMd[key] = value end

    sealedMd.recipientCharacterId=recipientId; sealedMd.recipientName=recipientName; sealedMd.sealed=true; sealedMd.trackingNumber=tracking(); sealedMd.label='Prepared Sealed Envelope'; sealedMd.description=('To: %s | %d document(s) | Ready to mail'):format(recipientName or 'Recipient',#contents)

    local removed = exports.ox_inventory:RemoveItem(source, item('openEnvelope'), 1, nil, envelopeSlot)
    if not removed then return {success=false,reason='remove_failed'} end

    local ok = exports.ox_inventory:AddItem(source, item('sealedEnvelope'), 1, sealedMd)
    if not ok then
        -- Roll back safely if the sealed item cannot be added.
        exports.ox_inventory:AddItem(source, item('openEnvelope'), 1, originalMd)
        return {success=false,reason='inventory_failed'}
    end
    return {success=true,trackingNumber=md.trackingNumber}
end)

local function deposit(source,slotId,opts)
    local slot=exports.ox_inventory:GetSlot(source,slotId); if not slot then return {success=false,reason='missing_item'} end
    local allowed=slot.name==item('outgoingLetter') or slot.name==item('sealedEnvelope')
    if not allowed then return {success=false,reason='not_prepared_mail'} end
    local md=slot.metadata or {}; local docs=slot.name==item('outgoingLetter') and {md} or (md.contents or {})
    if #docs<1 then return {success=false,reason='empty'} end
    local service=(Config.PreparedMail.services or {})[opts.service or 'standard']; if not service then return {success=false,reason='bad_service'} end
    local signature=opts.signature==true; local anonymous=opts.anonymous==true
    local fee=(service.fee or 0)+(signature and (Config.PreparedMail.signatureFee or 0) or 0)+(anonymous and (Config.PreparedMail.anonymousFee or 0) or 0)
    -- Existing Qbox bridge owns payment behavior for packages; prepared mail is free in dev mode.
    if fee>0 and not Config.PreparedMail.freeDevelopmentSupplies then return {success=false,reason='payment_not_configured',cost=fee} end
    local due=os.date('%Y-%m-%d %H:%M:%S',os.time()+(service.minutes*60)); local ids={}
    for _,doc in ipairs(docs) do
        local tr=doc.trackingNumber or tracking()
        local id=MySQL.insert.await([[INSERT INTO reo_mail_items
            (tracking_number,sender_type,sender_id,sender_name,recipient_character_id,recipient_name,mail_type,letter_template,subject,body,status,destination_type,destination_id,shipping_service,delivery_due_at,signature_required,anonymous_sender)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)]],{
            tr,'player',cid(source),cname(source),doc.recipientCharacterId,doc.recipientName,'letter','basic',doc.subject,doc.body,'in_transit','po_box','auto',opts.service or 'standard',due,signature and 1 or 0,anonymous and 1 or 0
        })
        ids[#ids+1]=id
    end
    if not exports.ox_inventory:RemoveItem(source,slot.name,1,slot.metadata,slotId) then return {success=false,reason='remove_failed'} end
    return {success=true,count=#docs,cost=fee,dueAt=due,service=service.label,signature=signature,anonymous=anonymous}
end
lib.callback.register('reo_mail:server:depositPreparedMail',deposit)

lib.callback.register('reo_mail:server:getSignatureReceipts', function(source)
    local characterId=cid(source); if not characterId then return {} end
    return MySQL.query.await([[SELECT tracking_number,recipient_name,signed_by_name,signed_at,subject FROM reo_mail_items
        WHERE sender_id=? AND signed_at IS NOT NULL ORDER BY signed_at DESC LIMIT 30]],{characterId}) or {}
end)

CreateThread(function()
    while true do
        Wait(30000)
        MySQL.update.await([[UPDATE reo_mail_items SET status=CASE WHEN signature_required=1 THEN 'awaiting_signature' ELSE 'ready' END,
            delivered_at=CASE WHEN signature_required=0 THEN CURRENT_TIMESTAMP ELSE delivered_at END
            WHERE status='in_transit' AND delivery_due_at IS NOT NULL AND delivery_due_at<=CURRENT_TIMESTAMP]])
    end
end)
