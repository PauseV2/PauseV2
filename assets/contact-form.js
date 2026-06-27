document.addEventListener('DOMContentLoaded', function () {
  var form = document.getElementById('ContactForm');
  if (!form) return;

  var typeInputs = form.querySelectorAll('input[name="contact[customer_type]"]');
  var businessFields = form.querySelectorAll('.field--business');
  var companyInput = document.getElementById('ContactFormCompany');
  var kvkInput = document.getElementById('ContactFormKvk');
  var messageInput = document.getElementById('ContactFormMessage');
  var headerPattern = /^Type aanvraag: (Particulier|Zakelijk)\n(Bedrijfsnaam:.*\nKVK-nummer:.*\n)?\n/;

  function isBusiness() {
    var checked = form.querySelector('input[name="contact[customer_type]"]:checked');
    return !!checked && checked.value === 'zakelijk';
  }

  function updateBusinessFields() {
    var business = isBusiness();
    businessFields.forEach(function (field) {
      field.hidden = !business;
    });
    if (companyInput) companyInput.required = business;
  }

  typeInputs.forEach(function (input) {
    input.addEventListener('change', updateBusinessFields);
  });
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
