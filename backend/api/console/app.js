// 굿모닝 관리자 페이지 — /admin/* API만 쓴다 (빌드 단계 없음)
'use strict';

const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const won = (v) => (v == null ? '알 수 없음' : `${Number(v).toLocaleString('ko-KR')}원`);
const hhmmss = (iso) => new Date(iso).toLocaleTimeString('ko-KR', { hour12: false });
const ago = (iso) => {
  const s = Math.max(0, Math.round((Date.now() - new Date(iso)) / 1000));
  return s < 60 ? `${s}초 전` : s < 3600 ? `${Math.round(s / 60)}분 전` : `${Math.round(s / 3600)}시간 전`;
};

const PIPELINES = {
  crawl: [
    ['target', '대상 확인', 'crawl_allowed · sites'],
    ['robots', 'robots.txt', '규칙 받기 · 지키기'],
    ['request', '페이지 요청', 'Scrapy · Playwright'],
    ['response', '응답', '상태 · 크기 · 시간'],
    ['parse', '파싱', 'CSS 선택자'],
    ['save', 'DB 저장', 'ingest.raw_listing'],
    ['done', '끝', '몰별 작업 기록'],
  ],
  shopify: [
    ['start', '시작', '상점 · 검색어'],
    ['fx', '환율', 'ECB 기준 (키 없음)'],
    ['api_request', 'API 요청', 'products.json 쪽마다'],
    ['api_response', '응답', '상품 250개씩'],
    ['parse', '거르기', '검색어 낱말'],
    ['save', 'DB 저장', 'ingest.raw_listing'],
    ['done', '끝', '실행 기록'],
  ],
  api: [
    ['start', '시작', '검색어 · 호출 한도'],
    ['sign', 'HMAC 서명', '시크릿은 안 보냄'],
    ['api_request', 'API 요청', 'GET + Authorization'],
    ['api_response', '응답', 'JSON · 상품 목록'],
    ['save', 'DB 저장', 'ingest.raw_listing'],
    ['done', '끝', '실행 기록'],
  ],
};
const KIND = { crawl: '크롤링', api: '쇼핑 API' };
const PROVIDER = { coupang: '쿠팡 파트너스', chiikawa_market: '치이카와 마켓 공개 API' };
const kindLabel = (r) => (r.kind === 'api' ? PROVIDER[r.params?.provider] || '쇼핑 API' : '크롤링');
const pipelineOf = (r) => (r.kind === 'api' && r.params?.provider === 'chiikawa_market' ? PIPELINES.shopify : PIPELINES[r.kind]);
const STATUS = { queued: '대기 중', running: '실행 중', success: '끝남', failed: '실패' };
const STATE = { pending: '매칭 대기', review: '검토', matched: '연결됨', rejected: '제외' };

// API 서버가 내려준 페이지(/console/)면 같은 서버, GitHub Pages면 이 PC에서 띄운 API 서버 주소
const ON_API = location.pathname.startsWith('/console');
let API = ON_API ? '' : (localStorage.getItem('gm-api-base') || 'http://localhost:8080');

const st = {
  token: sessionStorage.getItem('gm-admin-token'),
  kind: 'crawl',
  runId: null,
  run: null,
  events: [],
  lastEvent: 0,
  selected: null,
  timer: null,
};

async function api(path, opts = {}) {
  const res = await fetch(API + path, {
    ...opts,
    headers: { 'Content-Type': 'application/json', ...(st.token ? { Authorization: `Bearer ${st.token}` } : {}) },
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  const data = res.status === 204 ? null : await res.json().catch(() => null);
  if (res.status === 401) {
    showLogin();
    throw new Error('로그인이 필요합니다');
  }
  if (!res.ok) throw new Error(data?.message || `HTTP ${res.status}`);
  return data;
}

// ---------------------------------------------------------------- 로그인
function showLogin() {
  st.token = null;
  sessionStorage.removeItem('gm-admin-token');
  $('login').hidden = false;
  $('app').hidden = true;
  $('logout').hidden = true;
}

if (!ON_API) {
  $('apiBox').hidden = false;
  $('apiHint').hidden = false;
  $('apiBase').value = API;
  $('appLink').hidden = false;
}

$('loginForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  $('loginError').textContent = '';
  if (!ON_API) {
    API = $('apiBase').value.replace(/\/+$/, '');
    try { localStorage.setItem('gm-api-base', API); } catch { /* 저장 못 해도 이번에는 씀 */ }
  }
  try {
    const r = await api('/auth/login', { method: 'POST', body: { email: $('email').value, password: $('password').value } });
    if (r.user?.role !== 'admin') throw new Error('운영자 계정이 아닙니다');
    st.token = r.token;
    sessionStorage.setItem('gm-admin-token', r.token);
    start();
  } catch (err) {
    $('loginError').textContent = err instanceof TypeError ? `API 서버(${API || location.origin})에 연결할 수 없어요 — 서버가 떠 있는지 확인하세요` : err.message;
  }
});
$('logout').addEventListener('click', showLogin);

// ---------------------------------------------------------------- 수집기 상태 · 몰 · 실행 목록
async function refreshCollector() {
  try {
    const c = await api('/admin/collector');
    const pill = $('collector');
    pill.classList.toggle('on', c.worker_alive);
    pill.textContent = c.worker_alive
      ? `수집기 연결됨 · 대기 ${c.queued} · 실행 중 ${c.running}`
      : `수집기 꺼짐 — backend/collector에서 uv run python -m worker${c.queued ? ` (대기 ${c.queued})` : ''}`;
  } catch { /* 로그인 화면으로 넘어감 */ }
}

async function refreshMalls() {
  const { items } = await api('/admin/malls');
  const crawlMalls = items.filter((m) => m.source === 'crawl');
  const sel = $('mall');
  const cur = sel.value;
  sel.innerHTML = '<option value="">수집 허용된 몰 전체</option>' + crawlMalls.map((m) => `<option ${m.name === cur ? 'selected' : ''}>${esc(m.name)}</option>`).join('');
  $('malls').innerHTML = items
    .map(
      (m) => `<li>
      <span class="src ${m.source}">${m.source === 'crawl' ? '크롤링' : m.source === 'api' ? 'API' : '판매자'}</span>
      <span class="name"><b>${esc(m.name)}</b><span>${esc(m.site_url || '')} · 판매처 ${m.offer_count} · 원본 ${m.raw_count}</span></span>
      ${m.source === 'crawl' ? `<button class="switch" role="switch" aria-checked="${m.crawl_allowed}" aria-label="${esc(m.name)} 수집 허용" data-mall="${m.id}"></button>` : ''}
    </li>`,
    )
    .join('');
}

$('malls').addEventListener('click', async (e) => {
  const b = e.target.closest('.switch');
  if (!b) return;
  const next = b.getAttribute('aria-checked') !== 'true';
  b.setAttribute('aria-checked', String(next));
  try {
    await api(`/admin/malls/${b.dataset.mall}`, { method: 'PATCH', body: { crawl_allowed: next } });
  } catch (err) {
    b.setAttribute('aria-checked', String(!next));
    alert(err.message);
  }
});

async function refreshRuns() {
  const { items } = await api('/admin/collect-runs?limit=12');
  $('runs').innerHTML = items
    .map(
      (r) => `<li><button data-run="${r.id}" class="${r.id === st.runId ? 'on' : ''}">
      <b>#${r.id}</b> ${kindLabel(r)} <span class="badge ${r.status}">${STATUS[r.status]}</span>
      <span class="when">${r.item_count}건 · ${ago(r.created_at)}</span></button></li>`,
    )
    .join('') || '<li class="hint">아직 실행이 없어요</li>';
}

$('runs').addEventListener('click', (e) => {
  const b = e.target.closest('[data-run]');
  if (b) openRun(Number(b.dataset.run));
});

// ---------------------------------------------------------------- 수집 시작
document.querySelectorAll('.tabs [data-kind]').forEach((b) =>
  b.addEventListener('click', () => {
    st.kind = b.dataset.kind;
    document.querySelectorAll('.tabs [data-kind]').forEach((x) => {
      x.classList.toggle('on', x === b);
      x.setAttribute('aria-selected', String(x === b));
    });
    document.querySelectorAll('.crawl-only').forEach((x) => (x.hidden = st.kind !== 'crawl'));
    document.querySelectorAll('.api-only').forEach((x) => (x.hidden = st.kind !== 'api'));
    syncProvider();
  }),
);

function syncProvider() {
  const shop = st.kind === 'api' && $('provider').value === 'chiikawa_market';
  $('keyword').placeholder = shop ? '일본어 검색어 (예: ハチワレ マスコット)' : '비우면 카탈로그 상품명으로 검색';
  $('keyword').required = shop;
  $('apiDesc').textContent = shop
    ? '치이카와 마켓(일본 공식몰)의 공개 상품 목록을 2초 간격으로 받아 검색어로 거릅니다. 상품 이름이 일본어라 검색어도 일본어로. 엔화는 ECB 기준 환율로 원화로 바꿔 저장.'
    : '요청마다 HMAC-SHA256 서명. 한 번 실행에 호출 수 · 간격 제한. 키가 없으면 실행이 "키 없음"으로 실패합니다.';
}
$('provider').addEventListener('change', syncProvider);

$('runForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  $('runError').textContent = '';
  const body = { kind: st.kind, keyword: $('keyword').value || null, max_queries: Number($('maxQueries').value) || 3 };
  if (st.kind === 'crawl' && $('mall').value) body.mall = $('mall').value;
  if (st.kind === 'api') body.provider = $('provider').value;
  try {
    const r = await api('/admin/collect-runs', { method: 'POST', body });
    await refreshRuns();
    openRun(r.id);
  } catch (err) {
    $('runError').textContent = err.message;
  }
});

// ---------------------------------------------------------------- 실행 하나 보기 (1초마다 새 기록만 받아 온다)
function openRun(id) {
  clearTimeout(st.timer);
  Object.assign(st, { runId: id, run: null, events: [], lastEvent: 0, selected: null });
  $('empty').hidden = true;
  $('detail').hidden = false;
  $('events').innerHTML = '';
  $('inspect').innerHTML = '<p class="hint">기록을 고르세요.</p>';
  $('matchBox').hidden = true;
  document.querySelectorAll('#runs [data-run]').forEach((b) => b.classList.toggle('on', Number(b.dataset.run) === id));
  poll();
}

async function poll() {
  const id = st.runId;
  try {
    const d = await api(`/admin/collect-runs/${id}?after=${st.lastEvent}`);
    if (id !== st.runId) return;
    const wasActive = st.run && ['queued', 'running'].includes(st.run.status);
    st.run = d.run;
    for (const ev of d.events) {
      st.events.push(ev);
      st.lastEvent = ev.id;
      appendEvent(ev);
    }
    renderHead(d.jobs);
    renderPipeline();
    const active = ['queued', 'running'].includes(d.run.status);
    if (d.events.some((e) => e.step === 'save') || !active || wasActive !== active) await refreshResults();
    if (active) {
      st.timer = setTimeout(poll, 800);
    } else if (wasActive) {
      refreshRuns();
      refreshMalls();
    }
  } catch (err) {
    st.timer = setTimeout(poll, 2000);
  }
}

function renderHead(jobs) {
  const r = st.run;
  const p = r.params || {};
  $('runTitle').textContent = `#${r.id} ${kindLabel(r)}`;
  const what = [p.mall || (r.kind === 'crawl' ? '수집 허용된 몰 전체' : '쇼핑 API'), p.keyword ? `검색어 "${p.keyword}"` : `카탈로그 검색어 ${p.max_queries}개`];
  const time = r.finished_at ? `${Math.round((new Date(r.finished_at) - new Date(r.started_at)) / 1000)}초 걸림` : r.started_at ? `${ago(r.started_at)} 시작` : '수집기가 가져가길 기다리는 중';
  const jobText = jobs.map((j) => `${j.mall_name ?? '?'} ${j.item_count}건${j.error ? ' (실패)' : ''}`).join(' · ');
  $('runMeta').textContent = [...what, time, jobText, r.error].filter(Boolean).join(' · ');
  const badge = $('runStatus');
  badge.className = `badge ${r.status}`;
  badge.textContent = `${STATUS[r.status]}${r.status === 'success' || r.status === 'failed' ? ` · ${r.item_count}건` : ''}`;
}

function renderPipeline() {
  const steps = pipelineOf(st.run);
  const count = {};
  const level = {};
  for (const e of st.events) {
    const k = e.step === 'start' && st.run.kind === 'crawl' ? 'target' : e.step;
    count[k] = (count[k] || 0) + 1;
    if (e.level === 'error') level[k] = 'err';
    else if (e.level === 'warn' && level[k] !== 'err') level[k] = 'warn';
  }
  const last = st.events.at(-1);
  const active = ['queued', 'running'].includes(st.run.status);
  $('pipeline').innerHTML = steps
    .map(([k, name, sub]) => {
      const cls = [count[k] ? 'hit' : '', level[k] || '', active && last && (last.step === k || (k === 'target' && last.step === 'start')) ? 'live' : ''].join(' ');
      return `<li class="${cls}"><b>${name}</b><span>${sub}</span>${count[k] ? `<span class="n">${count[k]}</span>` : ''}</li>`;
    })
    .join('');
}

const STEP = { start: '시작', target: '대상', robots: 'robots', request: '요청', response: '응답', parse: '파싱', sign: '서명', api_request: 'API 요청', api_response: 'API 응답', fx: '환율', save: '저장', done: '끝', error: '오류' };

function appendEvent(ev) {
  const li = document.createElement('li');
  li.className = ev.level;
  li.dataset.id = ev.id;
  li.innerHTML = `<time>${hhmmss(ev.at)}</time><span class="step">${STEP[ev.step] || esc(ev.step)}</span><span class="msg">${esc(ev.message)}</span>`;
  const box = $('events');
  const stick = box.scrollTop + box.clientHeight >= box.scrollHeight - 30;
  box.append(li);
  if (stick) box.scrollTop = box.scrollHeight;
  // 서명 · API 응답 · 파싱 결과는 바로 오른쪽에 보여 준다
  if (!st.selected || ['sign', 'api_response', 'parse', 'robots', 'fx'].includes(ev.step)) inspect(ev);
}

$('events').addEventListener('click', (e) => {
  const li = e.target.closest('li[data-id]');
  if (!li) return;
  inspect(st.events.find((x) => x.id === Number(li.dataset.id)), true);
});

function inspect(ev, pinned = false) {
  if (!ev) return;
  if (st.selected?.pinned && !pinned) return;
  st.selected = { id: ev.id, pinned };
  document.querySelectorAll('#events li').forEach((li) => li.classList.toggle('on', Number(li.dataset.id) === ev.id));
  const d = ev.data || {};
  const rows = [];
  const pre = [];
  let table = '';
  for (const [k, v] of Object.entries(d)) {
    if (v == null) continue;
    if (k === 'items' && Array.isArray(v)) {
      table = `<table class="mini"><tr><th>상품</th><th>가격</th><th>배송비</th><th>품절</th></tr>${v
        .map((i) => `<tr><td>${esc(i.title)}</td><td>${won(i.price)}</td><td>${esc(i.shipping ?? '알 수 없음')}</td><td>${i.sold_out ? '품절' : ''}</td></tr>`)
        .join('')}</table>`;
    } else if (['body', 'signed', 'authorization'].includes(k)) {
      pre.push(`<p class="hint">${{ body: '본문', signed: '서명한 문자열 (signed-date + GET + 경로 + 쿼리)', authorization: 'Authorization 헤더' }[k]}</p><pre>${esc(v)}</pre>`);
    } else {
      rows.push(`<dt>${esc(k)}</dt><dd>${esc(typeof v === 'object' ? JSON.stringify(v) : v)}</dd>`);
    }
  }
  $('inspect').innerHTML = `<p><b>${STEP[ev.step] || esc(ev.step)}</b> · ${hhmmss(ev.at)}</p><p>${esc(ev.message)}</p>${rows.length ? `<dl>${rows.join('')}</dl>` : ''}${table}${pre.join('')}`;
}

// ---------------------------------------------------------------- 결과 · 매칭
async function refreshResults() {
  if (!st.runId) return;
  const { items } = await api(`/admin/raw-listings?run_id=${st.runId}&limit=200`);
  $('results').innerHTML =
    items
      .map(
        (r) => `<tr>
      <td class="num">#${r.id}</td><td>${esc(r.mall_name)}</td>
      <td><a href="${esc(r.source_url)}" target="_blank" rel="noopener">${esc(r.title)}</a>${r.payload?.sold_out ? ' <span class="state rejected">품절</span>' : ''}</td>
      <td class="num">${won(r.price)}</td><td class="num">${r.shipping_fee == null ? '알 수 없음' : won(r.shipping_fee)}</td>
      <td><span class="state ${r.match_state}">${STATE[r.match_state]}</span></td>
      <td>${r.match_state === 'pending' ? `<button class="small go" data-match="${r.id}">연결</button> <button class="small" data-reject="${r.id}">제외</button>` : ''}</td>
    </tr>`,
      )
      .join('') || `<tr><td colspan="7" class="hint">${['queued', 'running'].includes(st.run?.status) ? '수집 중…' : '모은 상품이 없어요'}</td></tr>`;
}

$('results').addEventListener('click', async (e) => {
  const m = e.target.closest('[data-match]');
  const r = e.target.closest('[data-reject]');
  try {
    if (m) await showCandidates(Number(m.dataset.match));
    if (r) {
      await api(`/admin/raw-listings/${r.dataset.reject}/reject`, { method: 'POST' });
      $('matchBox').hidden = true;
      refreshResults();
    }
  } catch (err) {
    alert(err.message);
  }
});

async function showCandidates(rawId) {
  const c = await api(`/admin/raw-listings/${rawId}/candidates`);
  const box = $('matchBox');
  box.hidden = false;
  box.innerHTML = `<b>#${rawId} ${esc(c.raw.title)}</b> · ${won(c.raw.price)} 을(를) 어느 카탈로그 버전에 연결할까요?
    <ul>${c.items
      .map(
        (v, i) => `<li><label><input type="radio" name="variant" value="${v.variant_id}" ${i === 0 ? 'checked' : ''}>
        ${esc(v.ip_name)} · <b>${esc(v.product_name)}</b> — ${esc(v.variant_name)}
        ${v.from_query ? '<span class="tag">이 검색어로 찾음</span>' : ''} <span class="hint">낱말 ${v.hits}개 겹침</span></label></li>`,
      )
      .join('')}</ul>
    <button class="small go" id="doMatch">이 버전으로 연결 → 몰별 가격에 반영</button> <button class="small" id="closeMatch">닫기</button>
    <p class="hint">AI 매칭(EmbeddingGemma 2)이 생기기 전까지는 운영자가 확정합니다. 한 번 연결한 몰 · 주소는 다음 수집부터 가격이 자동으로 갱신됩니다.</p>`;
  $('closeMatch').onclick = () => (box.hidden = true);
  $('doMatch').onclick = async () => {
    const v = box.querySelector('input[name=variant]:checked');
    if (!v) return;
    try {
      const r = await api(`/admin/raw-listings/${rawId}/match`, { method: 'POST', body: { variant_id: Number(v.value) } });
      box.innerHTML = `<b>연결했어요.</b> online.offer #${r.id} — 상품 API(GET /products/…)의 몰별 가격에 들어갑니다. (Flutter 앱은 아직 목업 API를 씁니다)`;
      refreshResults();
      refreshMalls();
    } catch (err) {
      alert(err.message);
    }
  };
}

// ---------------------------------------------------------------- 시작
async function start() {
  $('login').hidden = true;
  $('app').hidden = false;
  $('logout').hidden = false;
  syncProvider();
  try {
    await Promise.all([refreshCollector(), refreshMalls(), refreshRuns()]);
  } catch { /* 401이면 로그인 화면 */ }
}

setInterval(() => st.token && refreshCollector(), 3000);
if (st.token) start();
else showLogin();
