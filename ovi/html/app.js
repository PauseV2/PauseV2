// ============================================================
// OVI NUI app. Pure vanilla JS - no build step, no frameworks. Talks to
// the client resource via the standard FiveM NUI fetch callback pattern.
// Trust/loyalty bar scales below are cosmetic display assumptions
// (trust -100..100, loyalty 0..100) - the real clamps live server side
// in config/trust.lua and are never enforced here.
// ============================================================

(function () {
    const resourceName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'ovi';

    function post(name, data) {
        return fetch(`https://${resourceName}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }

    const S = {
        booted: false,
        theme: {},
        pinLength: 4,
        enteredPin: '',
        phone: null,
        contacts: [],
        messages: [],
        deliveries: [],
        notes: [],
        gpsLogs: [],
        offers: {}, // [offerId] = { contactId, drug, quantity, price }
        selectedContactId: null,
        activeTab: 'contacts',
        tabsCfg: {},
        networkRaided: false,
        networkCfg: {},
    };

    const app = document.getElementById('app');
    const screens = {
        pin: document.getElementById('screen-pin'),
        boot: document.getElementById('screen-boot'),
        dashboard: document.getElementById('screen-dashboard'),
    };

    function showApp() { app.classList.remove('hidden'); }
    function hideApp() { app.classList.add('hidden'); }

    // status bar clock is cosmetic (wall clock, not the in-game clock)
    function updateStatusClock() {
        const el = document.getElementById('status-time');
        if (!el) return;
        const now = new Date();
        el.textContent = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
    }
    updateStatusClock();
    setInterval(updateStatusClock, 15000);

    function showScreen(name) {
        Object.values(screens).forEach((el) => el.classList.add('hidden'));
        screens[name].classList.remove('hidden');
    }

    function applyTheme(theme) {
        if (!theme) return;
        const root = document.documentElement.style;
        root.setProperty('--bg', theme.background);
        root.setProperty('--panel', theme.panel);
        root.setProperty('--accent', theme.accent);
        root.setProperty('--accent-bright', theme.accentBright);
        root.setProperty('--danger', theme.danger);
        root.setProperty('--text', theme.text);
        root.setProperty('--text-muted', theme.textMuted);
        root.setProperty('--border', theme.border);
    }

    function escapeHtml(str) {
        const div = document.createElement('div');
        div.textContent = str == null ? '' : String(str);
        return div.innerHTML;
    }

    function timeAgo(tsLike) {
        if (!tsLike) return '';
        const t = (typeof tsLike === 'number') ? tsLike * 1000 : new Date(tsLike).getTime();
        const diff = Math.max(0, Date.now() - t);
        const mins = Math.floor(diff / 60000);
        if (mins < 1) return 'now';
        if (mins < 60) return `${mins}m ago`;
        const hours = Math.floor(mins / 60);
        if (hours < 24) return `${hours}h ago`;
        return `${Math.floor(hours / 24)}d ago`;
    }

    // ---------------------------------------------------------------- pin --

    function renderPinPad() {
        const titleEl = document.getElementById('pin-app-title');
        const subEl = document.getElementById('pin-app-subtitle');
        titleEl.textContent = S.theme.appName || 'OVI';
        subEl.textContent = S.theme.appSubtitle || '';

        const dots = document.getElementById('pin-dots');
        dots.innerHTML = '';
        for (let i = 0; i < S.pinLength; i++) {
            const d = document.createElement('div');
            d.className = 'pin-dot';
            dots.appendChild(d);
        }

        const pad = document.getElementById('pin-pad');
        pad.innerHTML = '';
        const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'clear', '0', 'back'];
        keys.forEach((k) => {
            const btn = document.createElement('div');
            btn.className = 'pin-key' + (k === 'clear' || k === 'back' ? ' wide' : '');
            btn.textContent = k === 'clear' ? 'CLR' : (k === 'back' ? 'DEL' : k);
            btn.addEventListener('click', () => handlePinKey(k));
            pad.appendChild(btn);
        });

        document.getElementById('pin-error').classList.add('hidden');
    }

    function updatePinDots() {
        const dots = document.querySelectorAll('#pin-dots .pin-dot');
        dots.forEach((d, i) => d.classList.toggle('filled', i < S.enteredPin.length));
    }

    function handlePinKey(k) {
        if (k === 'clear') {
            S.enteredPin = '';
        } else if (k === 'back') {
            S.enteredPin = S.enteredPin.slice(0, -1);
        } else if (S.enteredPin.length < S.pinLength) {
            S.enteredPin += k;
        }
        updatePinDots();

        if (S.enteredPin.length === S.pinLength) {
            post('submitPin', { pin: S.enteredPin });
        }
    }

    function onPinError() {
        S.enteredPin = '';
        updatePinDots();
        const err = document.getElementById('pin-error');
        err.classList.remove('hidden');
        // restart the shake animation
        err.style.animation = 'none';
        requestAnimationFrame(() => { err.style.animation = ''; });
    }

    // --------------------------------------------------------------- boot --

    function renderBoot(lines, totalMs) {
        const el = document.getElementById('boot-lines');
        if (!lines || lines.length === 0) { el.textContent = ''; return; }

        const perLine = Math.max(200, Math.floor(totalMs / lines.length));
        let i = 0;
        el.textContent = lines[0];
        const interval = setInterval(() => {
            i++;
            if (i >= lines.length) { clearInterval(interval); return; }
            el.textContent = lines[i];
        }, perLine);
    }

    // ---------------------------------------------------------- dashboard --

    function findContact(contactId) {
        return S.contacts.find((c) => c.contact_id === contactId);
    }

    function findDelivery(deliveryId) {
        return S.deliveries.find((d) => String(d.id) === String(deliveryId));
    }

    function activeDeliveryForContact(contactId) {
        return S.deliveries
            .filter((d) => d.contact_id === contactId && (d.status === 'pending' || d.status === 'accepted' || d.status === 'offer'))
            .sort((a, b) => (b.id > a.id ? 1 : -1))[0];
    }

    function renderTabbar() {
        const bar = document.getElementById('tabbar');
        bar.innerHTML = '';
        const labels = { contacts: 'Contacts', messages: 'Msgs', deliveries: 'Drops', connection: 'Net', vault: 'Vault', burn: 'Burn' };
        Object.keys(labels).forEach((key) => {
            if (!S.tabsCfg[key]) return;
            const btn = document.createElement('button');
            btn.className = 'tab-btn' + (S.activeTab === key ? ' active' : '');
            btn.textContent = labels[key];
            btn.addEventListener('click', () => { S.activeTab = key; renderAll(); });
            bar.appendChild(btn);
        });
    }

    function setSplit(isSplit) {
        document.getElementById('panel-list').classList.toggle('hidden', !isSplit);
    }

    function renderAll() {
        renderTabbar();
        const listEl = document.getElementById('panel-list');
        const detailEl = document.getElementById('panel-detail');
        listEl.innerHTML = '';
        detailEl.innerHTML = '';

        if (S.activeTab === 'contacts') {
            setSplit(true);
            renderContactsList(listEl);
            renderContactDetail(detailEl);
        } else if (S.activeTab === 'messages') {
            setSplit(true);
            renderConversationList(listEl);
            renderChatDetail(detailEl);
        } else if (S.activeTab === 'deliveries') {
            setSplit(true);
            renderDeliveriesList(listEl);
            renderDeliveryDetail(detailEl);
        } else if (S.activeTab === 'connection') {
            setSplit(false);
            renderConnectionPanel(detailEl);
        } else if (S.activeTab === 'vault') {
            setSplit(false);
            renderVaultPanel(detailEl);
        } else if (S.activeTab === 'burn') {
            setSplit(false);
            renderBurnPanel(detailEl);
        }
    }

    function statusTags(contact) {
        let html = '';
        if (contact.blacklisted) html += '<span class="tag blacklisted">BLACKLISTED</span>';
        if (contact.burned) html += '<span class="tag burned">BURNED</span>';
        if (contact.status && contact.status !== 'active') html += `<span class="tag ghost">${escapeHtml(contact.status.toUpperCase())}</span>`;
        return html;
    }

    function renderContactsList(listEl) {
        if (S.contacts.length === 0) {
            listEl.innerHTML = '<div class="empty-state">No contacts yet.</div>';
            return;
        }
        S.contacts.forEach((c) => {
            const item = document.createElement('div');
            item.className = 'list-item' + (S.selectedContactId === c.contact_id ? ' selected' : '');
            item.innerHTML = `
                <div class="name">${escapeHtml(c.full_name)} ${statusTags(c)}</div>
                <div class="meta">${escapeHtml(c.personality)} &middot; risk: ${escapeHtml(c.risk_level)}</div>
            `;
            item.addEventListener('click', () => { S.selectedContactId = c.contact_id; renderAll(); });
            listEl.appendChild(item);
        });
    }

    function trustBarPct(trust) {
        return Math.max(0, Math.min(100, ((Number(trust) + 100) / 200) * 100));
    }
    function loyaltyBarPct(loyalty) {
        return Math.max(0, Math.min(100, Number(loyalty)));
    }

    function renderContactDetail(detailEl) {
        const c = findContact(S.selectedContactId);
        if (!c) {
            detailEl.innerHTML = '<div class="empty-state">Select a contact to view details.</div>';
            return;
        }
        detailEl.innerHTML = `
            <div class="simple-panel">
                <h3 style="margin-top:0;color:var(--accent-bright)">${escapeHtml(c.full_name)} ${statusTags(c)}</h3>
                <div class="meta">Number: ${escapeHtml(c.number)}</div>
                <div class="meta">Personality: ${escapeHtml(c.personality)}</div>
                <div class="meta">Preferred: ${escapeHtml(c.preferred_drug)}</div>
                <div class="meta">Risk level: ${escapeHtml(c.risk_level)}</div>
                <div class="meta">Deliveries done: ${escapeHtml(c.deliveries_done)}</div>
                <div style="margin-top:10px">Trust</div>
                <div class="bar"><div class="bar-fill" style="width:${trustBarPct(c.trust)}%"></div></div>
                <div style="margin-top:8px">Loyalty</div>
                <div class="bar"><div class="bar-fill" style="width:${loyaltyBarPct(c.loyalty)}%"></div></div>
            </div>
        `;
    }

    function renderConversationList(listEl) {
        if (S.contacts.length === 0) {
            listEl.innerHTML = '<div class="empty-state">No conversations yet.</div>';
            return;
        }
        S.contacts.forEach((c) => {
            const lastMsg = S.messages.filter((m) => m.contact_id === c.contact_id).slice(-1)[0];
            const item = document.createElement('div');
            item.className = 'list-item' + (S.selectedContactId === c.contact_id ? ' selected' : '');
            item.innerHTML = `
                <div class="name">${escapeHtml(c.full_name)} ${statusTags(c)}</div>
                <div class="meta">${lastMsg ? escapeHtml(lastMsg.message).slice(0, 40) : 'No messages'}</div>
            `;
            item.addEventListener('click', () => { S.selectedContactId = c.contact_id; renderAll(); });
            listEl.appendChild(item);
        });
    }

    function renderDeliveryCard(delivery, contactId) {
        if (!delivery) return '';
        const isOffer = delivery.status === 'offer';
        const statusText = isOffer ? 'INCOMING OFFER' : delivery.status.toUpperCase();
        let actionHtml = '';

        if (isOffer) {
            actionHtml = `<button class="action-btn" id="btn-claim-offer">Claim</button>`;
        } else if (delivery.status === 'accepted') {
            actionHtml = `<button class="action-btn" id="btn-initiate-meet">Head to Meet</button>`;
        }

        return `
            <div class="delivery-card">
                <div class="row"><span>Drug</span><span>${escapeHtml(delivery.drug)}</span></div>
                <div class="row"><span>Quantity</span><span>${escapeHtml(delivery.quantity)}</span></div>
                <div class="row"><span>Price</span><span>$${escapeHtml(delivery.price)}</span></div>
                <div class="row"><span class="status">${escapeHtml(statusText)}</span></div>
                ${actionHtml ? `<div class="delivery-action">${actionHtml}</div>` : ''}
            </div>
        `;
    }

    function renderChatDetail(detailEl) {
        const contactId = S.selectedContactId;
        const c = findContact(contactId);
        if (!c) {
            detailEl.innerHTML = '<div class="empty-state">Select a conversation.</div>';
            return;
        }

        const thread = S.messages
            .filter((m) => m.contact_id === contactId)
            .slice()
            .sort((a, b) => (a.created_at > b.created_at ? 1 : -1));

        const delivery = activeDeliveryForContact(contactId);

        detailEl.innerHTML = `
            <div class="chat-thread" id="chat-thread"></div>
            ${renderDeliveryCard(delivery, contactId)}
            <div class="chat-input">
                <input type="text" id="chat-input-field" placeholder="Type a reply..." maxlength="200" />
                <button class="action-btn" id="btn-send">Send</button>
            </div>
        `;

        const threadEl = document.getElementById('chat-thread');
        thread.forEach((m) => {
            const b = document.createElement('div');
            b.className = 'bubble ' + (m.sender === 'player' ? 'player' : 'client');
            b.textContent = m.message;
            threadEl.appendChild(b);
        });
        threadEl.scrollTop = threadEl.scrollHeight;

        const claimBtn = document.getElementById('btn-claim-offer');
        if (claimBtn) {
            claimBtn.addEventListener('click', () => {
                post('claimSharedOffer', { offerId: delivery.id });
            });
        }

        const meetBtn = document.getElementById('btn-initiate-meet');
        if (meetBtn) {
            meetBtn.addEventListener('click', () => {
                post('initiateMeet', { deliveryId: delivery.id });
            });
        }

        const sendBtn = document.getElementById('btn-send');
        const inputField = document.getElementById('chat-input-field');
        const sendMessage = () => {
            const text = inputField.value.trim();
            if (!text || !delivery || delivery.status !== 'pending') return;
            S.messages.push({ contact_id: contactId, sender: 'player', message: text, created_at: Date.now() / 1000 });
            post('negotiate', { deliveryId: delivery.id, contactId: contactId, text: text });
            inputField.value = '';
            renderAll();
        };
        sendBtn.addEventListener('click', sendMessage);
        inputField.addEventListener('keydown', (e) => { if (e.key === 'Enter') sendMessage(); });
    }

    function renderDeliveriesList(listEl) {
        if (S.deliveries.length === 0) {
            listEl.innerHTML = '<div class="empty-state">No deliveries yet.</div>';
            return;
        }
        S.deliveries
            .slice()
            .sort((a, b) => (a.id < b.id ? 1 : -1))
            .forEach((d) => {
                const c = findContact(d.contact_id);
                const item = document.createElement('div');
                item.className = 'list-item' + (String(S.selectedDeliveryId) === String(d.id) ? ' selected' : '');
                item.innerHTML = `
                    <div class="name">${escapeHtml(c ? c.full_name : d.contact_id)}</div>
                    <div class="meta">${escapeHtml(d.drug)} x${escapeHtml(d.quantity)} - $${escapeHtml(d.price)} - ${escapeHtml(d.status)}</div>
                `;
                item.addEventListener('click', () => { S.selectedDeliveryId = d.id; renderAll(); });
                listEl.appendChild(item);
            });
    }

    function renderDeliveryDetail(detailEl) {
        const d = findDelivery(S.selectedDeliveryId);
        if (!d) {
            detailEl.innerHTML = '<div class="empty-state">Select a delivery to view details.</div>';
            return;
        }
        const c = findContact(d.contact_id);
        detailEl.innerHTML = `
            <div class="simple-panel">
                <h3 style="margin-top:0;color:var(--accent-bright)">${escapeHtml(c ? c.full_name : d.contact_id)}</h3>
                ${renderDeliveryCard(d, d.contact_id)}
                ${d.dead_drop ? '<div class="meta" style="margin-top:8px">Dead drop hand-off</div>' : ''}
            </div>
        `;
        const meetBtn = detailEl.querySelector('#btn-initiate-meet');
        if (meetBtn) meetBtn.addEventListener('click', () => post('initiateMeet', { deliveryId: d.id }));
    }

    function renderConnectionPanel(detailEl) {
        const state = S.networkRaided ? 'raided' : 'stable';
        const cfg = S.networkCfg[state] || {};
        detailEl.innerHTML = `
            <div class="simple-panel">
                <div class="connection-panel connection-${state}">
                    <div class="connection-dot"></div>
                    <div class="connection-title">${escapeHtml(cfg.title || '')}</div>
                    <div class="connection-subtitle">${escapeHtml(cfg.subtitle || '')}</div>
                </div>
            </div>
        `;
    }

    function renderVaultPanel(detailEl) {
        const notesHtml = S.notes.length
            ? S.notes.map((n) => `<div class="note-item">${escapeHtml(n.text)}<div class="meta">${timeAgo(n.created_at)}</div></div>`).join('')
            : '<div class="empty-state">No notes saved.</div>';

        const gpsHtml = S.gpsLogs.length
            ? S.gpsLogs.map((g) => `<div class="gps-item">${escapeHtml(g.label)} &middot; ${Number(g.x).toFixed(1)}, ${Number(g.y).toFixed(1)} <div class="meta">${timeAgo(g.created_at)}</div></div>`).join('')
            : '<div class="empty-state">No GPS logs.</div>';

        detailEl.innerHTML = `
            <div class="simple-panel">
                <h3 style="margin-top:0;color:var(--accent-bright)">Notes</h3>
                ${notesHtml}
                <div class="note-add">
                    <input type="text" id="note-input" placeholder="New note..." maxlength="280" />
                    <button class="action-btn" id="btn-add-note">Save</button>
                </div>
                <h3 style="color:var(--accent-bright)">GPS Logs</h3>
                ${gpsHtml}
            </div>
        `;

        document.getElementById('btn-add-note').addEventListener('click', () => {
            const input = document.getElementById('note-input');
            const text = input.value.trim();
            if (!text) return;
            post('addNote', { text });
            input.value = '';
        });
    }

    function renderBurnPanel(detailEl) {
        detailEl.innerHTML = `
            <div class="burn-panel">
                <div class="burn-warning">
                    Burning this device permanently wipes all contacts and messages.<br/>
                    Deliveries history and reputation are kept. This cannot be undone.
                </div>
                <button class="danger-btn" id="btn-burn">Confirm Burn</button>
            </div>
        `;
        let confirmed = false;
        document.getElementById('btn-burn').addEventListener('click', (e) => {
            if (!confirmed) {
                confirmed = true;
                e.target.textContent = 'Click again to confirm';
                return;
            }
            post('burnDevice');
        });
    }

    function renderDashboardShell() {
        document.getElementById('dash-app-title').textContent = S.theme.appName || 'OVI';
        document.getElementById('dash-alias').textContent = S.phone && S.phone.alias ? `@${S.phone.alias}` : '';
        renderAll();
    }

    // -------------------------------------------------------- push update --

    function ensureContactKnown(contactId) {
        if (!contactId) return true;
        return !!findContact(contactId);
    }

    function handlePushUpdate(payload) {
        if (!payload || !payload.type) return;

        if (!ensureContactKnown(payload.contactId)) {
            post('requestRefresh');
            return;
        }

        if (payload.type === 'newMessage') {
            S.messages.push({ contact_id: payload.contactId, sender: 'client', message: payload.message, created_at: Date.now() / 1000 });
            if (payload.deliveryId && !findDelivery(payload.deliveryId)) {
                S.deliveries.push({
                    id: payload.deliveryId,
                    contact_id: payload.contactId,
                    drug: payload.drug,
                    quantity: payload.quantity,
                    price: payload.price,
                    status: 'pending',
                    dead_drop: 0,
                });
            }
        } else if (payload.type === 'negotiationResult') {
            if (payload.reply) {
                S.messages.push({ contact_id: payload.contactId, sender: 'client', message: payload.reply, created_at: Date.now() / 1000 });
            }
            const d = findDelivery(payload.deliveryId);
            if (d) {
                if (payload.price != null) d.price = payload.price;
                if (payload.quantity != null) d.quantity = payload.quantity;
                if (payload.outcome === 'accept') d.status = 'accepted';
                else if (payload.outcome === 'insult' || payload.outcome === 'cancel') d.status = 'failed';
            }
        } else if (payload.type === 'sharedOffer') {
            S.offers[payload.offerId] = { contactId: payload.contactId, drug: payload.drug, quantity: payload.quantity, price: payload.price };
            S.messages.push({ contact_id: payload.contactId, sender: 'client', message: payload.message, created_at: Date.now() / 1000 });
            S.deliveries.push({
                id: payload.offerId,
                contact_id: payload.contactId,
                drug: payload.drug,
                quantity: payload.quantity,
                price: payload.price,
                status: 'offer',
                dead_drop: 0,
            });
        } else if (payload.type === 'sharedOfferClosed') {
            const offer = S.offers[payload.offerId];
            const d = findDelivery(payload.offerId);
            if (d) d.status = 'failed';
            if (offer) {
                S.messages.push({ contact_id: offer.contactId, sender: 'client', message: payload.message, created_at: Date.now() / 1000 });
            }
        } else if (payload.type === 'sharedOfferWon') {
            const offer = S.offers[payload.offerId];
            const d = findDelivery(payload.offerId);
            if (d && offer) {
                d.id = payload.deliveryId;
                d.status = 'pending';
            }
        } else if (payload.type === 'deliveryComplete') {
            const d = findDelivery(payload.deliveryId);
            if (d) d.status = 'success';
        } else if (payload.type === 'noteAdded') {
            S.notes.unshift({ text: payload.text, created_at: Date.now() / 1000 });
        } else if (payload.type === 'networkStatus') {
            S.networkRaided = !!payload.raided;
        }

        renderAll();
    }

    // --------------------------------------------------------- nui events --

    window.addEventListener('message', (event) => {
        const data = event.data;
        if (!data || !data.action) return;

        switch (data.action) {
            case 'showPin':
                S.theme = data.config.theme ? { ...data.config } : data.config;
                S.theme.appName = data.config.appName;
                S.theme.appSubtitle = data.config.appSubtitle;
                applyTheme(data.config.theme);
                S.pinLength = data.pinLength;
                S.enteredPin = '';
                showApp();
                showScreen('pin');
                renderPinPad();
                break;

            case 'pinError':
                onPinError();
                break;

            case 'boot':
                showScreen('boot');
                renderBoot(data.bootLines, data.bootLoadingTimeMs);
                break;

            case 'dashboard': {
                const d = data.data;
                S.theme = { ...d.config.ui, appName: d.config.ui.appName, appSubtitle: d.config.ui.appSubtitle };
                applyTheme(d.config.ui.theme);
                S.tabsCfg = d.config.ui.tabs || {};
                S.networkRaided = !!d.networkRaided;
                S.networkCfg = d.config.network || {};
                S.phone = d.phone;
                S.contacts = d.contacts || [];
                S.messages = d.messages || [];
                S.deliveries = d.deliveries || [];
                S.notes = d.notes || [];
                S.gpsLogs = d.gpsLogs || [];

                if (!S.booted) {
                    S.booted = true;
                    if (!S.activeTab) S.activeTab = 'contacts';
                }

                showApp();
                showScreen('dashboard');
                renderDashboardShell();
                break;
            }

            case 'pushUpdate':
                handlePushUpdate(data.payload);
                break;

            default:
                break;
        }
    });

    document.getElementById('btn-close').addEventListener('click', () => {
        post('close');
        hideApp();
        S.booted = false;
    });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !app.classList.contains('hidden')) {
            post('close');
            hideApp();
            S.booted = false;
        }
    });
})();
