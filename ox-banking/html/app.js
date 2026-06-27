const root = document.getElementById('root');
const cashEl = document.getElementById('cash-balance');
const bankEl = document.getElementById('bank-balance');
const amountInput = document.getElementById('amount');
const errorEl = document.getElementById('error');

function resourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'ox-banking';
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

function renderMoney(money) {
    cashEl.textContent = `$${money.cash || 0}`;
    bankEl.textContent = `$${money.bank || 0}`;
}

document.getElementById('deposit-btn').addEventListener('click', async () => {
    clearError();
    const amount = parseInt(amountInput.value, 10);
    const result = await nuiCallback('deposit', { amount });

    if (!result.ok) {
        showError(result.error || 'Deposit failed.');
        return;
    }

    renderMoney(result.money);
    amountInput.value = '';
});

document.getElementById('withdraw-btn').addEventListener('click', async () => {
    clearError();
    const amount = parseInt(amountInput.value, 10);
    const result = await nuiCallback('withdraw', { amount });

    if (!result.ok) {
        showError(result.error || 'Withdraw failed.');
        return;
    }

    renderMoney(result.money);
    amountInput.value = '';
});

document.getElementById('close-btn').addEventListener('click', () => {
    nuiCallback('close');
});

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open') {
        root.classList.remove('hidden');
        clearError();
        renderMoney(data.money || {});
    } else if (data.action === 'close') {
        root.classList.add('hidden');
    }
});

document.addEventListener('keyup', (event) => {
    if (event.key === 'Escape' && !root.classList.contains('hidden')) {
        nuiCallback('close');
    }
});
