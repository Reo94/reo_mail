const reader = document.getElementById('reader');
const set = (id, value) => document.getElementById(id).textContent = value || '';

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => null);
}

async function postJson(name, data = {}) {
    try {
        const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data)
        });
        if (!response || !response.ok) return null;
        return await response.json();
    } catch (_) {
        return null;
    }
}


function formatDate(value) {
    if (!value) return '';
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? String(value) : date.toLocaleDateString('en-US', {
        year: 'numeric', month: 'long', day: 'numeric'
    });
}

function closeLetter() {
    reader.classList.add('hidden');
    post('closeLetter');
}

function announceReady() {
    post('readerReady');
}

window.addEventListener('DOMContentLoaded', announceReady);



window.addEventListener('message', (event) => {
    const message = event.data || {};

    if (message.action === 'pingReader') {
        announceReady();
        return;
    }

    if (message.action === 'setMouseMode') {
        document.body.classList.toggle('mouse-enabled', message.enabled === true);
        return;
    }

    if (message.action === 'openLetter') {
        const letter = message.letter || {};
        set('recipient', letter.recipientName || 'Recipient');
        set('subject', letter.subject || 'Letter');
        set('body', letter.body || '');
        set('sender', letter.senderName || 'Unknown Sender');
        set('tracking', letter.trackingNumber ? `Tracking: ${letter.trackingNumber}` : '');
        set('date', formatDate(letter.createdAt));
        reader.classList.remove('hidden');
        return;
    }

    if (message.action === 'closeLetter') {
        reader.classList.add('hidden');
    }
});

document.getElementById('close').addEventListener('click', closeLetter);
document.addEventListener('keydown', (event) => {
    // Recipient Directory: ESC closes it. Backspace MUST remain available for typing/editing names.
    if (!directory.classList.contains('hidden')) {
        if (event.key !== 'Escape') return;
        event.preventDefault();
        event.stopPropagation();
        closeDirectory();
        return;
    }

    // Physical letter reader retains ESC and Backspace as close keys.
    if (!reader.classList.contains('hidden') && (event.key === 'Escape' || event.key === 'Backspace')) {
        event.preventDefault();
        event.stopPropagation();
        closeLetter();
    }
});

// ============================================================
// REO MAIL v0.4.0 - LIVE RECIPIENT / BUSINESS DIRECTORY
// ============================================================
const directory = document.getElementById('directory');
const recipientSearch = document.getElementById('recipientSearch');
const recipientResults = document.getElementById('recipientResults');
const businessResults = document.getElementById('businessResults');
let searchTimer = null;

function resultButton(item, type) {
    const button = document.createElement('button');
    button.className = 'directory-result';
    const left = document.createElement('div');
    const name = document.createElement('strong');
    name.textContent = item.name || 'Unknown';
    const meta = document.createElement('span');
    meta.textContent = type === 'business' ? 'Business mail recipient' : (item.postalLabel || (item.poBox ? `PO Box ${item.poBox}` : 'Postal profile unavailable'));
    left.append(name, meta);
    button.append(left);
    button.addEventListener('click', () => post('selectDirectoryRecipient', { type, item }));
    return button;
}

function renderPeople(items) {
    recipientResults.innerHTML = '';
    if (!items || !items.length) {
        recipientResults.innerHTML = '<div class="directory-empty">No matching characters.</div>';
        return;
    }
    items.forEach(item => recipientResults.appendChild(resultButton(item, 'person')));
}
function renderBusinesses(items) {
    businessResults.innerHTML = '';
    if (!items || !items.length) {
        businessResults.innerHTML = '<div class="directory-empty">No businesses are configured for mail yet.</div>';
        return;
    }
    items.forEach(item => businessResults.appendChild(resultButton(item, 'business')));
}
function closeDirectory() { directory.classList.add('hidden'); post('closeDirectory'); }

document.getElementById('directoryClose').addEventListener('click', closeDirectory);
document.querySelectorAll('.directory-tabs .tab').forEach(btn => btn.addEventListener('click', () => {
    document.querySelectorAll('.directory-tabs .tab').forEach(x => x.classList.remove('active'));
    btn.classList.add('active');
    const people = btn.dataset.tab === 'people';
    document.getElementById('peoplePanel').classList.toggle('hidden', !people);
    document.getElementById('businessPanel').classList.toggle('hidden', people);
}));
let searchSequence = 0;
recipientSearch.addEventListener('input', () => {
    clearTimeout(searchTimer);
    const query = recipientSearch.value.trim();
    const sequence = ++searchSequence;

    if (!query.length) {
        renderPeople([]);
        return;
    }

    searchTimer = setTimeout(async () => {
        const payload = await postJson('directorySearch', { query });
        if (sequence !== searchSequence) return; // Ignore stale responses while typing quickly.
        renderPeople(payload && Array.isArray(payload.results) ? payload.results : []);
    }, 180);
});


window.addEventListener('message', (event) => {
    const m = event.data || {};
    if (m.action === 'openDirectory') {
        directory.classList.remove('hidden');
        renderPeople(m.online || []);
        renderBusinesses(m.businesses || []);
        recipientSearch.value = '';
        setTimeout(() => recipientSearch.focus(), 30);
    } else if (m.action === 'directoryResults') {
        renderPeople(m.results || []);
    } else if (m.action === 'closeDirectory') {
        directory.classList.add('hidden');
    }
});


// ============================================================
// REO DEVELOPMENT - POSTAL TERMINAL v0.8.0
// ============================================================
const postalTerminal = document.getElementById('postalTerminal');
const terminalClose = document.getElementById('terminalClose');
const terminalTime = document.getElementById('terminalTime');
const terminalDate = document.getElementById('terminalDate');
const terminalStation = document.getElementById('terminalStation');
const terminalHome = document.getElementById('terminalHome');
const postalSupplyShop = document.getElementById('postalSupplyShop');
const supplyItems = document.getElementById('supplyItems');
const supplyTotal = document.getElementById('supplyTotal');
const supplyPurchase = document.getElementById('supplyPurchase');
const supplyBack = document.getElementById('supplyBack');
let supplyCatalog = [];
let supplyQuantities = {};
let supplyMaxQuantity = 50;
let terminalClockTimer = null;

function updateTerminalClock() {
    const now = new Date();
    terminalTime.textContent = now.toLocaleTimeString('en-US', { hour12: false });
    terminalDate.textContent = now.toLocaleDateString('en-US', { weekday:'short', month:'short', day:'2-digit', year:'numeric' }).toUpperCase();
}
function openPostalTerminal(message) {
    terminalHome.classList.remove('hidden');
    postalSupplyShop.classList.add('hidden');
    if (terminalServicePage) terminalServicePage.classList.add('hidden');
    if (terminalStation) terminalStation.textContent = (message.station || 'San Andreas Postal Service').toUpperCase();
    postalTerminal.classList.remove('hidden');
    postalTerminal.setAttribute('aria-hidden', 'false');
    updateTerminalClock();
    clearInterval(terminalClockTimer);
    terminalClockTimer = setInterval(updateTerminalClock, 1000);
}
function closePostalTerminalUi(notifyGame = true) {
    postalTerminal.classList.add('hidden');
    postalTerminal.setAttribute('aria-hidden', 'true');
    clearInterval(terminalClockTimer);
    terminalClockTimer = null;
    if (notifyGame) post('closePostalTerminal');
}
terminalClose.addEventListener('click', () => closePostalTerminalUi(true));
const terminalServicePage = document.getElementById('terminalServicePage');
const serviceBack = document.getElementById('serviceBack');
const serviceContinue = document.getElementById('serviceContinue');
const serviceDynamic = document.getElementById('serviceDynamic');
const serviceNumber = document.getElementById('serviceNumber');
const serviceTitle = document.getElementById('serviceTitle');
const serviceHeading = document.getElementById('serviceHeading');
const serviceDescription = document.getElementById('serviceDescription');
const serviceStatus = document.getElementById('serviceStatus');
let pendingTerminalAction = null;

const servicePages = {
    prepared_mail: { number:'01', title:'SEND MAIL', description:'Deposit prepared letters and sealed envelopes into the San Andreas postal network.', status:'PREPARED MAIL' },
    package_drop: { number:'02', title:'SEND PACKAGE', description:'Prepare and submit addressed shipping boxes for delivery.', status:'PACKAGE SERVICES' },
    package_pickup: { number:'03', title:'PICK UP', description:'Collect mail and packages currently waiting for you at the postal counter.', status:'COUNTER SERVICE' },
    tracking: { number:'04', title:'TRACKING', description:'Review shipment tracking information, service level and delivery status.', status:'LIVE TRACKING' },
    mailbox: { number:'06', title:'MY PO BOX', description:'Review your postal address and mail currently associated with your character.', status:'POSTAL ADDRESS' },
    recovery: { number:'07', title:'LOST MAIL', description:'Recover eligible physical mail through the REO Mail recovery service.', status:'RECOVERY SERVICE' },
    legacy_letter: { number:'08', title:'LEGACY LETTER', description:'Original direct-send letter workflow retained for development compatibility.', status:'DEVELOPMENT' }
};

function showTerminalHome() {
    postalSupplyShop.classList.add('hidden');
    terminalServicePage.classList.add('hidden');
    terminalHome.classList.remove('hidden');
    pendingTerminalAction = null;
}

function showServicePage(action) {
    const page = servicePages[action];
    if (!page) return;
    pendingTerminalAction = action;
    terminalHome.classList.add('hidden');
    postalSupplyShop.classList.add('hidden');
    terminalServicePage.classList.remove('hidden');
    serviceNumber.textContent = page.number;
    serviceTitle.textContent = page.title;
    serviceHeading.textContent = page.title;
    serviceDescription.textContent = page.description;
    serviceStatus.textContent = page.status; serviceDynamic.innerHTML=''; setTimeout(loadServiceData,0);
}

serviceBack.addEventListener('click', showTerminalHome);
async function loadServiceData(){
 if(!pendingTerminalAction)return; serviceContinue.disabled=true; serviceDynamic.innerHTML='<div class="terminal-empty">LOADING POSTAL DATA...</div>';
 const r=await postJson('postalTerminalData',{action:pendingTerminalAction}); renderServiceData(r||{}); serviceContinue.disabled=false;
}
function renderServiceData(r){ const items=Array.isArray(r.items)?r.items:[]; serviceDynamic.innerHTML=''; if(!items.length){serviceDynamic.innerHTML='<div class="terminal-empty">'+(r.empty||'NO ITEMS AVAILABLE')+'</div>';return;} items.forEach(x=>{const el=document.createElement('article');el.className='terminal-list-card';el.innerHTML='<div><span class="terminal-badge">'+(x.badge||'POSTAL ITEM')+'</span><strong>'+esc(x.title||'Item')+'</strong><small>'+esc(x.description||'')+'</small></div>'+(x.action?'<button>'+esc(x.actionLabel||'SELECT')+'</button>':''); if(x.action)el.querySelector('button').onclick=async()=>{const out=await postJson('postalTerminalItemAction',{action:x.action,id:x.id,slot:x.slot}); if(out&&out.refresh!==false)loadServiceData();};serviceDynamic.appendChild(el);});}
function esc(v){return String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));}
serviceContinue.textContent='REFRESH'; serviceContinue.addEventListener('click',loadServiceData);

document.querySelectorAll('.service-card[data-action]').forEach(button => {
    button.addEventListener('click', () => {
        const action = button.dataset.action;
        if (action === 'supplies') {
            button.disabled = true;
            post('postalTerminalAction', { action }).finally(() => { button.disabled = false; });
            return;
        }
        showServicePage(action);
    });
});

function money(value) { return '$' + Number(value || 0).toLocaleString('en-US'); }
function updateSupplyTotal() {
    let total = 0, count = 0;
    supplyCatalog.forEach(item => {
        const qty = supplyQuantities[item.key] || 0;
        total += qty * Number(item.price || 0); count += qty;
        const q = document.querySelector(`[data-supply-qty="${item.key}"]`);
        if (q) q.textContent = qty;
        const line = document.querySelector(`[data-supply-line="${item.key}"]`);
        if (line) line.textContent = money(qty * Number(item.price || 0));
    });
    supplyTotal.textContent = money(total);
    supplyPurchase.disabled = count < 1;
}
function renderSupplyShop(catalog) {
    supplyCatalog = (catalog && catalog.items) || [];
    supplyMaxQuantity = Number((catalog && catalog.maxQuantity) || 50);
    supplyQuantities = {};
    supplyItems.innerHTML = '';
    supplyCatalog.forEach(item => {
        supplyQuantities[item.key] = 0;
        const row = document.createElement('article');
        row.className = 'supply-row supply-card';
        const imageName = item.image || '';
        row.innerHTML = `<div class="supply-art"><img src="./images/${esc(imageName)}" alt="${esc(item.label || 'Postal supply')}" draggable="false"><span class="image-fallback">REO MAIL</span></div><div class="supply-info"><strong>${esc(item.label)}</strong><small>${esc(item.description || '')}</small><span>${money(item.price)} EACH</span></div><div class="supply-buy"><div class="qty-control"><button data-minus="${item.key}">−</button><b data-supply-qty="${item.key}">0</b><button data-plus="${item.key}">+</button></div><div class="line-total" data-supply-line="${item.key}">$0</div></div>`;
        const art = row.querySelector('.supply-art img');
        art.addEventListener('load', () => row.querySelector('.image-fallback').classList.add('hidden'));
        art.addEventListener('error', () => { art.classList.add('hidden'); row.querySelector('.image-fallback').classList.remove('hidden'); });
        supplyItems.appendChild(row);
    });
    supplyItems.querySelectorAll('[data-minus]').forEach(b => b.addEventListener('click', () => { const k=b.dataset.minus; supplyQuantities[k]=Math.max(0,(supplyQuantities[k]||0)-1); updateSupplyTotal(); }));
    supplyItems.querySelectorAll('[data-plus]').forEach(b => b.addEventListener('click', () => { const k=b.dataset.plus; supplyQuantities[k]=Math.min(supplyMaxQuantity,(supplyQuantities[k]||0)+1); updateSupplyTotal(); }));
    terminalHome.classList.add('hidden'); postalSupplyShop.classList.remove('hidden'); updateSupplyTotal();
}
supplyBack.addEventListener('click', showTerminalHome);
supplyPurchase.addEventListener('click', async () => {
    const order = Object.entries(supplyQuantities).filter(([,quantity]) => quantity > 0).map(([key,quantity]) => ({key, quantity}));
    if (!order.length) return;
    supplyPurchase.disabled = true; supplyPurchase.textContent = 'PROCESSING...';
    try {
        const result = await postJson('purchasePostalSupplies', {order});
        if (result && result.success) { supplyCatalog.forEach(i => supplyQuantities[i.key]=0); updateSupplyTotal(); }
    } finally { supplyPurchase.textContent = 'PURCHASE'; updateSupplyTotal(); }
});

window.addEventListener('message', (event) => {
    const message = event.data || {};
    if (message.action === 'openPostalTerminal') openPostalTerminal(message);
    if (message.action === 'closePostalTerminal') closePostalTerminalUi(false);
    if (message.action === 'setPostalTerminalMouse') postalTerminal.classList.toggle('mouse-active', message.enabled === true);
    if (message.action === 'openPostalSupplyShop') renderSupplyShop(message.catalog || {});
});
// ESC is handled natively in client Lua so it remains a failsafe even if NUI JavaScript fails.


// v0.11: when the browser owns focus, ALT hands focus back to gameplay.
// When gameplay owns focus, client Lua handles ALT and gives focus to NUI.
document.addEventListener('keydown', (event) => {
    if (postalTerminal.classList.contains('hidden')) return;
    if (event.key === 'Alt') {
        event.preventDefault();
        post('togglePostalFocus');
    } else if (event.key === 'Escape') {
        event.preventDefault();
        post('closePostalTerminal');
    }
});
