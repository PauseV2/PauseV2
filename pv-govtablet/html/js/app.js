(() => {
  const resourceName = (() => {
    try { return GetParentResourceName(); } catch (e) { return 'pv-govtablet'; }
  })();

  const state = {
    permissions: {},
    job: null,
    label: '',
    profile: null,
  };

  // ============================================================
  // NUI bridge
  // ============================================================

  function post(event, args = []) {
    return fetch(`https://${resourceName}/${event}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify({ args }),
    }).then(r => r.json()).catch(() => ({ success: false, data: 'nui_error' }));
  }

  // ============================================================
  // Toasts
  // ============================================================

  function toast(message, type = 'info') {
    const stack = document.getElementById('toastStack');
    const el = document.createElement('div');
    el.className = `toast ${type}`;
    el.textContent = message;
    stack.appendChild(el);
    setTimeout(() => el.remove(), 3500);
  }

  function friendlyError(code) {
    const map = {
      no_permission: 'You do not have permission to do that.',
      rate_limited: 'Slow down - too many actions.',
      invalid_citizenid: 'Invalid citizen ID.',
      invalid_query: 'Enter a search term.',
      invalid_account: 'Invalid account type.',
      invalid_amount: 'Invalid amount.',
      invalid_plate: 'Invalid plate.',
      invalid_house: 'Invalid property.',
      invalid_url: 'Enter a valid http(s) image URL.',
      invalid_payload: 'Invalid data submitted.',
      invalid_charges: 'Charges are required.',
      not_found: 'Not found.',
      not_owned: 'Citizen does not own that property.',
      no_seizure_found: 'No active seizure record found.',
      insufficient_funds: 'Citizen does not have sufficient funds.',
      no_garage_resource: 'No garage resource detected on this server.',
      no_housing_resource: 'No housing resource detected on this server.',
    };
    return map[code] || 'Action failed.';
  }

  // ============================================================
  // Modal
  // ============================================================

  function showModal(title, fields, confirmLabel = 'Confirm', danger = false) {
    return new Promise((resolve) => {
      const overlay = document.getElementById('modalOverlay');
      const modal = document.getElementById('modal');

      let html = `<h2>${title}</h2>`;
      fields.forEach(f => {
        html += `<label>${f.label}</label>`;
        if (f.type === 'select') {
          html += `<select id="mf_${f.name}">${f.options.map(o => `<option value="${o.value}">${o.label}</option>`).join('')}</select>`;
        } else if (f.type === 'textarea') {
          html += `<textarea id="mf_${f.name}" placeholder="${f.placeholder || ''}"></textarea>`;
        } else {
          html += `<input id="mf_${f.name}" type="${f.type || 'text'}" placeholder="${f.placeholder || ''}" />`;
        }
      });
      html += `<div class="modal-actions">
        <button class="cancel" id="modalCancel">Cancel</button>
        <button class="confirm ${danger ? 'danger' : ''}" id="modalConfirm">${confirmLabel}</button>
      </div>`;

      modal.innerHTML = html;
      overlay.classList.remove('hidden');

      const close = (result) => {
        overlay.classList.add('hidden');
        resolve(result);
      };

      document.getElementById('modalCancel').onclick = () => close(null);
      document.getElementById('modalConfirm').onclick = () => {
        const values = {};
        fields.forEach(f => { values[f.name] = document.getElementById(`mf_${f.name}`).value; });
        close(values);
      };
    });
  }

  // ============================================================
  // View / tab switching
  // ============================================================

  function setView(view) {
    document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
    document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
    document.getElementById(`view-${view}`).classList.add('active');
    const navBtn = document.querySelector(`.nav-item[data-view="${view}"]`);
    if (navBtn) navBtn.classList.add('active');

    if (view === 'approvals') loadApprovals();
    if (view === 'logs') loadLogs();
  }

  function setTab(tab) {
    document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    document.getElementById(`tab-${tab}`).classList.add('active');
    document.querySelector(`.tab-btn[data-tab="${tab}"]`).classList.add('active');
  }

  document.addEventListener('click', (e) => {
    const navItem = e.target.closest('.nav-item');
    if (navItem && !navItem.disabled) setView(navItem.dataset.view);

    const tabBtn = e.target.closest('.tab-btn');
    if (tabBtn) setTab(tabBtn.dataset.tab);
  });

  // ============================================================
  // Search
  // ============================================================

  async function runSearch() {
    const type = document.getElementById('searchType').value;
    const query = document.getElementById('searchInput').value.trim();
    const resultsEl = document.getElementById('searchResults');

    if (!query) { toast('Enter a search term.', 'error'); return; }

    const res = await post('search', [query, type]);
    if (!res.success) {
      resultsEl.innerHTML = `<div class="empty-state">${friendlyError(res.data)}</div>`;
      return;
    }

    if (!res.data.length) {
      resultsEl.innerHTML = `<div class="empty-state">No matching citizens found.</div>`;
      return;
    }

    resultsEl.innerHTML = res.data.map(r => `
      <div class="result-card" data-cid="${r.citizenid}">
        <div>
          <div class="result-name">${r.name}</div>
          <div class="result-meta">CID: ${r.citizenid} &middot; ${r.phone}</div>
        </div>
        <div class="result-arrow">&#8594;</div>
      </div>
    `).join('');

    resultsEl.querySelectorAll('.result-card').forEach(card => {
      card.addEventListener('click', () => loadProfile(card.dataset.cid));
    });
  }

  document.getElementById('searchBtn').addEventListener('click', runSearch);
  document.getElementById('searchInput').addEventListener('keydown', (e) => { if (e.key === 'Enter') runSearch(); });

  // ============================================================
  // Profile
  // ============================================================

  async function loadProfile(citizenid) {
    const res = await post('getProfile', [citizenid]);
    if (!res.success) { toast(friendlyError(res.data), 'error'); return; }

    state.profile = res.data;
    document.getElementById('navProfile').disabled = false;
    renderProfile();
    setView('profile');
    setTab('overview');
  }

  function perm(action) { return !!state.permissions[action]; }

  function renderProfile() {
    const p = state.profile;
    document.getElementById('profilePhoto').src = p.photo || 'img/placeholder.svg';
    document.getElementById('profileName').textContent = p.name;
    document.getElementById('profileJob').textContent = p.job;
    document.getElementById('profileCid').textContent = p.citizenid;
    document.getElementById('setPhotoBtn').style.display = perm('setPhoto') ? '' : 'none';

    renderOverview();
    renderFinancial();
    renderVehicles();
    renderProperties();
    renderCriminal();
  }

  function infoCard(label, value, sub) {
    return `<div class="info-card">
      <div class="label">${label}</div>
      <div class="value">${value}</div>
      ${sub ? `<div class="sub">${sub}</div>` : ''}
    </div>`;
  }

  function renderOverview() {
    const p = state.profile;
    document.getElementById('overviewGrid').innerHTML = [
      infoCard('Date of Birth', p.dob),
      infoCard('Gender', p.gender),
      infoCard('Nationality', p.nationality),
      infoCard('Phone Number', p.phone),
      infoCard('Occupation', p.job),
      infoCard('Citizen ID', p.citizenid),
    ].join('');
  }

  function renderFinancial() {
    const grid = document.getElementById('financialGrid');
    if (!perm('viewFinance') || !state.profile.finance) {
      grid.innerHTML = `<div class="empty-state">No financial access.</div>`;
      return;
    }

    const types = { bank: 'Bank Account', crypto: 'Crypto Wallet' };
    grid.innerHTML = Object.entries(types).map(([key, label]) => {
      const f = state.profile.finance[key] || { amount: 0, frozen: false, hidden: false };
      let actions = '';
      if (perm('freeze') && !f.frozen) actions += `<button class="action-btn warn" data-act="freeze" data-type="${key}">Freeze</button>`;
      if (perm('unfreeze') && f.frozen) actions += `<button class="action-btn success" data-act="unfreeze" data-type="${key}">Unfreeze</button>`;
      if (perm('hide') && !f.hidden) actions += `<button class="action-btn" data-act="hide" data-type="${key}">Hide</button>`;
      if (perm('reveal') && f.hidden) actions += `<button class="action-btn" data-act="reveal" data-type="${key}">Reveal</button>`;
      if (perm('seizeFunds')) actions += `<button class="action-btn danger" data-act="seizeFunds" data-type="${key}">Seize Funds</button>`;

      return `<div class="finance-card">
        <div class="ftype">${label}</div>
        <div class="famount">$${Number(f.amount).toLocaleString()}</div>
        <div class="fstatus">
          ${f.frozen ? '<span class="pill frozen">Frozen</span>' : '<span class="pill active-pill">Active</span>'}
          ${f.hidden ? '<span class="pill hidden-pill">Hidden</span>' : ''}
        </div>
        <div class="finance-actions">${actions}</div>
      </div>`;
    }).join('');

    grid.querySelectorAll('button[data-act]').forEach(btn => {
      btn.addEventListener('click', () => handleFinanceAction(btn.dataset.act, btn.dataset.type));
    });
  }

  async function handleFinanceAction(action, accountType) {
    const citizenid = state.profile.citizenid;

    if (action === 'freeze' || action === 'unfreeze') {
      const vals = await showModal(`${action === 'freeze' ? 'Freeze' : 'Unfreeze'} ${accountType} account`, [
        { name: 'reason', label: 'Reason', type: 'textarea', placeholder: 'Reason for this action...' },
      ], action === 'freeze' ? 'Freeze' : 'Unfreeze', action === 'freeze');
      if (!vals) return;
      const res = await post('freezeAccount', [citizenid, accountType, vals.reason, action === 'freeze']);
      if (res.success) { toast('Account updated.', 'success'); refreshProfile(); }
      else toast(friendlyError(res.data), 'error');
      return;
    }

    if (action === 'hide' || action === 'reveal') {
      const res = await post('setAccountHidden', [citizenid, accountType, action === 'hide']);
      if (res.success) { toast('Account updated.', 'success'); refreshProfile(); }
      else toast(friendlyError(res.data), 'error');
      return;
    }

    if (action === 'seizeFunds') {
      const vals = await showModal(`Seize funds - ${accountType}`, [
        { name: 'amount', label: 'Amount ($)', type: 'number', placeholder: '0' },
        { name: 'reason', label: 'Reason', type: 'textarea', placeholder: 'Reason for seizure...' },
      ], 'Seize', true);
      if (!vals) return;
      const res = await post('seizeFunds', [citizenid, accountType, Number(vals.amount), vals.reason]);
      if (res.success) {
        toast(res.data === 'pending_approval' ? 'Submitted for judge approval.' : 'Funds seized.', 'success');
        refreshProfile();
      } else toast(friendlyError(res.data), 'error');
    }
  }

  function renderVehicles() {
    const list = document.getElementById('vehicleList');
    const vehicles = state.profile.vehicles;
    if (!perm('viewAssets') || !vehicles) { list.innerHTML = `<div class="empty-state">No asset access.</div>`; return; }
    if (!vehicles.length) { list.innerHTML = `<div class="empty-state">No registered vehicles.</div>`; return; }

    list.innerHTML = vehicles.map(v => {
      let status = v.impounded ? '<span class="pill warn-pill" style="background:var(--warn-soft);color:var(--warn);">Impounded</span>'
        : v.stored ? '<span class="pill active-pill">In Garage</span>'
        : '<span class="pill" style="background:var(--bg-3);color:var(--text-1);">Out</span>';
      if (v.seized) status += ' <span class="pill frozen">Seized</span>';

      let actions = '';
      if (v.seized) {
        if (perm('releaseVehicle')) actions += `<button class="action-btn success" data-act="releaseVehicle" data-plate="${v.plate}">Release Seizure</button>`;
      } else if (perm('seizeVehicle')) {
        actions += `<button class="action-btn danger" data-act="seizeVehicle" data-plate="${v.plate}">Seize</button>`;
      }
      if (v.impounded) {
        if (perm('impoundVehicle')) actions += `<button class="action-btn success" data-act="releaseImpound" data-plate="${v.plate}">Release Impound</button>`;
      } else if (perm('impoundVehicle')) {
        actions += `<button class="action-btn warn" data-act="impoundVehicle" data-plate="${v.plate}">Impound</button>`;
      }

      return `<div class="list-item">
        <div class="list-item-main">
          <div class="list-item-title">${v.model || 'Unknown Model'} ${status}</div>
          <div class="list-item-sub">Plate: ${v.plate}</div>
        </div>
        <div class="list-item-actions">${actions}</div>
      </div>`;
    }).join('');

    list.querySelectorAll('button[data-act]').forEach(btn => {
      btn.addEventListener('click', () => handleVehicleAction(btn.dataset.act, btn.dataset.plate));
    });
  }

  async function handleVehicleAction(action, plate) {
    if (action === 'releaseVehicle' || action === 'releaseImpound') {
      const res = await post(action, [plate]);
      if (res.success) { toast('Vehicle updated.', 'success'); refreshProfile(); }
      else toast(friendlyError(res.data), 'error');
      return;
    }

    const isDanger = action === 'seizeVehicle';
    const vals = await showModal(`${isDanger ? 'Seize' : 'Impound'} vehicle ${plate}`, [
      { name: 'reason', label: 'Reason', type: 'textarea', placeholder: 'Reason...' },
    ], isDanger ? 'Seize' : 'Impound', isDanger);
    if (!vals) return;

    const res = await post(action, [plate, vals.reason]);
    if (res.success) {
      toast(res.data === 'pending_approval' ? 'Submitted for judge approval.' : 'Vehicle updated.', 'success');
      refreshProfile();
    } else toast(friendlyError(res.data), 'error');
  }

  function renderProperties() {
    const list = document.getElementById('propertyList');
    const properties = state.profile.properties;
    if (!perm('viewAssets') || !properties) { list.innerHTML = `<div class="empty-state">No asset access.</div>`; return; }
    if (!properties.length) { list.innerHTML = `<div class="empty-state">No registered properties.</div>`; return; }

    list.innerHTML = properties.map(p => {
      const status = p.seized ? '<span class="pill frozen">Seized</span>' : '<span class="pill active-pill">Owned</span>';
      let actions = '';
      if (p.seized && perm('restoreProperty')) actions += `<button class="action-btn success" data-act="restoreProperty" data-house="${p.house}">Restore</button>`;
      if (!p.seized && perm('seizeProperty')) actions += `<button class="action-btn danger" data-act="seizeProperty" data-house="${p.house}">Seize</button>`;

      return `<div class="list-item">
        <div class="list-item-main">
          <div class="list-item-title">${p.label} ${status}</div>
          <div class="list-item-sub">${p.type === 'apartment' ? 'Apartment' : 'House'} &middot; ${p.location} &middot; $${Number(p.price).toLocaleString()}</div>
        </div>
        <div class="list-item-actions">${actions}</div>
      </div>`;
    }).join('');

    list.querySelectorAll('button[data-act]').forEach(btn => {
      btn.addEventListener('click', () => handlePropertyAction(btn.dataset.act, btn.dataset.house));
    });
  }

  async function handlePropertyAction(action, house) {
    const citizenid = state.profile.citizenid;

    if (action === 'restoreProperty') {
      const res = await post('restoreProperty', [citizenid, house]);
      if (res.success) { toast('Property restored.', 'success'); refreshProfile(); }
      else toast(friendlyError(res.data), 'error');
      return;
    }

    const vals = await showModal(`Seize property: ${house}`, [
      { name: 'reason', label: 'Reason', type: 'textarea', placeholder: 'Reason for seizure...' },
    ], 'Seize', true);
    if (!vals) return;

    const res = await post('seizeProperty', [citizenid, house, vals.reason]);
    if (res.success) {
      toast(res.data === 'pending_approval' ? 'Submitted for judge approval.' : 'Property seized.', 'success');
      refreshProfile();
    } else toast(friendlyError(res.data), 'error');
  }

  function renderCriminal() {
    const timeline = document.getElementById('criminalTimeline');
    const records = state.profile.criminalRecords;
    document.getElementById('addRecordBtn').style.display = perm('editCriminal') ? '' : 'none';

    if (!perm('viewCriminal') || !records) { timeline.innerHTML = `<div class="empty-state">No criminal record access.</div>`; return; }
    if (!records.length) { timeline.innerHTML = `<div class="empty-state">No criminal history on file.</div>`; return; }

    timeline.innerHTML = records.map(r => `
      <div class="timeline-item">
        <div class="timeline-dot ${r.status}"></div>
        <div class="timeline-card">
          <div class="tc-top">
            <div class="tc-charges">${r.charges}</div>
            <span class="pill ${r.status === 'served' ? 'active-pill' : r.status === 'warrant' ? 'frozen' : 'hidden-pill'}">${r.status}</span>
          </div>
          <div class="tc-meta">
            <span>Officer: ${r.officer_name}</span>
            <span>Date: ${new Date(r.created_at).toLocaleDateString()}</span>
            <span>Sentence: ${r.sentence_months} mo.</span>
            <span>Fine: $${Number(r.fine).toLocaleString()}</span>
          </div>
        </div>
      </div>
    `).join('');
  }

  document.getElementById('addRecordBtn').addEventListener('click', async () => {
    const vals = await showModal('Add Criminal Record', [
      { name: 'charges', label: 'Charges', type: 'text', placeholder: 'e.g. Grand Theft Auto, Murder' },
      { name: 'fine', label: 'Fine ($)', type: 'number', placeholder: '0' },
      { name: 'sentenceMonths', label: 'Sentence (months)', type: 'number', placeholder: '0' },
      { name: 'status', label: 'Status', type: 'select', options: [
        { value: 'active', label: 'Active' },
        { value: 'served', label: 'Served' },
        { value: 'warrant', label: 'Warrant' },
        { value: 'fined', label: 'Fined' },
        { value: 'dismissed', label: 'Dismissed' },
      ] },
      { name: 'notes', label: 'Notes', type: 'textarea', placeholder: 'Additional notes...' },
    ], 'Add Record');
    if (!vals) return;

    vals.fine = Number(vals.fine) || 0;
    vals.sentenceMonths = Number(vals.sentenceMonths) || 0;

    const res = await post('addCriminalRecord', [state.profile.citizenid, vals]);
    if (res.success) { toast('Record added.', 'success'); refreshProfile(); }
    else toast(friendlyError(res.data), 'error');
  });

  document.getElementById('setPhotoBtn').addEventListener('click', async () => {
    const vals = await showModal('Set Profile Photo', [
      { name: 'url', label: 'Image URL', type: 'text', placeholder: 'https://...' },
    ], 'Save');
    if (!vals) return;

    const res = await post('setPhoto', [state.profile.citizenid, vals.url]);
    if (res.success) { toast('Photo updated.', 'success'); refreshProfile(); }
    else toast(friendlyError(res.data), 'error');
  });

  async function refreshProfile() {
    const res = await post('getProfile', [state.profile.citizenid]);
    if (res.success) { state.profile = res.data; renderProfile(); }
  }

  // ============================================================
  // Approvals
  // ============================================================

  async function loadApprovals() {
    const list = document.getElementById('approvalList');
    const res = await post('getPendingApprovals', []);
    if (!res.success) { list.innerHTML = `<div class="empty-state">${friendlyError(res.data)}</div>`; return; }
    if (!res.data.length) { list.innerHTML = `<div class="empty-state">No pending requests.</div>`; return; }

    list.innerHTML = res.data.map(r => {
      const payload = JSON.parse(r.payload);
      let detail = '';
      if (r.type === 'funds') detail = `${payload.accountType} - $${Number(payload.amount).toLocaleString()}`;
      if (r.type === 'vehicle') detail = `Plate ${payload.plate}`;
      if (r.type === 'property') detail = `Property ${payload.house}`;

      return `<div class="list-item">
        <div class="list-item-main">
          <div class="list-item-title">${r.type.toUpperCase()} seizure - ${detail}</div>
          <div class="list-item-sub">Requested by ${r.requested_by_name} &middot; Citizen ${r.citizenid} &middot; "${r.reason}"</div>
        </div>
        <div class="list-item-actions">
          <button class="action-btn success" data-act="approve" data-id="${r.id}">Approve</button>
          <button class="action-btn danger" data-act="deny" data-id="${r.id}">Deny</button>
        </div>
      </div>`;
    }).join('');

    list.querySelectorAll('button[data-act]').forEach(btn => {
      btn.addEventListener('click', async () => {
        const res2 = await post('resolveApproval', [btn.dataset.id, btn.dataset.act === 'approve']);
        if (res2.success) { toast('Request resolved.', 'success'); loadApprovals(); }
        else toast(friendlyError(res2.data), 'error');
      });
    });
  }

  // ============================================================
  // Logs
  // ============================================================

  async function loadLogs() {
    const list = document.getElementById('logList');
    const res = await post('getLogs', []);
    if (!res.success) { list.innerHTML = `<div class="empty-state">${friendlyError(res.data)}</div>`; return; }
    if (!res.data.length) { list.innerHTML = `<div class="empty-state">No log entries.</div>`; return; }

    list.innerHTML = res.data.map(l => `
      <div class="list-item">
        <div class="list-item-main">
          <div class="list-item-title">${l.action} <span class="pill" style="background:var(--bg-3);color:var(--text-1);">${l.staff_job}</span></div>
          <div class="list-item-sub">${l.staff_name} &middot; Target: ${l.target_citizenid || 'N/A'} &middot; ${l.details || ''}</div>
        </div>
        <div class="list-item-sub">${new Date(l.created_at).toLocaleString()}</div>
      </div>
    `).join('');
  }

  // ============================================================
  // Lifecycle
  // ============================================================

  function resetUI() {
    state.profile = null;
    document.getElementById('navProfile').disabled = true;
    document.getElementById('searchInput').value = '';
    document.getElementById('searchResults').innerHTML = '';
    setView('search');
  }

  window.addEventListener('message', (event) => {
    const msg = event.data;
    if (msg.action === 'open') {
      state.permissions = msg.permissions || {};
      state.job = msg.job;
      state.label = msg.label;

      document.getElementById('roleLabel').textContent = msg.label || msg.job;
      document.getElementById('navApprovals').style.display = perm('approveSeizure') ? '' : 'none';
      document.getElementById('navLogs').style.display = perm('viewLogs') ? '' : 'none';

      resetUI();
      document.getElementById('app').classList.remove('hidden');
    }

    if (msg.action === 'close') {
      document.getElementById('app').classList.add('hidden');
      document.getElementById('modalOverlay').classList.add('hidden');
    }
  });

  document.getElementById('closeBtn').addEventListener('click', () => post('close', []));

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') post('close', []);
  });
})();
