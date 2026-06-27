document.addEventListener('DOMContentLoaded', function () {
  var form = document.getElementById('ContactForm');
  if (!form) return;

  var typeSwitch = document.getElementById('ContactFormCustomerType');
  var typeLabels = form.querySelectorAll('[data-type-label]');
  var companyInput = document.getElementById('ContactFormCompany');
  var kvkInput = document.getElementById('ContactFormKvk');
  var messageInput = document.getElementById('ContactFormMessage');
  var headerPattern = /^Type aanvraag: (Particulier|Zakelijk)\n(Bedrijfsnaam:.*\nKVK-nummer:.*\n)?\n/;
  var NA = 'N.v.t.';

  function isBusiness() {
    return !!typeSwitch && typeSwitch.checked;
  }

  function updateBusinessFields() {
    var business = isBusiness();
    [companyInput, kvkInput].forEach(function (input) {
      if (!input) return;
      input.disabled = !business;
      input.value = business ? '' : NA;
    });
    if (companyInput) companyInput.required = business;
    typeLabels.forEach(function (label) {
      var isActive = label.getAttribute('data-type-label') === (business ? 'zakelijk' : 'particulier');
      label.classList.toggle('is-active', isActive);
    });
  }

  if (typeSwitch) {
    typeSwitch.addEventListener('change', updateBusinessFields);
  }
  updateBusinessFields();

  form.addEventListener('submit', function () {
    if (!messageInput) return;
    var business = isBusiness();
    var header = 'Type aanvraag: ' + (business ? 'Zakelijk' : 'Particulier') + '\n';
    if (business) {
      header += 'Bedrijfsnaam: ' + (companyInput && companyInput.value ? companyInput.value : '-') + '\n';
      header += 'KVK-nummer: ' + (kvkInput && kvkInput.value ? kvkInput.value : '-') + '\n';
    }
    header += '\n';
    messageInput.value = header + messageInput.value.replace(headerPattern, '');
  });
});
