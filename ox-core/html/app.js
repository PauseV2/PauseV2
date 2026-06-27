const root = document.getElementById('root');
const slotsEl = document.getElementById('slots');
const createForm = document.getElementById('create-form');
const errorEl = document.getElementById('error');

let currentList = [];
let maxSlots = 3;

function resourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'ox-core';
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

function renderSlots() {
    slotsEl.innerHTML = '';

    for (let i = 0; i < maxSlots; i++) {
        const character = currentList[i];
        const card = document.createElement('div');
        card.className = 'slot';

        if (character) {
            const info = character.charinfo || {};
            card.innerHTML = `
                <div class="slot-name">${info.firstname || ''} ${info.lastname || ''}</div>
                <div class="slot-job">${character.job ? character.job.label : ''}</div>
                <div class="slot-actions">
                    <button class="select-btn">Play</button>
                    <button class="delete-btn">Delete</button>
                </div>
            `;
            card.querySelector('.select-btn').addEventListener('click', () => selectCharacter(character.citizenid));
            card.querySelector('.delete-btn').addEventListener('click', () => deleteCharacter(character.citizenid));
        } else {
            card.classList.add('empty');
            card.innerHTML = `<div class="slot-name">Empty Slot</div><button class="create-btn">Create Character</button>`;
            card.querySelector('.create-btn').addEventListener('click', openCreateForm);
        }

        slotsEl.appendChild(card);
    }
}

function openCreateForm() {
    clearError();
    createForm.classList.remove('hidden');
    slotsEl.classList.add('hidden');
}

function closeCreateForm() {
    createForm.classList.add('hidden');
    slotsEl.classList.remove('hidden');
    createForm.reset();
}

async function selectCharacter(citizenid) {
    clearError();
    const result = await nuiCallback('selectCharacter', { citizenid });
    if (!result.ok) {
        showError(result.error || 'Failed to load character.');
    }
}

async function deleteCharacter(citizenid) {
    clearError();
    const result = await nuiCallback('deleteCharacter', { citizenid });
    if (!result.ok) {
        showError(result.error || 'Failed to delete character.');
    }
}

createForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    clearError();

    const formData = new FormData(createForm);
    const data = Object.fromEntries(formData.entries());

    const result = await nuiCallback('createCharacter', data);
    if (!result.ok) {
        showError(result.error || 'Failed to create character.');
        return;
    }

    closeCreateForm();
});

document.getElementById('cancel-create').addEventListener('click', closeCreateForm);

window.addEventListener('message', (event) => {
    const { action, list, maxSlots: slots } = event.data;

    if (action === 'open') {
        root.classList.remove('hidden');
    } else if (action === 'close') {
        root.classList.add('hidden');
        nuiCallback('closeMenu');
    } else if (action === 'characters') {
        currentList = list || [];
        if (typeof slots === 'number') {
            maxSlots = slots;
        }
        renderSlots();
    }
});
