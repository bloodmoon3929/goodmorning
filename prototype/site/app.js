// 굿모닝 정적 프로토타입 뷰어: FigCraft에서 내보낸 화면 PNG 위에 클릭 영역을 올려 화면을 잇는다.
// 화면 목록과 클릭 영역은 prototype/figcraft/build.py 가 쓰는 screens.json 에서 읽는다.
(function () {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const els = {
    viewport: $('viewport'), screen: $('screen'), img: $('screen-img'), hotspots: $('hotspots'),
    caption: $('caption'), list: $('list'), source: $('source'), hints: $('chk-hints'),
    back: $('btn-back'), restart: $('btn-restart'), appLink: $('app-link'), phone: $('phone'),
  };

  let data = null;
  let bySlug = {};
  let depth = 0; // 이 뷰어 안에서 앞으로 간 횟수 (뒤로 가기가 뷰어 밖으로 나가지 않게)

  const titleOf = (s) => (s.slide ? `#${s.slide} ` : '') + s.title;

  function slugFromHash() {
    const m = location.hash.match(/^#\/?([\w-]+)/);
    return m && bySlug[m[1]] ? m[1] : data.start;
  }

  function go(slug) {
    if (slug === 'back') { back(); return; }
    if (!bySlug[slug] || slug === slugFromHash()) return;
    depth += 1;
    location.hash = '/' + slug;
  }

  function back() {
    if (depth > 0) { depth -= 1; history.back(); }
    else { location.hash = '/' + data.start; }
  }

  function render() {
    const slug = slugFromHash();
    const s = bySlug[slug];
    els.img.src = s.image;
    els.img.alt = s.title;
    els.img.style.height = (s.height * (390 / data.width)) + 'px';
    els.hotspots.innerHTML = '';
    for (const h of s.hotspots) {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'hotspot';
      Object.assign(b.style, { left: h.x + 'px', top: h.y + 'px', width: h.w + 'px', height: h.h + 'px' });
      const target = h.to === 'back' ? '뒤로' : titleOf(bySlug[h.to]);
      b.title = target;
      b.setAttribute('aria-label', target);
      b.addEventListener('click', (e) => { e.stopPropagation(); go(h.to); });
      els.hotspots.appendChild(b);
    }
    els.screen.scrollTop = 0;
    els.caption.innerHTML = `<b>${escapeHtml(titleOf(s))}</b><br>${escapeHtml(s.desc || '')}`;
    document.title = `${s.title} · 굿모닝 프로토타입`;
    for (const a of els.list.querySelectorAll('a')) a.classList.toggle('current', a.dataset.slug === slug);
  }

  function escapeHtml(t) {
    return String(t).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }

  function buildList() {
    els.list.innerHTML = '';
    for (const s of data.screens) {
      const li = document.createElement('li');
      const a = document.createElement('a');
      a.href = '#/' + s.slug;
      a.dataset.slug = s.slug;
      a.innerHTML = `<span class="num">${s.slide ? '#' + s.slide : ''}</span><span>${escapeHtml(s.title)}</span>`;
      a.addEventListener('click', (e) => { e.preventDefault(); go(s.slug); });
      li.appendChild(a);
      els.list.appendChild(li);
    }
    els.source.textContent = `원본: ${data.source}`;
  }

  function fitPhone() {
    const top = document.querySelector('.topbar').offsetHeight;
    const availH = window.innerHeight - top - 90;
    const availW = els.phone.parentElement.clientWidth;
    const scale = Math.max(0.45, Math.min(1, availH / (844 + 24), availW / (390 + 24)));
    document.documentElement.style.setProperty('--scale', scale.toFixed(3));
  }

  function flashHints() {
    if (els.hints.checked) return;
    els.screen.classList.remove('flash');
    void els.screen.offsetWidth;
    els.screen.classList.add('flash');
  }

  function setHints(on) {
    els.hints.checked = on;
    els.screen.classList.toggle('show-hints', on);
    try { localStorage.setItem('gm-hints', on ? '1' : '0'); } catch (e) { /* 저장 안 돼도 동작 */ }
  }

  async function init() {
    if (window.GM_SCREENS) {
      data = window.GM_SCREENS;
    } else {
      const res = await fetch('screens.json', { cache: 'no-cache' });
      data = await res.json();
    }
    bySlug = Object.fromEntries(data.screens.map((s) => [s.slug, s]));
    buildList();
    let saved = '0';
    try { saved = localStorage.getItem('gm-hints') || '0'; } catch (e) { /* 무시 */ }
    setHints(saved === '1');
    window.addEventListener('hashchange', render);
    window.addEventListener('resize', fitPhone);
    els.screen.addEventListener('click', flashHints);
    els.back.addEventListener('click', back);
    els.restart.addEventListener('click', () => { depth = 0; location.hash = '/' + data.start; });
    els.hints.addEventListener('change', () => setHints(els.hints.checked));
    document.addEventListener('keydown', (e) => {
      if (e.target.closest('input, textarea')) return;
      if (e.key === 'ArrowLeft' || e.key === 'Backspace') { e.preventDefault(); back(); }
      if (e.key === 'h' || e.key === 'H') setHints(!els.hints.checked);
    });
    if (!location.hash) history.replaceState(null, '', '#/' + data.start);
    fitPhone();
    render();
    // 다음 화면이 바로 뜨도록 나머지 화면 그림을 미리 받아 둔다
    for (const s of data.screens) { const i = new Image(); i.src = s.image; }
    // Flutter 앱이 함께 배포되어 있으면 링크를 보인다
    fetch('app/index.html', { method: 'HEAD' }).then((r) => { if (r.ok) els.appLink.hidden = false; }).catch(() => {});
  }

  init().catch((err) => {
    els.caption.textContent = '화면 목록(screens.json)을 불러오지 못했어요: ' + err.message;
  });
})();
