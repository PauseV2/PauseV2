const hud = document.getElementById('hud');
const weaponPanel = document.getElementById('weapon-panel');
const weaponName = document.getElementById('weapon-name');
const weaponAmmo = document.getElementById('weapon-ammo');
const healthFill = document.getElementById('health-fill');
const armorFill = document.getElementById('armor-fill');
const micBtn = document.getElementById('mic-btn');
const staminaBtn = document.getElementById('stamina-btn');

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function setBar(el, value) {
  el.style.width = `${clamp(value, 0, 100)}%`;
}

function updateWeapon(weapon) {
  if (!weapon) {
    weaponPanel.classList.add('hidden');
    return;
  }
  weaponPanel.classList.remove('hidden');
  weaponName.textContent = weapon.label;
  weaponAmmo.textContent = `${weapon.clip} / ${weapon.total}`;
}

window.addEventListener('message', (event) => {
  const { action, data } = event.data;

  if (action === 'update') {
    setBar(healthFill, data.health);
    setBar(armorFill, data.armor);
    updateWeapon(data.weapon);
    micBtn.classList.toggle('active', !!data.talking);
    staminaBtn.classList.toggle('active', data.stamina < 30);
  } else if (action === 'visibility') {
    hud.classList.toggle('hidden', !data.show);
  }
});
