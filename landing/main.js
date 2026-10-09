// Platter · Landing (US01–US04). Módulo ES sin build.
const API = '/api/v1';
const QR_LIB = 'https://cdn.jsdelivr.net/npm/qrcode-generator@2.0.4/dist/qrcode.mjs';

const $ = (s, r = document) => r.querySelector(s);
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const soles = (n, d = 0) => `S/ ${Number(n).toFixed(d)}`;
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

async function getJson(path, opts = {}) {
  let res;
  try {
    res = await fetch(API + path, { headers: { Accept: 'application/json', ...(opts.body ? { 'Content-Type': 'application/json' } : {}) }, ...opts });
  } catch {
    const e = new Error('Sin conexión'); e.code = 'NETWORK'; throw e;
  }
  let body = null;
  try { body = await res.json(); } catch { /* sin cuerpo */ }
  if (!res.ok) {
    const e = new Error(body?.message || `Error ${res.status}`);
    e.status = res.status; e.code = body?.code; e.details = body?.details;
    throw e;
  }
  return body;
}

// ---------------------------------------------------------------------------
// Navegación móvil
const navToggle = $('.nav-toggle');
const nav = $('#siteNav');
navToggle.addEventListener('click', () => {
  const open = nav.classList.toggle('is-open');
  navToggle.setAttribute('aria-expanded', String(open));
  navToggle.setAttribute('aria-label', open ? 'Cerrar menú' : 'Abrir menú');
});
nav.addEventListener('click', (e) => {
  if (e.target.closest('a')) { nav.classList.remove('is-open'); navToggle.setAttribute('aria-expanded', 'false'); }
});
$('#year').textContent = String(new Date().getFullYear());

// ---------------------------------------------------------------------------
// Demo AR interactiva (US01)
const viewer = $('#demoViewer');
const switcher = $('#modelSwitcher');
const dimsEl = $('#demoDims');
const FALLBACK_MODELS = [{ id: 'lomo-saltado', name: 'Lomo saltado', glbUrl: `${API}/assets/models/lomo-saltado.glb`, dimensions: { widthM: 0.28, depthM: 0.28, heightM: 0.065 } }];

if (reducedMotion) viewer.removeAttribute('auto-rotate');

function dimsText(d) {
  if (!d) return '';
  const cm = (m) => Math.round(m * 100);
  const round = d.widthM && d.depthM && Math.abs(d.widthM - d.depthM) / Math.max(d.widthM, d.depthM) < 0.1;
  return round ? `Escala real · Ø ${cm(Math.max(d.widthM, d.depthM))} cm` : `Escala real · ${cm(d.widthM)} × ${cm(d.depthM)} cm`;
}

function selectModel(m, btn) {
  viewer.src = m.glbUrl || `${API}/assets/models/${m.id}.glb`;
  viewer.alt = `Modelo 3D de ${m.name} a escala real`;
  dimsEl.textContent = dimsText(m.dimensions);
  switcher.querySelectorAll('.chip').forEach((c) => c.setAttribute('aria-pressed', String(c === btn)));
}

async function initDemo() {
  let models = FALLBACK_MODELS;
  try {
    const list = await getJson('/models');
    if (Array.isArray(list) && list.length) models = list.filter((m) => m.id !== 'generico');
  } catch { /* usa respaldo */ }
  switcher.innerHTML = models.map((m, i) => `<button type="button" class="chip" data-i="${i}" aria-pressed="false">${esc(m.name)}</button>`).join('');
  const start = Math.max(0, models.findIndex((m) => m.id === 'lomo-saltado'));
  selectModel(models[start], switcher.children[start]);
  switcher.addEventListener('click', (e) => {
    const b = e.target.closest('.chip');
    if (b) selectModel(models[+b.dataset.i], b);
  });
}

viewer.addEventListener('error', () => {
  $('#demoNote').textContent = 'No pudimos cargar el modelo 3D en este momento. Prueba la carta de demostración desde tu celular.';
});

async function initQr() {
  const isDesktop = matchMedia('(hover: hover) and (pointer: fine)').matches;
  if (!isDesktop) return; // en el celular se usa el botón "Ver en mi mesa"
  try {
    const { default: qrcode } = await import(QR_LIB);
    const qr = qrcode(0, 'M');
    qr.addData(`${location.origin}/m/demo`);
    qr.make();
    $('#qrCode').innerHTML = qr.createSvgTag({ cellSize: 4, margin: 0, scalable: true });
    $('#demoQr').classList.add('is-ready');
    $('#demoNote').innerHTML = 'Gira el plato con el mouse. La Realidad Aumentada funciona en el celular: <strong>escanea el QR</strong> o abre <a href="/m/demo">la carta demo</a>.';
  } catch { /* sin QR: queda el enlace a la demo */ }
}

// ---------------------------------------------------------------------------
// Planes (US03) + calculadora
const FALLBACK_PLANS = [
  { code: 'EMPRENDEDOR', name: 'Emprendedor', priceSoles: 49, maxTables: 15, maxDishes: 30, aiAnalysis: true },
  { code: 'CRECIMIENTO', name: 'Crecimiento', priceSoles: 89, maxTables: 40, maxDishes: 120, aiAnalysis: true },
  { code: 'PRO', name: 'Pro', priceSoles: 129, maxTables: null, maxDishes: null, aiAnalysis: true },
];
let plans = FALLBACK_PLANS;

function planCard(p) {
  const featured = p.code === 'CRECIMIENTO';
  const items = [
    p.maxTables == null ? 'Mesas ilimitadas' : `Hasta ${p.maxTables} mesas con QR`,
    p.maxDishes == null ? 'Platos ilimitados' : `Hasta ${p.maxDishes} platos`,
    'Carta en Realidad Aumentada a escala real',
    p.aiAnalysis ? 'Fichas con IA desde una foto' : 'Fichas de platos manuales',
    'Filtro de alérgenos para comensales',
    'Analítica de escaneos y vistas',
  ];
  return `<article class="plan card${featured ? ' plan--featured' : ''}" aria-labelledby="plan-${esc(p.code)}">
    ${featured ? '<span class="plan__badge">Recomendado</span>' : ''}
    <h3 class="plan__name" id="plan-${esc(p.code)}">${esc(p.name)}</h3>
    <p class="plan__price">${soles(p.priceSoles)} <small>/ mes</small></p>
    <ul>${items.map((i) => `<li>${esc(i)}</li>`).join('')}</ul>
    <a class="btn ${featured ? 'btn--primary' : 'btn--ghost'}" href="#piloto" data-plan="${esc(p.code)}">Empezar con ${esc(p.name)}</a>
  </article>`;
}

async function initPlans() {
  const grid = $('#plansGrid');
  grid.innerHTML = '<div class="plan card plan--skeleton"></div>'.repeat(3);
  let fromApi = true;
  try {
    const list = await getJson('/plans');
    if (Array.isArray(list) && list.length) plans = [...list].sort((a, b) => a.priceSoles - b.priceSoles);
    else fromApi = false;
  } catch { fromApi = false; }
  grid.innerHTML = plans.map(planCard).join('');
  if (!fromApi) grid.insertAdjacentHTML('afterend', '<p class="muted small plans__note">Precios referenciales en soles.</p>');
  updateCalc();
}

const calcInput = $('#calcTables');
function recommend(n) {
  return plans.find((p) => p.maxTables == null || p.maxTables >= n) || plans[plans.length - 1];
}
function updateCalc() {
  const n = Math.round(Number(calcInput.value));
  const out = $('#calcResult');
  if (!Number.isFinite(n) || n < 1 || n > 500) {
    out.innerHTML = '<p class="muted" style="margin:0">Ingresa un número de mesas entre 1 y 500.</p>';
    return;
  }
  const p = recommend(n);
  const perTableDay = p.priceSoles / n / 30;
  out.innerHTML = `
    <p class="calc__plan">Plan recomendado: <strong>${esc(p.name)}</strong></p>
    <p class="muted small" style="margin:0">${p.maxTables == null ? 'Sin límite de mesas.' : `Cubre hasta ${p.maxTables} mesas; tú tienes ${n}.`}</p>
    <dl class="calc__figures">
      <div><dt>Costo mensual</dt><dd>${soles(p.priceSoles)}</dd></div>
      <div><dt>Por mesa al día</dt><dd>${soles(perTableDay, 2)}</dd></div>
    </dl>
    <a class="btn btn--primary btn--sm" href="#piloto" data-tables="${n}">Solicitar piloto con ${n} ${n === 1 ? 'mesa' : 'mesas'}</a>`;
}
calcInput.addEventListener('input', updateCalc);
document.querySelectorAll('[data-step]').forEach((b) =>
  b.addEventListener('click', () => {
    const v = Math.min(500, Math.max(1, Math.round(Number(calcInput.value) || 0) + Number(b.dataset.step)));
    calcInput.value = String(v);
    updateCalc();
  }),
);
document.addEventListener('click', (e) => {
  const t = e.target.closest('[data-tables]');
  if (t) $('#tables').value = t.dataset.tables;
});

// ---------------------------------------------------------------------------
// Solicitud de piloto (US04)
const form = $('#leadForm');
const FIELDS = ['restaurantName', 'contactName', 'email', 'phone', 'tables'];

function validate(data) {
  const err = {};
  if (data.restaurantName.length < 2) err.restaurantName = 'Escribe el nombre de tu restaurante.';
  if (data.contactName.length < 2) err.contactName = 'Escribe tu nombre.';
  if (!data.email) err.email = 'Escribe tu correo electrónico.';
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(data.email)) err.email = 'Revisa el correo: debe tener el formato nombre@dominio.com.';
  const digits = data.phone.replace(/\D/g, '');
  if (!digits) err.phone = 'Escribe un celular o teléfono de contacto.';
  else if (!/^(51)?9\d{8}$/.test(digits) && !(digits.length >= 7 && digits.length <= 12)) err.phone = 'Ingresa un número válido (por ejemplo, 987 654 321).';
  if (data.tables === '' || data.tables == null) err.tables = 'Indica cuántas mesas tiene tu local.';
  else if (!Number.isInteger(Number(data.tables)) || Number(data.tables) < 1 || Number(data.tables) > 500) err.tables = 'Ingresa un número entero entre 1 y 500.';
  return err;
}

function showErrors(err) {
  for (const f of FIELDS) {
    const input = form.elements[f];
    const msg = err[f] || '';
    $(`#${f}-err`).textContent = msg;
    if (msg) input.setAttribute('aria-invalid', 'true');
    else input.removeAttribute('aria-invalid');
  }
  const first = FIELDS.find((f) => err[f]);
  if (first) form.elements[first].focus();
}

form.addEventListener('input', (e) => {
  const f = e.target.name;
  if (f && e.target.getAttribute('aria-invalid') === 'true') {
    e.target.removeAttribute('aria-invalid');
    $(`#${f}-err`).textContent = '';
  }
});

form.addEventListener('submit', async (e) => {
  e.preventDefault();
  $('#formError').textContent = '';
  const raw = Object.fromEntries(FIELDS.map((f) => [f, String(form.elements[f].value || '').trim()]));
  const err = validate(raw);
  showErrors(err);
  if (Object.keys(err).length) return;

  const payload = { ...raw, tables: Number(raw.tables) };
  const submit = $('#leadSubmit');
  submit.disabled = true;
  submit.textContent = 'Enviando…';
  try {
    const res = await getJson('/public/leads', { method: 'POST', body: JSON.stringify(payload) });
    const success = $('#leadSuccess');
    success.innerHTML = `<div class="big" aria-hidden="true">🎉</div><h3>¡Solicitud recibida!</h3>
      <p>${esc(res?.message || 'Recibirás tu acceso en menos de 24 horas')}</p>
      <p class="muted small">Te escribiremos a <strong>${esc(payload.email)}</strong>.</p>`;
    [...form.children].forEach((c) => { if (c !== success) c.hidden = true; });
    success.hidden = false;
    success.focus();
  } catch (ex) {
    if (ex.code === 'VALIDATION_ERROR' && ex.details && typeof ex.details === 'object') {
      const fieldErr = {};
      const other = [];
      for (const [k, v] of Object.entries(ex.details)) (FIELDS.includes(k) ? (fieldErr[k] = String(v)) : other.push(String(v)));
      showErrors(fieldErr);
      $('#formError').textContent = other.length ? other.join(' ') : (Object.keys(fieldErr).length ? 'Revisa los campos marcados.' : ex.message);
    } else if (ex.code === 'NETWORK') {
      $('#formError').textContent = 'No hay conexión. Revisa tu internet e inténtalo de nuevo.';
    } else {
      $('#formError').textContent = `${ex.message || 'No pudimos enviar tu solicitud'}. Inténtalo nuevamente en unos minutos.`;
    }
  } finally {
    submit.disabled = false;
    submit.textContent = 'Solicitar mi piloto';
  }
});

initDemo();
initQr();
initPlans();
