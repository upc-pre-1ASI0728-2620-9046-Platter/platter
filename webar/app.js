// Platter · Carta del comensal con Realidad Aumentada (US13–US17).
// SPA sin build. Rutas: /m/{token} · /m/?t={token} · /m/demo
const API = '/api/v1';
const MODEL_VIEWER_URL = 'https://cdn.jsdelivr.net/npm/@google/model-viewer@4.3.1/dist/model-viewer.min.js';
const AUTO_AR_WINDOW_MS = 4500; // ventana de "activación de usuario" tras el toque 1

const $ = (sel, root = document) => root.querySelector(sel);
const el = {
  tableLabel: $('#tableLabel'),
  restaurantName: $('#restaurantName'),
  filterBtn: $('#filterBtn'),
  filterCount: $('#filterCount'),
  nav: $('#categoryNav'),
  notice: $('#notice'),
  activeFilters: $('#activeFilters'),
  content: $('#content'),
  dishSheet: $('#dishSheet'),
  dishPanel: $('#dishPanel'),
  filterSheet: $('#filterSheet'),
  filterForm: $('#filterForm'),
  toggles: $('#allergenToggles'),
};

const state = {
  token: null,
  table: null,
  restaurant: null,
  menu: null,
  allergens: [],
  allergenMap: new Map(),
  excluded: new Set(),
};

// ---------------------------------------------------------------------------
// Utilidades
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const money = (n) => `S/ ${Number(n || 0).toFixed(2)}`;
const store = {
  get(k) { try { return sessionStorage.getItem(k); } catch { return null; } },
  set(k, v) { try { sessionStorage.setItem(k, v); } catch { /* modo privado */ } },
};

class ApiError extends Error {
  constructor(status, body) {
    super(body?.message || `Error ${status}`);
    this.status = status;
    this.code = body?.code || (status ? `HTTP_${status}` : 'NETWORK');
    this.details = body?.details;
  }
}

async function api(path, opts = {}) {
  let res;
  try {
    res = await fetch(API + path, { headers: { Accept: 'application/json', ...(opts.body ? { 'Content-Type': 'application/json' } : {}) }, ...opts });
  } catch {
    throw new ApiError(0, { code: 'NETWORK', message: 'Sin conexión' });
  }
  const text = await res.text();
  let body = null;
  try { body = text ? JSON.parse(text) : null; } catch { /* no JSON */ }
  if (!res.ok) throw new ApiError(res.status, body);
  return body;
}

/** Envía un evento de analítica sin bloquear la UI (sendBeacon si es posible). */
function track(type, extra = {}) {
  const payload = { type, ...(state.table ? { tableToken: state.token } : {}), ...extra };
  try {
    const blob = new Blob([JSON.stringify(payload)], { type: 'application/json' });
    if (navigator.sendBeacon && navigator.sendBeacon(`${API}/public/events`, blob)) return;
  } catch { /* sigue con fetch */ }
  try {
    fetch(`${API}/public/events`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload), keepalive: true }).catch(() => {});
  } catch { /* nunca romper la UI por analítica */ }
}

function readToken() {
  const qs = new URLSearchParams(location.search).get('t');
  if (qs) return qs.trim();
  const m = location.pathname.match(/^\/m\/([^/?#]+)\/?$/);
  if (m && m[1] !== 'index.html') return decodeURIComponent(m[1]);
  return null;
}

// Iconos por código (respaldo si el API no envía un icono utilizable).
const FALLBACK_ICON = {
  GLUTEN: '🌾', CRUSTACEANS: '🦐', MOLLUSCS: '🦑', FISH: '🐟', EGGS: '🥚', MILK: '🥛', PEANUTS: '🥜',
  TREE_NUTS: '🌰', SOY: '🫘', SESAME: '⚪', CELERY: '🥬', MUSTARD: '🟡', SULPHITES: '🍷', LUPIN: '🌼',
};
const FALLBACK_LABEL = {
  GLUTEN: 'Gluten', CRUSTACEANS: 'Crustáceos', MOLLUSCS: 'Moluscos', FISH: 'Pescado', EGGS: 'Huevo', MILK: 'Lácteos',
  PEANUTS: 'Maní', TREE_NUTS: 'Frutos secos', SOY: 'Soya', SESAME: 'Ajonjolí', CELERY: 'Apio', MUSTARD: 'Mostaza',
  SULPHITES: 'Sulfitos', LUPIN: 'Altramuz',
};
function allergenInfo(code) {
  const a = state.allergenMap.get(code);
  return { code, label: a?.label || FALLBACK_LABEL[code] || code, icon: a?.icon || FALLBACK_ICON[code] || '⚠️' };
}
function iconHtml(icon, label) {
  if (/^(\/|https?:)/.test(icon)) return `<img src="${esc(icon)}" alt="" width="16" height="16">`;
  if (/^[a-z0-9_-]{3,}$/i.test(icon)) return '⚠️'; // nombre simbólico desconocido
  return esc(icon);
}
const withoutLabel = (label) => (/^sin\b/i.test(label) ? label : `Sin ${label.charAt(0).toLowerCase()}${label.slice(1)}`);

// ---------------------------------------------------------------------------
// Estados de pantalla
function renderState({ icon, title, text, actions = '' }) {
  el.content.setAttribute('aria-busy', 'false');
  el.content.innerHTML = `<section class="state" role="alert"><div class="state__icon" aria-hidden="true">${icon}</div><h2>${esc(title)}</h2><p>${esc(text)}</p>${actions}</section>`;
}
function renderSkeleton() {
  el.content.setAttribute('aria-busy', 'true');
  const card = '<div class="card card--skeleton"><div class="skeleton card__photo"></div><div class="card__body"><span class="skeleton skeleton--title"></span><span class="skeleton skeleton--text"></span><span class="skeleton skeleton--text" style="width:60%"></span></div></div>';
  el.content.innerHTML = `<div class="menu-list" aria-hidden="true">${card.repeat(3)}</div><span class="sr-only">Cargando la carta…</span>`;
}
function renderNetworkError(retry, err) {
  const offline = err?.code === 'NETWORK';
  renderState({
    icon: offline ? '📶' : '🍽️',
    title: offline ? 'Sin conexión' : 'No pudimos cargar la carta',
    text: offline ? 'Revisa tu conexión a internet e inténtalo de nuevo.' : 'Ocurrió un problema temporal. Vuelve a intentarlo en unos segundos.',
    actions: '<button class="btn btn--primary" type="button" data-retry>Reintentar</button>',
  });
  el.content.querySelector('[data-retry]').addEventListener('click', retry, { once: true });
}

// ---------------------------------------------------------------------------
// Carga inicial
async function init() {
  state.token = readToken();
  try { state.excluded = new Set(JSON.parse(store.get('platter.exclude') || '[]')); } catch { state.excluded = new Set(); }

  if (!state.token) {
    setHeader(null);
    return renderInvalidQr();
  }
  loadAllergens(); // en paralelo; no bloquea la carta
  await loadTable();
}

function setHeader(restaurantName, tableLabel) {
  el.restaurantName.textContent = restaurantName || 'Platter';
  el.tableLabel.textContent = tableLabel || '';
  document.title = restaurantName ? `${restaurantName} · Carta` : 'Carta digital · Platter';
}

function renderInvalidQr() {
  el.filterBtn.hidden = true;
  el.nav.hidden = true;
  renderState({
    icon: '🔍',
    title: 'Código QR no válido',
    text: 'No encontramos esta mesa. Vuelve a escanear el código de tu mesa o pide ayuda al personal del restaurante.',
    actions: '<a class="btn btn--ghost" href="/m/demo">Ver una carta de demostración</a>',
  });
}

async function loadTable() {
  renderSkeleton();
  try {
    const data = await api(`/public/tables/${encodeURIComponent(state.token)}`);
    state.table = data.table;
    state.restaurant = data.restaurant;
  } catch (err) {
    if (err.status === 404 || err.status === 400) { setHeader(null); return renderInvalidQr(); }
    setHeader(null);
    return renderNetworkError(loadTable, err);
  }
  setHeader(state.restaurant.name, state.table?.label);
  // Escaneo de QR: una vez por sesión y mesa.
  const scanKey = `platter.scan.${state.token}`;
  if (!store.get(scanKey)) {
    store.set(scanKey, '1');
    track('QR_SCAN', { tableToken: state.token });
  }
  if (state.table && state.table.active === false) {
    el.notice.innerHTML = `<div class="notice"><span aria-hidden="true">ℹ️</span><div><strong>Esta mesa no está activa.</strong> Igual puedes ver la carta general del restaurante; consulta con el personal para hacer tu pedido.</div></div>`;
  }
  el.filterBtn.hidden = false;
  await loadMenu();
}

async function loadAllergens() {
  try {
    state.allergens = (await api('/allergens')) || [];
  } catch {
    state.allergens = Object.keys(FALLBACK_LABEL).map((code) => ({ code, label: FALLBACK_LABEL[code], icon: FALLBACK_ICON[code] }));
  }
  state.allergenMap = new Map(state.allergens.map((a) => [a.code, a]));
  renderToggles();
  if (state.menu) renderMenu(); // refresca etiquetas/iconos
}

async function loadMenu() {
  renderSkeleton();
  updateFilterUi();
  const qs = state.excluded.size ? `?exclude=${encodeURIComponent([...state.excluded].join(','))}` : '';
  try {
    state.menu = await api(`/public/restaurants/${encodeURIComponent(state.restaurant.id)}/menu${qs}`);
  } catch (err) {
    return renderNetworkError(loadMenu, err);
  }
  renderMenu();
  preloadModelViewer();
}

// ---------------------------------------------------------------------------
// Carta
function dishCard(d) {
  const soldOut = d.available === false;
  const allergens = (d.allergens || []).map(allergenInfo);
  const photo = d.photoUrl
    ? `<img class="card__photo" src="${esc(d.photoUrl)}" alt="" loading="lazy" decoding="async" width="148" height="148">`
    : `<div class="card__photo card__photo--empty" aria-hidden="true">🍽️</div>`;
  const badges = [
    soldOut ? '<span class="badge badge--soldout">Agotado por hoy</span>' : '',
    d.vegan ? '<span class="badge">🌱 Vegano</span>' : d.vegetarian ? '<span class="badge">🥗 Vegetariano</span>' : '',
  ].join('');
  const allergenIcons = allergens.length
    ? `<span class="allergen-icons" role="img" aria-label="Contiene: ${esc(allergens.map((a) => a.label).join(', '))}">${allergens.map((a) => `<span title="${esc(a.label)}">${iconHtml(a.icon, a.label)}</span>`).join('')}</span>`
    : '';
  const hasModel = !!d.model?.glbUrl;
  const action = hasModel
    ? `<button class="btn btn--primary" type="button" data-ar="${esc(d.id)}" ${soldOut ? 'disabled aria-disabled="true"' : ''} aria-label="Ver ${esc(d.name)} en mi mesa con realidad aumentada">
         <svg aria-hidden="true" viewBox="0 0 24 24" width="20" height="20"><path d="M12 3l8 4.5v9L12 21l-8-4.5v-9L12 3zm0 0v9m0 0l8-4.5M12 12l-8-4.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>
         Ver en mi mesa</button>`
    : `<button class="btn btn--ghost" type="button" data-detail="${esc(d.id)}">Ver detalle</button>`;
  return `<article class="card${soldOut ? ' card--soldout' : ''}" aria-labelledby="dish-${esc(d.id)}">
    ${photo}
    <div class="card__body">
      <div class="card__top">
        <h3 class="card__name" id="dish-${esc(d.id)}"><button type="button" data-detail="${esc(d.id)}">${esc(d.name)}</button></h3>
        <span class="price">${money(d.priceSoles)}</span>
      </div>
      ${d.description ? `<p class="card__desc">${esc(d.description)}</p>` : ''}
      <div class="card__meta">${badges}${allergenIcons}</div>
      <div class="card__actions">${action}</div>
    </div>
  </article>`;
}

const slug = (s, i) => `cat-${i}-${String(s).toLowerCase().normalize('NFD').replace(/[^a-z0-9]+/g, '-')}`;

function renderMenu() {
  const cats = (state.menu?.categories || []).filter((c) => c.dishes?.length);
  el.content.setAttribute('aria-busy', 'false');
  renderActiveFilters();
  if (!cats.length) {
    el.nav.hidden = true;
    if (state.excluded.size) {
      renderState({
        icon: '🥢',
        title: 'No hay platos con esos filtros',
        text: 'Ningún plato cumple todos los filtros de alérgenos elegidos. Prueba quitando alguno.',
        actions: '<button class="btn btn--primary" type="button" data-clear>Quitar filtros</button>',
      });
      el.content.querySelector('[data-clear]').addEventListener('click', () => setExcluded([]));
    } else {
      renderState({ icon: '📋', title: 'La carta aún está vacía', text: 'Este restaurante todavía no ha publicado platos. Consulta con el personal.' });
    }
    return;
  }
  el.nav.innerHTML = cats.map((c, i) => `<a class="chip" href="#${slug(c.name, i)}" data-cat="${slug(c.name, i)}">${esc(c.name)}</a>`).join('');
  el.nav.hidden = false;
  el.content.innerHTML = cats
    .map((c, i) => `<section class="category" id="${slug(c.name, i)}" aria-labelledby="${slug(c.name, i)}-t">
        <h2 class="category__title" id="${slug(c.name, i)}-t">${esc(c.name)}</h2>
        <div class="menu-list">${c.dishes.map(dishCard).join('')}</div>
      </section>`)
    .join('');
  observeCategories();
}

let catObserver;
function observeCategories() {
  catObserver?.disconnect();
  const chips = [...el.nav.querySelectorAll('.chip')];
  const setCurrent = (id) => chips.forEach((c) => {
    const on = c.dataset.cat === id;
    c.setAttribute('aria-current', on ? 'true' : 'false');
    if (on) c.scrollIntoView({ block: 'nearest', inline: 'nearest' });
  });
  if (chips[0]) setCurrent(chips[0].dataset.cat);
  if (!('IntersectionObserver' in window)) return;
  catObserver = new IntersectionObserver((entries) => {
    const vis = entries.filter((e) => e.isIntersecting).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top);
    if (vis[0]) setCurrent(vis[0].target.id);
  }, { rootMargin: '-140px 0px -60% 0px' });
  el.content.querySelectorAll('.category').forEach((s) => catObserver.observe(s));
}

function findDish(id) {
  for (const c of state.menu?.categories || []) for (const d of c.dishes || []) if (String(d.id) === String(id)) return d;
  return null;
}

// ---------------------------------------------------------------------------
// Filtro de alérgenos (US15)
function renderToggles() {
  el.toggles.innerHTML = state.allergens
    .map((a) => `<label class="toggle"><input type="checkbox" name="exclude" value="${esc(a.code)}" ${state.excluded.has(a.code) ? 'checked' : ''}>
      <span aria-hidden="true">${iconHtml(a.icon || FALLBACK_ICON[a.code] || '⚠️', a.label)}</span><span>${esc(withoutLabel(a.label))}</span></label>`)
    .join('');
}
function updateFilterUi() {
  const n = state.excluded.size;
  el.filterCount.hidden = !n;
  el.filterCount.textContent = n ? String(n) : '';
  el.filterBtn.setAttribute('aria-label', n ? `Filtrar alérgenos (${n} activos)` : 'Filtrar alérgenos');
}
function renderActiveFilters() {
  if (!state.excluded.size) { el.activeFilters.innerHTML = ''; return; }
  el.activeFilters.innerHTML = `<div class="active-filters"><span class="label">Ocultando platos con:</span>${[...state.excluded]
    .map((code) => {
      const a = allergenInfo(code);
      return `<button type="button" class="chip chip--filter" data-remove="${esc(code)}" aria-label="Quitar filtro ${esc(withoutLabel(a.label))}">${iconHtml(a.icon, a.label)} ${esc(a.label)} <span aria-hidden="true">✕</span></button>`;
    })
    .join('')}</div>`;
}
function setExcluded(codes) {
  state.excluded = new Set(codes);
  store.set('platter.exclude', JSON.stringify([...state.excluded]));
  renderToggles();
  loadMenu();
}

el.filterBtn.addEventListener('click', () => {
  renderToggles();
  openSheet(el.filterSheet);
});
el.filterForm.addEventListener('submit', (e) => {
  e.preventDefault();
  const codes = [...el.filterForm.querySelectorAll('input[name="exclude"]:checked')].map((i) => i.value);
  closeSheet(el.filterSheet);
  setExcluded(codes);
});
$('#clearFilters').addEventListener('click', () => {
  closeSheet(el.filterSheet);
  setExcluded([]);
});
el.activeFilters.addEventListener('click', (e) => {
  const b = e.target.closest('[data-remove]');
  if (b) setExcluded([...state.excluded].filter((c) => c !== b.dataset.remove));
});

// ---------------------------------------------------------------------------
// Hojas (dialog) con soporte del botón "atrás"
function openSheet(dlg) {
  if (dlg.open) return;
  dlg.showModal();
  try { history.pushState({ sheet: dlg.id }, ''); } catch { /* ignore */ }
}
function closeSheet(dlg, fromPop = false) {
  if (!dlg.open) return;
  dlg.close();
  if (!fromPop && history.state?.sheet === dlg.id) history.back();
}
window.addEventListener('popstate', () => {
  [el.dishSheet, el.filterSheet].forEach((d) => d.open && closeSheet(d, true));
});
for (const dlg of [el.dishSheet, el.filterSheet]) {
  dlg.addEventListener('click', (e) => {
    if (e.target === dlg || e.target.closest('[data-close]')) closeSheet(dlg);
  });
  dlg.addEventListener('cancel', (e) => { e.preventDefault(); closeSheet(dlg); });
}
el.dishSheet.addEventListener('close', () => {
  endArSession();
  el.dishPanel.innerHTML = '';
});

// ---------------------------------------------------------------------------
// Detalle del plato + AR (US14, US16, US17)
let mvPromise;
function loadModelViewer() {
  mvPromise ??= import(MODEL_VIEWER_URL).catch((e) => { mvPromise = null; throw e; });
  return mvPromise;
}
function preloadModelViewer() {
  const go = () => loadModelViewer().catch(() => {});
  if ('requestIdleCallback' in window) requestIdleCallback(go, { timeout: 3000 });
  else setTimeout(go, 1500);
}

function formatDims(dim) {
  if (!dim) return '';
  const cm = (m) => Math.round(m * 100);
  const w = dim.widthM, dpt = dim.depthM;
  if (w && dpt && Math.abs(w - dpt) / Math.max(w, dpt) < 0.1) {
    return `Diámetro aprox. ${cm(Math.max(w, dpt))} cm · alto ${cm(dim.heightM)} cm`;
  }
  return `Aprox. ${cm(w)} × ${cm(dpt)} cm · alto ${cm(dim.heightM)} cm`;
}

const ar = { dishId: null, startedAt: 0, active: false, launchLogged: false, pendingTap: 0 };

function startArSession(dishId) {
  if (ar.active) return;
  ar.active = true;
  ar.dishId = dishId;
  ar.startedAt = Date.now();
  if (!ar.launchLogged) { ar.launchLogged = true; track('AR_LAUNCH', { dishId }); }
}
function endArSession() {
  if (!ar.active) return;
  ar.active = false;
  const durationSeconds = Math.max(1, Math.round((Date.now() - ar.startedAt) / 1000));
  track('AR_SESSION_END', { dishId: ar.dishId, durationSeconds });
  ar.launchLogged = false;
}
// Scene Viewer (Android) y Quick Look (iOS) abren otra app: la página queda oculta mientras dura la sesión.
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'hidden' && ar.pendingTap && Date.now() - ar.pendingTap < 8000 && !ar.active) {
    startArSession(ar.dishId);
    ar.external = true;
  } else if (document.visibilityState === 'visible' && ar.active && ar.external) {
    ar.external = false;
    ar.pendingTap = 0;
    endArSession();
  }
});
window.addEventListener('pagehide', () => endArSession());

function detailHtml(d) {
  const soldOut = d.available === false;
  const allergens = (d.allergens || []).map(allergenInfo);
  const model = d.model;
  const dims = formatDims(model?.dimensions);
  const viewer = model?.glbUrl
    ? `<div class="viewer">
        <model-viewer id="mv" src="${esc(model.glbUrl)}" ${d.photoUrl ? `poster="${esc(d.photoUrl)}"` : ''}
          alt="Modelo 3D de ${esc(d.name)} a escala real"
          ${soldOut ? '' : 'ar ar-modes="webxr scene-viewer quick-look" ar-scale="fixed" ar-placement="floor"'}
          camera-controls touch-action="pan-y" shadow-intensity="1" shadow-softness="0.8" exposure="1"
          camera-orbit="0deg 60deg auto" interaction-prompt="auto" loading="eager" reveal="auto">
          ${soldOut ? '' : `<button slot="ar-button" class="btn btn--primary btn--ar mv-ar-btn" type="button">
            <svg aria-hidden="true" viewBox="0 0 24 24" width="22" height="22"><path d="M12 3l8 4.5v9L12 21l-8-4.5v-9L12 3zm0 0v9m0 0l8-4.5M12 12l-8-4.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>
            Ver en mi mesa (Realidad Aumentada)</button>`}
        </model-viewer>
      </div>
      <p class="ar-hint" id="arHint">${soldOut ? '<span aria-hidden="true">⛔</span><span>Agotado por hoy: la Realidad Aumentada no está disponible para este plato.</span>' : '<span aria-hidden="true">📐</span><span>Escala real 1:1. Apunta la cámara a tu mesa y muévela despacio hasta que aparezca el plato.</span>'}</p>`
    : d.photoUrl
      ? `<img class="viewer__photo" src="${esc(d.photoUrl)}" alt="Foto de ${esc(d.name)}">`
      : '';
  const kcal = d.calories && (d.calories.min || d.calories.max)
    ? `${d.calories.min ?? '?'}–${d.calories.max ?? '?'} kcal <span class="muted">(estimación orientativa)</span>`
    : '';
  return `
    <div class="sheet__head">
      <span class="dims">${dims ? `<span aria-hidden="true">📏</span>${esc(dims)}` : ''}</span>
      <button class="icon-btn" type="button" data-close aria-label="Cerrar detalle">
        <svg aria-hidden="true" viewBox="0 0 24 24" width="22" height="22"><path d="M6 6l12 12M18 6L6 18" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
      </button>
    </div>
    ${viewer}
    <div class="detail__top">
      <h2 class="sheet__title" id="dishTitle">${esc(d.name)}</h2>
      <span class="detail__price">${money(d.priceSoles)}</span>
    </div>
    <div class="card__meta" style="margin-top:.4rem">
      ${soldOut ? '<span class="badge badge--soldout">Agotado por hoy</span>' : ''}
      ${d.vegan ? '<span class="badge">🌱 Vegano</span>' : ''}
      ${d.vegetarian && !d.vegan ? '<span class="badge">🥗 Vegetariano</span>' : ''}
    </div>
    ${d.description ? `<div class="detail__section"><p>${esc(d.description)}</p></div>` : ''}
    <div class="detail__section">
      <h3>Alérgenos</h3>
      <div class="allergen-chips">${allergens.length
        ? allergens.map((a) => `<span class="allergen-chip">${iconHtml(a.icon, a.label)} ${esc(a.label)}</span>`).join('')
        : d.allergenFree ? '<span class="allergen-chip allergen-chip--none">✓ Sin alérgenos declarados</span>' : '<span class="muted">Consulta con el personal.</span>'}</div>
    </div>
    ${d.kitchenNotes ? `<div class="detail__section"><h3>Contaminación cruzada y notas de cocina</h3><p class="kitchen-note">${esc(d.kitchenNotes)}</p></div>` : ''}
    ${d.ingredients?.length ? `<div class="detail__section"><h3>Ingredientes</h3><ul class="ingredients">${d.ingredients.map((i) => `<li>${esc(i)}</li>`).join('')}</ul></div>` : ''}
    ${kcal ? `<div class="detail__section"><h3>Calorías</h3><p>${kcal}</p></div>` : ''}
    <p class="fineprint">El modelo 3D es una representación referencial del plato a tamaño real.</p>`;
}

async function openDish(id, { autoAr = false } = {}) {
  const d = findDish(id);
  if (!d) return;
  const tapAt = Date.now();
  el.dishPanel.innerHTML = detailHtml(d);
  openSheet(el.dishSheet);
  track('DISH_VIEW', { dishId: d.id });
  ar.dishId = d.id;
  ar.launchLogged = false;

  const mv = el.dishPanel.querySelector('#mv');
  if (!mv) return;
  try {
    await loadModelViewer();
  } catch {
    $('#arHint').innerHTML = '<span aria-hidden="true">⚠️</span><span>No se pudo cargar el visor 3D. Revisa tu conexión.</span>';
    return;
  }
  await customElements.whenDefined('model-viewer');
  const hint = $('#arHint');
  const arButton = mv.querySelector('[slot="ar-button"]');

  arButton?.addEventListener('click', () => { ar.pendingTap = Date.now(); ar.dishId = d.id; });
  mv.addEventListener('ar-status', (e) => {
    const s = e.detail?.status;
    if (s === 'session-started') startArSession(d.id);
    else if (s === 'not-presenting') endArSession();
    else if (s === 'failed') { endArSession(); showNoAr(hint); }
  });
  mv.addEventListener('error', () => {
    if (hint) hint.innerHTML = '<span aria-hidden="true">⚠️</span><span>No se pudo cargar el modelo 3D de este plato.</span>';
  });

  const checkSupport = () => {
    if (d.available === false) return;
    if (!mv.canActivateAR) {
      showNoAr(hint);
      return;
    }
    // Toque 1 ("Ver en mi mesa") cuenta como gesto del usuario por unos segundos:
    // intentamos abrir la RA directamente; si el navegador lo bloquea, queda el botón grande (toque 2).
    if (autoAr && Date.now() - tapAt < AUTO_AR_WINDOW_MS) {
      ar.pendingTap = Date.now();
      try { const p = mv.activateAR(); p?.catch?.(() => {}); } catch { /* requiere otro toque */ }
    }
  };
  if (mv.loaded) checkSupport();
  else mv.addEventListener('load', checkSupport, { once: true });
}

function showNoAr(hint) {
  if (!hint) return;
  hint.classList.add('ar-unsupported');
  hint.innerHTML = '<span aria-hidden="true">🔄</span><span>Tu dispositivo no soporta AR: gira y acerca el plato en 3D.</span>';
}

el.content.addEventListener('click', (e) => {
  const arBtn = e.target.closest('[data-ar]');
  if (arBtn && !arBtn.disabled) return openDish(arBtn.dataset.ar, { autoAr: true });
  const det = e.target.closest('[data-detail]');
  if (det) openDish(det.dataset.detail);
});

init();
