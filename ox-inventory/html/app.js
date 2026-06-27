const root = document.getElementById('root');
const playerGrid = document.getElementById('player-grid');
const playerWeightFill = document.getElementById('player-weight-fill');
const playerWeightText = document.getElementById('player-weight-text');

const contextPane = document.getElementById('context-pane');
const contextTitle = document.getElementById('context-title');
const contextWeightWrap = document.getElementById('context-weight-wrap');
const contextWeightFill = document.getElementById('context-weight-fill');
const contextWeightText = document.getElementById('context-weight-text');
const contextGrid = document.getElementById('context-grid');
const shopList = document.getElementById('shop-list');
const errorEl = document.getElementById('inv-error');

let mode = null;
let secondaryId = null;
let playerSnapshot = null;
let secondarySnapshot = null;
let shopData = null;
let selected = null; // { inv: 'player'|secondaryId, slot }

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

function showError(message) {
    errorEl.textContent = message;
    errorEl.classList.remove('hidden');
}

function clearError() {
    errorEl.classList.add('hidden');
    errorEl.textContent = '';
}

function findEntry(snapshot, slot) {
    return snapshot && snapshot.items.find((entry) => entry.slot === slot);
}

function renderGrid(container, snapshot, invId) {
    container.innerHTML = '';
    if (!snapshot) return;

    for (let slot = 1; slot <= snapshot.slots; slot++) {
        const entry = findEntry(snapshot, slot);
        const slotEl = document.createElement('div');
        slotEl.className = 'slot';

        if (entry) {
            slotEl.classList.add('has-item');
            slotEl.innerHTML = `
                <div class="slot-label">${entry.label}</div>
                <div class="slot-count">x${entry.count}</div>
            `;

            if (invId === 'player') {
                const useBtn = document.createElement('button');
                useBtn.className = 'use-btn';
                useBtn.textContent = 'Use';
                useBtn.addEventListener('click', (event) => {
                    event.stopPropagation();
                    useItem(slot);
                });
                slotEl.appendChild(useBtn);
            }
        }

        if (selected && selected.inv === invId && selected.slot === slot) {
            slotEl.classList.add('selected');
        }

        slotEl.addEventListener('click', () => onSlotClick(invId, slot, !!entry));
        container.appendChild(slotEl);
    }
}

function renderWeight(fillEl, textEl, snapshot) {
    const pct = snapshot ? Math.min(100, (snapshot.weight / snapshot.maxWeight) * 100) : 0;
    fillEl.style.width = `${pct}%`;
    textEl.textContent = snapshot ? `${(snapshot.weight / 1000).toFixed(1)} / ${(snapshot.maxWeight / 1000).toFixed(1)} kg` : '';
}

function renderShop() {
    shopList.innerHTML = '';
    if (!shopData) return;

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

function renderAll() {
    renderGrid(playerGrid, playerSnapshot, 'player');
    renderWeight(playerWeightFill, playerWeightText, playerSnapshot);

    if (mode === 'stash') {
        contextPane.classList.remove('hidden');
        contextGrid.classList.remove('hidden');
        shopList.classList.add('hidden');
        contextWeightWrap.classList.remove('hidden');
        contextTitle.textContent = secondarySnapshot ? secondarySnapshot.label : '';
        renderGrid(contextGrid, secondarySnapshot, secondaryId);
        renderWeight(contextWeightFill, contextWeightText, secondarySnapshot);
    } else if (mode === 'shop') {
        contextPane.classList.remove('hidden');
        contextGrid.classList.add('hidden');
        contextWeightWrap.classList.add('hidden');
        shopList.classList.remove('hidden');
        contextTitle.textContent = shopData ? shopData.label : '';
        renderShop();
    } else {
        contextPane.classList.add('hidden');
    }
}

function onSlotClick(invId, slot, hasItem) {
    clearError();

    if (selected) {
        if (selected.inv === invId && selected.slot === slot) {
            selected = null;
            renderAll();
            return;
        }

        moveItem(selected.inv, selected.slot, invId, slot);
        selected = null;
        return;
    }

    if (hasItem) {
        selected = { inv: invId, slot };
        renderAll();
    }
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

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open') {
        mode = data.mode;
        secondaryId = data.secondaryId;
        playerSnapshot = data.player;
        secondarySnapshot = data.secondary;
        shopData = data.shop;
        selected = null;

        root.classList.remove('hidden');
        clearError();
        renderAll();
    } else if (data.action === 'close') {
        root.classList.add('hidden');
        mode = null;
        secondaryId = null;
        selected = null;
    }
});

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape' && !root.classList.contains('hidden')) {
        nuiCallback('close');
    }
});
