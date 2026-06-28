const root = document.getElementById('root');

const headerWeightLeft = document.getElementById('header-weight-left');
const headerWeightRight = document.getElementById('header-weight-right');
const searchInput = document.getElementById('search-input');
const closeBtn = document.getElementById('close-btn');

const playerGrid = document.getElementById('player-grid');
const playerList = document.getElementById('player-list');

const contextPane = document.getElementById('context-pane');
const detailView = document.getElementById('detail-view');
const detailIcon = document.getElementById('detail-icon');
const detailName = document.getElementById('detail-name');
const detailWeight = document.getElementById('detail-weight');
const detailDescription = document.getElementById('detail-description');
const qtyMinus = document.getElementById('qty-minus');
const qtyInput = document.getElementById('qty-input');
const qtyPlus = document.getElementById('qty-plus');
const useItemBtn = document.getElementById('use-item-btn');

const secondaryView = document.getElementById('secondary-view');
const contextTitle = document.getElementById('context-title');
const contextWeightFill = document.getElementById('context-weight-fill');
const contextWeightText = document.getElementById('context-weight-text');
const contextGrid = document.getElementById('context-grid');

const shopView = document.getElementById('shop-view');
const shopTitle = document.getElementById('shop-title');
const shopList = document.getElementById('shop-list');

const emptyView = document.getElementById('empty-view');

const useBtn = document.getElementById('use-btn');
const dropBtn = document.getElementById('drop-btn');
const splitBtn = document.getElementById('split-btn');
const giveBtn = document.getElementById('give-btn');
const viewGridBtn = document.getElementById('view-grid-btn');
const viewListBtn = document.getElementById('view-list-btn');

const errorEl = document.getElementById('inv-error');
const notifyEl = document.getElementById('inv-notify');

let mode = null;
let secondaryId = null;
let playerSnapshot = null;
let secondarySnapshot = null;
let shopData = null;
let selected = null; // { inv: 'player'|secondaryId, slot }
let viewMode = 'grid'; // 'grid' | 'list'
let searchTerm = '';

function resourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'ox-inventory';
}

function nuiCallback(name, data) {
    return fetch(`https://${resourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).then((resp) => resp.json());
}

let errorTimeout, notifyTimeout;

function showError(message) {
    clearTimeout(errorTimeout);
    errorEl.textContent = message;
    errorEl.classList.remove('hidden');
    errorTimeout = setTimeout(() => errorEl.classList.add('hidden'), 3000);
}

function clearError() {
    clearTimeout(errorTimeout);
    errorEl.classList.add('hidden');
}

function showNotify(message) {
    clearTimeout(notifyTimeout);
    notifyEl.textContent = message;
    notifyEl.classList.remove('hidden');
    notifyTimeout = setTimeout(() => notifyEl.classList.add('hidden'), 3000);
}

function findEntry(snapshot, slot) {
    return snapshot && snapshot.items.find((entry) => entry.slot === slot);
}

function getSnapshotFor(invId) {
    if (invId === 'player') return playerSnapshot;
    if (invId === secondaryId) return secondarySnapshot;
    return null;
}

function getEntryFor(invId, slot) {
    return findEntry(getSnapshotFor(invId), slot);
}

function fmtKg(grams, decimals) {
    return (grams / 1000).toFixed(decimals === undefined ? 1 : decimals);
}

function matchesSearch(entry) {
    if (!searchTerm) return true;
    return entry.label.toLowerCase().includes(searchTerm);
}

function setupDragTarget(el, invId, slot) {
    el.addEventListener('dragover', (event) => {
        event.preventDefault();
        el.classList.add('drag-over');
    });

    el.addEventListener('dragleave', () => {
        el.classList.remove('drag-over');
    });

    el.addEventListener('drop', (event) => {
        event.preventDefault();
        el.classList.remove('drag-over');

        const raw = event.dataTransfer.getData('text/plain');
        if (!raw) return;

        const from = JSON.parse(raw);
        if (from.inv === invId && from.slot === slot) return;

        moveItem(from.inv, from.slot, invId, slot);
    });
}

function renderGrid(container, snapshot, invId) {
    container.innerHTML = '';
    if (!snapshot) return;

    for (let slot = 1; slot <= snapshot.slots; slot++) {
        const entry = findEntry(snapshot, slot);
        const slotEl = document.createElement('div');
        slotEl.className = 'slot';

        if (entry) {
            if (invId === 'player' && !matchesSearch(entry)) {
                slotEl.style.display = 'none';
            }

            slotEl.classList.add('has-item');
            slotEl.draggable = true;
            slotEl.innerHTML = `
                <div class="slot-count">x${entry.count}</div>
                <div class="slot-icon">${entry.icon}</div>
                <div class="slot-label">${entry.label}</div>
                <div class="slot-weight">${fmtKg(entry.weight * entry.count)} KG</div>
            `;

            slotEl.addEventListener('dragstart', (event) => {
                event.dataTransfer.setData('text/plain', JSON.stringify({ inv: invId, slot }));
            });
        } else {
            slotEl.classList.add('empty');
        }

        if (selected && selected.inv === invId && selected.slot === slot) {
            slotEl.classList.add('selected');
        }

        slotEl.addEventListener('click', () => onSlotClick(invId, slot, !!entry));
        setupDragTarget(slotEl, invId, slot);
        container.appendChild(slotEl);
    }
}

function renderList(container, snapshot, invId) {
    container.innerHTML = '';
    if (!snapshot) return;

    for (let slot = 1; slot <= snapshot.slots; slot++) {
        const entry = findEntry(snapshot, slot);
        if (!entry) continue;
        if (invId === 'player' && !matchesSearch(entry)) continue;

        const rowEl = document.createElement('div');
        rowEl.className = 'list-row';
        rowEl.draggable = true;
        rowEl.innerHTML = `
            <div class="slot-icon">${entry.icon}</div>
            <div class="list-label">${entry.label}</div>
            <div class="list-weight">${fmtKg(entry.weight * entry.count)} KG</div>
            <div class="list-count">x${entry.count}</div>
        `;

        if (selected && selected.inv === invId && selected.slot === slot) {
            rowEl.classList.add('selected');
        }

        rowEl.addEventListener('dragstart', (event) => {
            event.dataTransfer.setData('text/plain', JSON.stringify({ inv: invId, slot }));
        });

        rowEl.addEventListener('click', () => onSlotClick(invId, slot, true));
        setupDragTarget(rowEl, invId, slot);
        container.appendChild(rowEl);
    }
}

function renderPlayerPane() {
    if (viewMode === 'grid') {
        playerGrid.classList.remove('hidden');
        playerList.classList.add('hidden');
        renderGrid(playerGrid, playerSnapshot, 'player');
    } else {
        playerGrid.classList.add('hidden');
        playerList.classList.remove('hidden');
        renderList(playerList, playerSnapshot, 'player');
    }

    if (playerSnapshot) {
        const text = `${Math.round(playerSnapshot.weight / 1000)}/${Math.round(playerSnapshot.maxWeight / 1000)} KG`;
        headerWeightLeft.textContent = text;
        headerWeightRight.textContent = text;
    }
}

function renderDetail(entry) {
    detailIcon.textContent = entry.icon;
    detailName.textContent = entry.label;
    detailWeight.textContent = `${fmtKg(entry.weight)} KG`;
    detailDescription.textContent = entry.description || '';
    qtyInput.max = entry.count;
    qtyInput.value = Math.min(parseInt(qtyInput.value, 10) || 1, entry.count);
}

function renderShop() {
    shopList.innerHTML = '';
    if (!shopData) return;

    shopTitle.textContent = shopData.label;

    const accountWrap = document.createElement('div');
    accountWrap.className = 'shop-account';
    accountWrap.innerHTML = `
        <label>Pay with
            <select id="shop-account-select">
                <option value="cash">Cash</option>
                <option value="bank">Bank</option>
            </select>
        </label>
    `;
    shopList.appendChild(accountWrap);

    shopData.items.forEach((item) => {
        const row = document.createElement('div');
        row.className = 'shop-item';
        row.innerHTML = `
            <div>
                <div class="shop-item-name">${item.name}</div>
                <div class="shop-item-price">$${item.price}</div>
            </div>
            <div class="shop-item-actions">
                <input type="number" min="1" value="1" />
                <button>Buy</button>
            </div>
        `;

        row.querySelector('button').addEventListener('click', () => {
            const qty = parseInt(row.querySelector('input').value, 10) || 1;
            const account = document.getElementById('shop-account-select').value;
            buyItem(item.name, qty, account);
        });

        shopList.appendChild(row);
    });
}

function renderContextPane() {
    detailView.classList.add('hidden');
    secondaryView.classList.add('hidden');
    shopView.classList.add('hidden');
    emptyView.classList.add('hidden');

    const selectedEntry = selected && getEntryFor(selected.inv, selected.slot);

    if (selectedEntry) {
        detailView.classList.remove('hidden');
        renderDetail(selectedEntry);
    } else if (mode === 'shop') {
        shopView.classList.remove('hidden');
        renderShop();
    } else if (mode === 'stash' || mode === 'ground') {
        secondaryView.classList.remove('hidden');
        contextTitle.textContent = secondarySnapshot ? secondarySnapshot.label : '';
        renderGrid(contextGrid, secondarySnapshot, secondaryId);

        const pct = secondarySnapshot ? Math.min(100, (secondarySnapshot.weight / secondarySnapshot.maxWeight) * 100) : 0;
        contextWeightFill.style.width = `${pct}%`;
        contextWeightText.textContent = secondarySnapshot
            ? `${fmtKg(secondarySnapshot.weight, 0)} / ${fmtKg(secondarySnapshot.maxWeight, 0)} KG`
            : '';
    } else {
        emptyView.classList.remove('hidden');
    }
}

function renderFooter() {
    const entry = selected && selected.inv === 'player' && getEntryFor('player', selected.slot);

    useBtn.disabled = !entry;
    dropBtn.disabled = !entry;
    giveBtn.disabled = !entry;
    splitBtn.disabled = !entry || entry.count <= 1;

    viewGridBtn.classList.toggle('active', viewMode === 'grid');
    viewListBtn.classList.toggle('active', viewMode === 'list');
}

function renderAll() {
    renderPlayerPane();
    renderContextPane();
    renderFooter();
}

function onSlotClick(invId, slot, hasItem) {
    clearError();

    if (selected && selected.inv === invId && selected.slot === slot) {
        selected = null;
        renderAll();
        return;
    }

    if (hasItem) {
        selected = { inv: invId, slot };
    } else {
        selected = null;
    }

    renderAll();
}

function getQty() {
    return parseInt(qtyInput.value, 10) || 1;
}

async function moveItem(fromInv, fromSlot, toInv, toSlot) {
    const result = await nuiCallback('moveItem', { fromInv, fromSlot, toInv, toSlot });

    if (!result.ok) {
        showError(result.error || 'Failed to move item.');
        return;
    }

    if (fromInv === 'player') playerSnapshot = result.fromSnapshot;
    else secondarySnapshot = result.fromSnapshot;

    if (toInv === 'player') playerSnapshot = result.toSnapshot;
    else secondarySnapshot = result.toSnapshot;

    selected = null;
    renderAll();
}

async function useItem(slot) {
    clearError();
    const result = await nuiCallback('useItem', { slot });

    if (!result.ok) {
        showError(result.error || 'Failed to use item.');
        return;
    }

    playerSnapshot = result.snapshot;
    selected = null;
    renderAll();
}

async function dropItem(slot, count) {
    clearError();
    const result = await nuiCallback('dropItem', { slot, count });

    if (!result.ok) {
        showError(result.error || 'Failed to drop item.');
        return;
    }

    playerSnapshot = result.snapshot;
    selected = null;
    renderAll();
}

async function splitStack(slot, count) {
    clearError();
    const result = await nuiCallback('splitStack', { slot, count });

    if (!result.ok) {
        showError(result.error || 'Failed to split stack.');
        return;
    }

    playerSnapshot = result.snapshot;
    selected = null;
    renderAll();
}

async function giveItem(slot, count) {
    clearError();
    const result = await nuiCallback('giveItem', { slot, count });

    if (!result.ok) {
        showError(result.error || 'Failed to give item.');
        return;
    }

    playerSnapshot = result.snapshot;
    selected = null;
    renderAll();
}

async function buyItem(item, count, account) {
    clearError();
    const result = await nuiCallback('buyItem', { shop: secondaryId, item, count, account });

    if (!result.ok) {
        showError(result.error || 'Failed to buy item.');
        return;
    }

    playerSnapshot = result.snapshot;
    renderAll();
}

searchInput.addEventListener('input', () => {
    searchTerm = searchInput.value.trim().toLowerCase();
    renderPlayerPane();
});

closeBtn.addEventListener('click', () => nuiCallback('close'));

viewGridBtn.addEventListener('click', () => {
    viewMode = 'grid';
    renderAll();
});

viewListBtn.addEventListener('click', () => {
    viewMode = 'list';
    renderAll();
});

qtyMinus.addEventListener('click', () => {
    qtyInput.value = Math.max(1, getQty() - 1);
});

qtyPlus.addEventListener('click', () => {
    const max = parseInt(qtyInput.max, 10) || 1;
    qtyInput.value = Math.min(max, getQty() + 1);
});

useItemBtn.addEventListener('click', () => {
    if (selected) useItem(selected.slot);
});

useBtn.addEventListener('click', () => {
    if (selected) useItem(selected.slot);
});

dropBtn.addEventListener('click', () => {
    if (selected) dropItem(selected.slot, getQty());
});

splitBtn.addEventListener('click', () => {
    if (selected) splitStack(selected.slot, getQty());
});

giveBtn.addEventListener('click', () => {
    if (selected) giveItem(selected.slot, getQty());
});

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open') {
        mode = data.mode;
        secondaryId = data.secondaryId;
        playerSnapshot = data.player;
        secondarySnapshot = data.secondary;
        shopData = data.shop;
        selected = null;
        searchTerm = '';
        searchInput.value = '';

        root.classList.remove('hidden');
        clearError();
        renderAll();
    } else if (data.action === 'close') {
        root.classList.add('hidden');
        mode = null;
        secondaryId = null;
        selected = null;
    } else if (data.action === 'notify') {
        showNotify(data.message);
    }
});

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape' && !root.classList.contains('hidden')) {
        nuiCallback('close');
    }
});
