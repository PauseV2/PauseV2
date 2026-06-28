const root = document.getElementById('root');

const inventoryTitle = document.getElementById('inventory-title');
const weightFill = document.getElementById('weight-fill');
const weightText = document.getElementById('weight-text');
const closeBtn = document.getElementById('close-btn');
const tabsEl = document.getElementById('tabs');
const mainGrid = document.getElementById('main-grid');
const amountInput = document.getElementById('amount-input');
const useBtn = document.getElementById('use-btn');
const giveBtn = document.getElementById('give-btn');

const hotbarSection = document.getElementById('hotbar-section');
const hotbarGrid = document.getElementById('hotbar-grid');

const secondaryTitle = document.getElementById('secondary-title');
const secondaryWeightText = document.getElementById('secondary-weight-text');
const secondaryHint = document.getElementById('secondary-hint');
const secondaryGrid = document.getElementById('secondary-grid');

const shopSection = document.getElementById('shop-section');
const shopTitle = document.getElementById('shop-title');
const shopAccountSelect = document.getElementById('shop-account-select');
const shopList = document.getElementById('shop-list');

const errorEl = document.getElementById('inv-error');
const notifyEl = document.getElementById('inv-notify');

const TABS = [
    { id: 'all', label: 'All' },
    { id: 'weapon', label: 'Weapons' },
    { id: 'consumable', label: 'Consumables' },
    { id: 'ammo', label: 'Ammo' },
    { id: 'misc', label: 'Misc' },
];

let mode = null;
let secondaryId = null;
let playerSnapshot = null;
let secondarySnapshot = null;
let shopData = null;
let hotbar = {};
let selected = null; // { inv: 'player'|secondaryId, slot }
let activeTab = 'all';

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

function fmtKg(grams, decimals) {
    return (grams / 1000).toFixed(decimals === undefined ? 1 : decimals);
}

function categoryOf(entry) {
    if (entry.type === 'weapon') return 'weapon';
    if (entry.type === 'food' || entry.type === 'drink' || entry.type === 'medical') return 'consumable';
    if (entry.type === 'ammo') return 'ammo';
    return 'misc';
}

function setupGridDropTarget(el, invId, slot) {
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

function renderSlotGrid(container, snapshot, invId, filterTab) {
    container.innerHTML = '';
    if (!snapshot) return;

    for (let slot = 1; slot <= snapshot.slots; slot++) {
        const entry = findEntry(snapshot, slot);
        const slotEl = document.createElement('div');
        slotEl.className = 'slot';

        if (entry) {
            if (filterTab && filterTab !== 'all' && categoryOf(entry) !== filterTab) {
                slotEl.style.display = 'none';
            }

            slotEl.classList.add('has-item');
            slotEl.draggable = true;
            slotEl.innerHTML = `
                <div class="slot-count">x${entry.count}</div>
                <div class="slot-label">${entry.label}</div>
            `;

            slotEl.addEventListener('dragstart', (event) => {
                event.dataTransfer.setData('text/plain', JSON.stringify({ inv: invId, slot }));
            });

            slotEl.addEventListener('contextmenu', (event) => {
                event.preventDefault();
                if (invId === 'player') assignToFirstHotbarSlot(slot);
            });
        }

        if (selected && selected.inv === invId && selected.slot === slot) {
            slotEl.classList.add('selected');
        }

        slotEl.addEventListener('click', () => onSlotClick(invId, slot, !!entry));
        setupGridDropTarget(slotEl, invId, slot);
        container.appendChild(slotEl);
    }
}

function renderMainGrid() {
    renderSlotGrid(mainGrid, playerSnapshot, 'player', activeTab);
}

function renderTabs() {
    tabsEl.innerHTML = '';

    TABS.forEach((tab) => {
        const btn = document.createElement('button');
        btn.className = 'tab-btn' + (activeTab === tab.id ? ' active' : '');
        btn.textContent = tab.label;
        btn.addEventListener('click', () => {
            activeTab = tab.id;
            renderAll();
        });
        tabsEl.appendChild(btn);
    });
}

function renderHeader() {
    if (!playerSnapshot) return;

    const pct = Math.min(100, (playerSnapshot.weight / playerSnapshot.maxWeight) * 100);
    weightFill.style.width = `${pct}%`;
    weightText.textContent = `Weight: ${fmtKg(playerSnapshot.weight)}/${fmtKg(playerSnapshot.maxWeight, 0)}kg`;
    inventoryTitle.textContent = mode === 'shop' ? 'Shop' : 'Inventory';
}

function renderSecondaryPanel() {
    const hasSecondary = (mode === 'stash' || mode === 'ground' || mode === 'trunk') && secondarySnapshot;

    secondaryHint.classList.toggle('hidden', !!hasSecondary);
    secondaryGrid.classList.toggle('hidden', !hasSecondary);

    if (hasSecondary) {
        secondaryTitle.textContent = secondarySnapshot.label;
        secondaryWeightText.textContent = `${fmtKg(secondarySnapshot.weight, 0)}/${fmtKg(secondarySnapshot.maxWeight, 0)}kg`;
        renderSlotGrid(secondaryGrid, secondarySnapshot, secondaryId, null);
    } else {
        secondaryTitle.textContent = 'Storage';
        secondaryWeightText.textContent = '';
        secondaryGrid.innerHTML = '';
    }
}

function renderHotbarGrid() {
    hotbarGrid.innerHTML = '';

    for (let i = 1; i <= 5; i++) {
        const slotNum = hotbar[i];
        const entry = slotNum ? findEntry(playerSnapshot, slotNum) : null;
        const el = document.createElement('div');
        el.className = 'hotbar-slot';
        el.innerHTML = `<div class="hotbar-index">${i}</div>` + (entry ? `<div class="slot-label">${entry.label}</div>` : '');

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
            if (from.inv !== 'player') return;

            assignHotbar(i, from.slot);
        });

        el.addEventListener('contextmenu', (event) => {
            event.preventDefault();
            if (slotNum) clearHotbarSlot(i);
        });

        hotbarGrid.appendChild(el);
    }
}

function assignToFirstHotbarSlot(slot) {
    for (let i = 1; i <= 5; i++) {
        if (!hotbar[i]) {
            assignHotbar(i, slot);
            return;
        }
    }

    showNotify('Hotbar is full.');
}

function renderShop() {
    shopList.innerHTML = '';
    if (!shopData) return;

    shopTitle.textContent = shopData.label;

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
            buyItem(item.name, qty, shopAccountSelect.value);
        });

        shopList.appendChild(row);
    });
}

function renderBottomPanel() {
    hotbarSection.classList.toggle('hidden', mode !== 'inventory');
    shopSection.classList.toggle('hidden', mode !== 'shop');

    if (mode === 'shop') {
        renderShop();
    } else {
        renderHotbarGrid();
    }
}

function renderActionRow() {
    const entry = selected && selected.inv === 'player' && findEntry(playerSnapshot, selected.slot);

    useBtn.disabled = !entry;
    giveBtn.disabled = !entry;

    if (entry) {
        amountInput.max = entry.count;
        const current = parseInt(amountInput.value, 10) || 1;
        amountInput.value = Math.min(Math.max(1, current), entry.count);
    }
}

function renderAll() {
    renderSecondaryPanel();
    renderTabs();
    renderHeader();
    renderMainGrid();
    renderActionRow();
    renderBottomPanel();
}

function onSlotClick(invId, slot, hasItem) {
    clearError();

    if (selected && selected.inv === invId && selected.slot === slot) {
        selected = null;
        renderAll();
        return;
    }

    selected = hasItem ? { inv: invId, slot } : null;
    renderAll();
}

function getAmount() {
    return parseInt(amountInput.value, 10) || 1;
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

async function assignHotbar(index, slot) {
    await nuiCallback('setHotbar', { index, slot });
    hotbar[index] = slot;
    renderHotbarGrid();
}

async function clearHotbarSlot(index) {
    await nuiCallback('clearHotbar', { index });
    hotbar[index] = null;
    renderHotbarGrid();
}

closeBtn.addEventListener('click', () => nuiCallback('close'));

useBtn.addEventListener('click', () => {
    if (selected) useItem(selected.slot);
});

giveBtn.addEventListener('click', () => {
    if (selected) giveItem(selected.slot, getAmount());
});

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open') {
        mode = data.mode;
        secondaryId = data.secondaryId;
        playerSnapshot = data.player;
        secondarySnapshot = data.secondary;
        shopData = data.shop;
        hotbar = data.hotbar || {};
        selected = null;
        activeTab = 'all';

        root.classList.remove('hidden');
        clearError();
        renderAll();
    } else if (data.action === 'close') {
        root.classList.add('hidden');
        mode = null;
        secondaryId = null;
        selected = null;
    } else if (data.action === 'hotbar') {
        hotbar = data.hotbar || {};
        renderHotbarGrid();
    } else if (data.action === 'notify') {
        showNotify(data.message);
    }
});

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape' && !root.classList.contains('hidden')) {
        nuiCallback('close');
    }
});
