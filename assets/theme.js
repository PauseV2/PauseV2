document.addEventListener('DOMContentLoaded', function () {
  var burger = document.querySelector('.site-header__burger');
  var nav = document.getElementById('MobileNav');

  if (burger && nav) {
    burger.addEventListener('click', function () {
      var isOpen = burger.getAttribute('aria-expanded') === 'true';
      burger.setAttribute('aria-expanded', String(!isOpen));
      nav.hidden = isOpen;
    });
  }
});
