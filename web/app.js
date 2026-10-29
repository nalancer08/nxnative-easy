(() => {
  'use strict';
  const root = document.documentElement;
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  let paused = false;
  try { paused = localStorage.getItem('nxe-motion') === 'paused'; } catch (_) {}
  const motionButton = document.querySelector('#motion-toggle');
  const lang = root.lang;
  function setMotion() {
    document.body.classList.toggle('paused', paused || reduced.matches);
    motionButton.setAttribute('aria-pressed', String(paused));
    motionButton.querySelector('span').textContent = paused ? (lang === 'es' ? 'Activar animaciones' : 'Play animation') : (lang === 'es' ? 'Pausar animaciones' : 'Pause animation');
  }
  motionButton.addEventListener('click', () => {
    paused = !paused;
    try { localStorage.setItem('nxe-motion', paused ? 'paused' : 'play'); } catch (_) {}
    setMotion();
  });
  reduced.addEventListener('change', setMotion);
  setMotion();
  if ('IntersectionObserver' in window && !reduced.matches) {
    root.classList.add('motion');
    const observer = new IntersectionObserver(entries => entries.forEach(entry => {
      if (entry.isIntersecting) { entry.target.classList.add('visible'); observer.unobserve(entry.target); }
    }), { threshold: 0.08 });
    document.querySelectorAll('.reveal').forEach(el => observer.observe(el));
  }
  let frame = false;
  function scrollFrame() {
    const max = root.scrollHeight - innerHeight;
    document.querySelector('.scroll-progress').style.transform = `scaleX(${max > 0 ? scrollY / max : 0})`;
    frame = false;
  }
  addEventListener('scroll', () => { if (!frame) { requestAnimationFrame(scrollFrame); frame = true; } }, { passive: true });
  scrollFrame();
  if (matchMedia('(hover: hover) and (pointer: fine)').matches) {
    document.querySelectorAll('[data-tilt]').forEach(el => {
      el.addEventListener('pointermove', event => {
        if (paused || reduced.matches) return;
        const box = el.getBoundingClientRect();
        const x = (event.clientX - box.left) / box.width - 0.5;
        const y = (event.clientY - box.top) / box.height - 0.5;
        el.style.transform = `perspective(1400px) rotateX(${-y * 4}deg) rotateY(${x * 5}deg)`;
      });
      el.addEventListener('pointerleave', () => { el.style.transform = ''; });
    });
  }
  const tabs = [...document.querySelectorAll('[role="tab"]')];
  function selectTab(selected) {
    tabs.forEach(tab => {
      const active = selected === tab;
      tab.setAttribute('aria-selected', String(active)); tab.tabIndex = active ? 0 : -1;
      document.getElementById(tab.getAttribute('aria-controls')).hidden = !active;
    });
  }
  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => selectTab(tab));
    tab.addEventListener('keydown', event => {
      if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
      event.preventDefault();
      const next = event.key === 'Home' ? tabs[0] : event.key === 'End' ? tabs[tabs.length - 1] : tabs[(index + (event.key === 'ArrowRight' ? 1 : tabs.length - 1)) % tabs.length];
      selectTab(next); next.focus();
    });
  });
  const search = document.querySelector('#game-search');
  const cards = [...document.querySelectorAll('.game-card')];
  const all = document.querySelector('#view-all');
  const count = document.querySelector('#game-count');
  let expanded = false;
  const normalize = value => value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  function filter() {
    const query = normalize(search.value.trim()); let matches = 0;
    cards.forEach((card, index) => {
      const match = normalize(card.dataset.search).includes(query);
      if (match) matches++;
      card.hidden = !match || (!query && !expanded && index >= 12);
    });
    count.textContent = `${matches} ${matches === 1 ? (lang === 'es' ? 'juego' : 'game') : count.dataset.label}`;
    document.querySelector('#empty-games').hidden = matches !== 0;
    all.hidden = Boolean(query);
    all.setAttribute('aria-expanded', String(expanded));
    all.replaceChildren(document.createTextNode(expanded ? all.dataset.less : all.dataset.all));
    const icon = document.createElement('span'); icon.textContent = expanded ? '−' : '＋'; all.appendChild(icon);
  }
  search.addEventListener('input', filter);
  all.addEventListener('click', () => { expanded = !expanded; filter(); });
  filter();
})();
