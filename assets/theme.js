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

  function animateCount(el) {
    var raw = el.getAttribute('data-count-to') || '';
    var target = parseInt(raw.replace(/[^0-9]/g, ''), 10);
    if (isNaN(target)) {
      el.textContent = raw;
      return;
    }
    var suffix = raw.replace(/^[0-9]+/, '');
    var duration = 1200;
    var start = null;

    function step(timestamp) {
      if (start === null) start = timestamp;
      var progress = Math.min((timestamp - start) / duration, 1);
      el.textContent = Math.floor(progress * target) + suffix;
      if (progress < 1) {
        requestAnimationFrame(step);
      } else {
        el.textContent = target + suffix;
      }
    }
    requestAnimationFrame(step);
  }

  var animatedEls = document.querySelectorAll('[data-animate]');
  var counterEls = document.querySelectorAll('[data-count-to]');

  if ('IntersectionObserver' in window) {
    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          entry.target.classList.add('is-visible');
          var counter = entry.target.querySelector('[data-count-to]');
          if (counter) animateCount(counter);
          observer.unobserve(entry.target);
        });
      },
      { threshold: 0.25 }
    );
    animatedEls.forEach(function (el) { observer.observe(el); });
  } else {
    animatedEls.forEach(function (el) { el.classList.add('is-visible'); });
    counterEls.forEach(function (el) { el.textContent = el.getAttribute('data-count-to'); });
  }
});
