-- ============================================================
-- REO DEVELOPMENT - REO MAIL v0.7.0
-- PREPARED MAIL UI + VANILLA PUBLIC POST BOXES
-- ============================================================
local function notify(msg,t) lib.notify({title='REO Mail',description=msg,type=t or 'inform'}) end
local function slotFromData(data) return data and (data.slot or data.slotId) end

local function chooseServiceAndDeposit(slotId, sourceLabel)
    local services={}
    for id,cfg in pairs(Config.PreparedMail.services or {}) do services[#services+1]={value=id,label=('%s - %d min%s'):format(cfg.label,cfg.minutes,(cfg.fee or 0)>0 and (' - $'..cfg.fee) or ' - FREE')} end
    table.sort(services,function(a,b) return a.label<b.label end)
    local input=lib.inputDialog(sourceLabel or 'Deposit Prepared Mail',{
        {type='select',label='Delivery Service',options=services,required=true,default='standard'},
        {type='checkbox',label=('Signature Required (+$%s)'):format(Config.PreparedMail.signatureFee or 0)},
        {type='checkbox',label=('Anonymous Sender (+$%s)'):format(Config.PreparedMail.anonymousFee or 0)}
    })
    if not input then return end
    local result=lib.callback.await('reo_mail:server:depositPreparedMail',false,slotId,{service=input[1],signature=input[2]==true,anonymous=input[3]==true})
    if result and result.success then notify(('%d piece(s) accepted. %s delivery. Estimated processing: %s'):format(result.count,result.service,result.dueAt),'success') else notify('Unable to deposit mail: '..tostring(result and result.reason or 'unknown'),'error') end
end

local function preparedInventoryMenu(sourceLabel)
    local inv=exports.ox_inventory:GetPlayerItems() or {}; local opts={}
    for _,s in pairs(inv) do
        if s.name==Config.PreparedMail.items.outgoingLetter or s.name==Config.PreparedMail.items.sealedEnvelope then
            local md=s.metadata or {}; opts[#opts+1]={title=md.label or 'Prepared Mail',description=md.description or md.recipientName or '',icon='envelope',onSelect=function() chooseServiceAndDeposit(s.slot,sourceLabel) end}
        end
    end
    if #opts==0 then opts[1]={title='No Prepared Mail',description='Prepare a letter or sealed envelope first.',disabled=true} end
    lib.registerContext({id='reo_prepared_drop',title=sourceLabel or 'Prepared Mail Drop-Off',options=opts}); lib.showContext('reo_prepared_drop')
end

exports('writeOutgoingLetter',function(data,slot)
    local slotId=slotFromData(data) or slot
    local q=lib.inputDialog('Write Letter',{{type='input',label='Recipient Name Search',required=true,min=1},{type='input',label='Subject',required=true,max=100},{type='textarea',label='Letter',required=true,min=1,max=4000}}); if not q then return end
    local results=lib.callback.await('reo_mail:server:searchRecipients',false,q[1]) or {}
    local opts={}; for _,r in ipairs(results) do opts[#opts+1]={title=r.name,description=r.poBox and ('PO Box '..r.poBox) or nil,onSelect=function()
        local res=lib.callback.await('reo_mail:server:prepareOutgoingLetter',false,slotId,{recipientCharacterId=r.characterId,recipientName=r.name,subject=q[2],body=q[3]})
        notify(res and res.success and 'Letter prepared. Mail it by itself or place it in an envelope.' or 'Unable to prepare letter.',res and res.success and 'success' or 'error')
    end} end
    lib.registerContext({id='reo_letter_recipient',title='Choose Recipient',options=opts}); lib.showContext('reo_letter_recipient')
end)

exports('useOutgoingLetter',function(data,slot) local sid=slotFromData(data) or slot; lib.registerContext({id='reo_out_letter',title='Prepared Letter',options={{title='Mail This Letter',description='Send without an envelope.',onSelect=function() chooseServiceAndDeposit(sid,'Mail Letter') end},{title='Place in Envelope',description='Use an Open Mailing Envelope and choose this letter from its menu.',disabled=true}}}); lib.showContext('reo_out_letter') end)

local function openOutgoingEnvelopeMenu(envSlot)
    local state = lib.callback.await('reo_mail:server:getOutgoingEnvelopeContents', false, envSlot)
    if not state or not state.success then
        notify('Unable to inspect envelope: '..tostring(state and state.reason or 'unknown'), 'error')
        return
    end

    local count = state.count or 0
    local maxDocs = state.max or (Config.PreparedMail.maxEnvelopeDocuments or 5)
    local opts = {}

    -- Add prepared letters while there is room in the envelope.
    local inv = exports.ox_inventory:GetPlayerItems() or {}
    local available = {}
    for _, s in pairs(inv) do
        if s.name == Config.PreparedMail.items.outgoingLetter then
            available[#available + 1] = s
        end
    end

    if count < maxDocs then
        if #available > 0 then
            for _, s in ipairs(available) do
                local letterSlot = s.slot
                local md = s.metadata or {}
                opts[#opts + 1] = {
                    title = ('Add Letter: %s'):format(md.subject or 'Letter'),
                    description = ('To: %s'):format(md.recipientName or 'Unknown'),
                    icon = 'plus',
                    onSelect = function()
                        local r = lib.callback.await('reo_mail:server:addLetterToEnvelope', false, envSlot, letterSlot)
                        if r and r.success then
                            notify(('Letter added. Envelope now contains %d/%d document(s).'):format(r.count, maxDocs), 'success')
                            openOutgoingEnvelopeMenu(envSlot)
                        else
                            notify('Unable to add: '..tostring(r and r.reason or 'unknown'), 'error')
                        end
                    end
                }
            end
        else
            opts[#opts + 1] = {
                title = 'Add Letter / Document',
                description = 'No prepared letters are currently available in your inventory.',
                icon = 'plus',
                disabled = true
            }
        end
    else
        opts[#opts + 1] = {
            title = ('Envelope Full (%d/%d)'):format(count, maxDocs),
            description = 'Remove a document before adding another.',
            icon = 'ban',
            disabled = true
        }
    end

    -- Always show what is physically inside the envelope.
    if count > 0 then
        for _, doc in ipairs(state.contents or {}) do
            local documentIndex = doc.index
            opts[#opts + 1] = {
                title = ('Inside #%d: %s'):format(documentIndex, doc.subject or 'Letter'),
                description = ('To: %s | Select to remove from envelope'):format(doc.recipientName or 'Unknown'),
                icon = 'file-lines',
                onSelect = function()
                    local confirm = lib.alertDialog({
                        header = 'Remove Letter From Envelope?',
                        content = ('Return **%s** for **%s** to your inventory?'):format(doc.subject or 'Letter', doc.recipientName or 'Unknown'),
                        centered = true,
                        cancel = true
                    })
                    if confirm ~= 'confirm' then
                        openOutgoingEnvelopeMenu(envSlot)
                        return
                    end
                    local r = lib.callback.await('reo_mail:server:removeLetterFromEnvelope', false, envSlot, documentIndex)
                    if r and r.success then
                        notify(('Letter removed. Envelope now contains %d/%d document(s).'):format(r.count, maxDocs), 'success')
                    else
                        notify('Unable to remove: '..tostring(r and r.reason or 'unknown'), 'error')
                    end
                    openOutgoingEnvelopeMenu(envSlot)
                end
            }
        end
    else
        opts[#opts + 1] = {
            title = 'Envelope Contents (0)',
            description = 'This envelope is empty.',
            icon = 'folder-open',
            disabled = true
        }
    end

    opts[#opts + 1] = {
        title = ('Seal Envelope (%d/%d)'):format(count, maxDocs),
        description = count > 0 and 'Locks the contents and prepares the envelope for drop-off.' or 'Add at least one letter before sealing.',
        icon = 'lock',
        disabled = count < 1,
        onSelect = function()
            local r = lib.callback.await('reo_mail:server:sealOutgoingEnvelope', false, envSlot)
            notify(r and r.success and 'Envelope sealed and ready to mail.' or ('Unable to seal: '..tostring(r and r.reason or 'unknown')), r and r.success and 'success' or 'error')
        end
    }

    lib.registerContext({
        id = 'reo_open_env',
        title = ('Open Mailing Envelope - %d/%d'):format(count, maxDocs),
        options = opts
    })
    lib.showContext('reo_open_env')
end

exports('useOpenOutgoingEnvelope', function(data, slot)
    openOutgoingEnvelopeMenu(slotFromData(data) or slot)
end)

exports('useOutgoingEnvelope',function(data,slot) chooseServiceAndDeposit(slotFromData(data) or slot,'Mail Sealed Envelope') end)

RegisterNetEvent('reo_mail:client:preparedMailDrop',function() preparedInventoryMenu('GoPostal - Prepared Mail Drop-Off') end)
RegisterNetEvent('reo_mail:client:terminalPreparedDeposit',function(slotId) chooseServiceAndDeposit(slotId,'REO Mail - Delivery Options') end)
RegisterNetEvent('reo_mail:client:postalSupplies',function() TriggerEvent('reo_mail:client:postalSuppliesShop') end)

-- Vanilla GTA post boxes: no hard-coded coordinate list is required. Every streamed
-- instance of either supported vanilla model becomes a usable REO Mail drop box.
CreateThread(function()
    if not Config.PublicMailboxes.enabled then return end
    local hashes={}; for _,m in ipairs(Config.PublicMailboxes.models or {}) do hashes[#hashes+1]=joaat(m) end
    while true do
        local wait=1200; local ped=PlayerPedId(); local pos=GetEntityCoords(ped); local nearest=nil; local best=Config.PublicMailboxes.scanRadius or 2.2
        for _,h in ipairs(hashes) do local obj=GetClosestObjectOfType(pos.x,pos.y,pos.z,best,h,false,false,false); if obj and obj~=0 then local d=#(pos-GetEntityCoords(obj)); if d<best then best=d; nearest=obj end end end
        if nearest then wait=0; lib.showTextUI('[E] Deposit Prepared REO Mail'); if IsControlJustReleased(0,38) then lib.hideTextUI(); preparedInventoryMenu('Public Mailbox - Letter Drop-Off'); Wait(500) end else if lib.isTextUIOpen() then lib.hideTextUI() end end
        Wait(wait)
    end
end)

RegisterCommand('reomailsupplies',function() TriggerEvent('reo_mail:client:postalSupplies') end,false)
