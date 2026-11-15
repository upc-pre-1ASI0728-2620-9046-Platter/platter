// Genera out/index.html: por cada foto, el modelo de la biblioteca actual frente a cada proveedor de IA,
// con visor 3D, botón de Realidad Aumentada a escala real y una ficha para calificar.
import { writeFile } from 'node:fs/promises';
import path from 'node:path';
import { OUT_DIR } from './paths.js';

const MODEL_VIEWER = 'https://cdn.jsdelivr.net/npm/@google/model-viewer@4.3.1/dist/model-viewer.min.js';
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const cm = (m) => Math.round(m * 1000) / 10;
const mb = (b) => `${(b / 1024 / 1024).toFixed(2)} MB`;

function card(photoId, providerId, e) {
  if (!e) return '';
  const head = `<header class="card__head"><h3>${esc(e.label || providerId)}</h3></header>`;
  if (e.status !== 'done') {
    const msg = e.status === 'pending' ? 'Generando… vuelve a ejecutar npm run generate para retomarlo.' : esc(e.error || 'Sin resultado');
    return `<article class="card card--empty">${head}<p class="state">${msg}</p></article>`;
  }
  const d = e.final.dimensions;
  const rateable = providerId !== 'biblioteca';
  const key = `${photoId}:${providerId}`;
  const select = (field, label) => `<label>${label}
      <select data-rate="${esc(key)}" data-field="${field}">
        <option value="">—</option>${[1, 2, 3, 4, 5].map((n) => `<option>${n}</option>`).join('')}
      </select></label>`;
  return `<article class="card">
    ${head}
    <model-viewer src="${esc(e.file)}" alt="Modelo 3D: ${esc(e.label)}" loading="lazy" reveal="auto"
      camera-controls touch-action="pan-y" shadow-intensity="1" exposure="1" camera-orbit="0deg 60deg auto"
      ar ar-modes="webxr scene-viewer quick-look" ar-scale="fixed" ar-placement="floor">
      <button slot="ar-button" class="ar-btn" type="button">Ver en mi mesa</button>
    </model-viewer>
    <dl class="stats">
      <div><dt>Medidas</dt><dd>${cm(d.widthM)} × ${cm(d.depthM)} × ${cm(d.heightM)} cm</dd></div>
      <div><dt>Peso</dt><dd>${mb(e.final.bytes)}${e.raw ? ` <span class="muted">(llegó ${mb(e.raw.bytes)})</span>` : ''}</dd></div>
      <div><dt>Triángulos</dt><dd>${e.final.triangles.toLocaleString('es-PE')}${e.raw ? ` <span class="muted">(de ${e.raw.triangles.toLocaleString('es-PE')})</span>` : ''}</dd></div>
      ${e.seconds != null ? `<div><dt>Tiempo</dt><dd>${e.seconds} s</dd></div>` : ''}
      ${e.credits != null ? `<div><dt>Créditos</dt><dd>${esc(e.credits)}</dd></div>` : ''}
      ${e.raw ? `<div><dt>Tamaño original del modelo</dt><dd>${cm(Math.max(e.raw.dimensions.widthM, e.raw.dimensions.depthM))} cm de ancho</dd></div>` : ''}
    </dl>
    ${e.warnings?.length ? `<ul class="warn">${e.warnings.map((w) => `<li>${esc(w)}</li>`).join('')}</ul>` : ''}
    ${rateable ? `<fieldset class="rate"><legend>Tu calificación</legend>${select('parecido', 'Se parece al plato')}${select('apetitoso', 'Se ve apetitoso')}${select('mesa', 'Se ve bien en la mesa (AR)')}</fieldset>` : ''}
  </article>`;
}

export async function writeReport(results) {
  const entries = Object.entries(results.photos || {});
  const providerIds = ['biblioteca', ...new Set(entries.flatMap(([, r]) => Object.keys(r.providers)).values())]
    .filter((v, i, a) => a.indexOf(v) === i);

  const rows = entries.map(([id, r]) => `<section class="dish" aria-labelledby="t-${esc(id)}">
      <div class="dish__photo">
        <img src="${esc(r.photo)}" alt="Foto original: ${esc(r.name)}" loading="lazy">
        <h2 id="t-${esc(id)}">${esc(r.name)}</h2>
        <p class="muted">Diámetro declarado: ${esc(r.diameterCm)} cm</p>
      </div>
      <div class="dish__models">${providerIds.map((p) => card(id, p, r.providers[p])).join('')}</div>
    </section>`).join('');

  const html = `<!doctype html>
<html lang="es-PE">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Prueba de modelos 3D</title>
<script type="module" src="${MODEL_VIEWER}"></script>
<style>
  :root { --bg:#FBF4EA; --surface:#FFFFFF; --ink:#2B1D16; --muted:#6B5D54; --line:#E5D9CC; --accent:#C2562F; --warn-bg:#FFF4D6; --warn-ink:#7A5200; }
  @media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --bg:#17120F; --surface:#221B17; --ink:#F3E9DF; --muted:#B4A69B; --line:#3A2F29; --accent:#E07A50; --warn-bg:#3A2E12; --warn-ink:#F2CF7A; } }
  :root[data-theme="dark"] { --bg:#17120F; --surface:#221B17; --ink:#F3E9DF; --muted:#B4A69B; --line:#3A2F29; --accent:#E07A50; --warn-bg:#3A2E12; --warn-ink:#F2CF7A; }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--ink); font:16px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; }
  .wrap { max-width:1400px; margin:0 auto; padding:24px 16px 64px; }
  h1 { margin:0 0 4px; font-size:1.6rem; }
  .muted { color:var(--muted); }
  .intro { max-width:70ch; }
  .toolbar { display:flex; gap:8px; flex-wrap:wrap; margin:16px 0 8px; }
  button.btn { font:inherit; padding:8px 14px; border-radius:999px; border:1px solid var(--line); background:var(--surface); color:var(--ink); cursor:pointer; }
  button.btn--primary { background:var(--accent); border-color:var(--accent); color:#fff; }
  .dish { border-top:1px solid var(--line); padding:24px 0; display:grid; grid-template-columns:260px 1fr; gap:20px; }
  .dish__photo img { width:100%; aspect-ratio:1; object-fit:cover; border-radius:12px; display:block; }
  .dish__photo h2 { margin:10px 0 0; font-size:1.2rem; text-transform:capitalize; }
  .dish__models { display:grid; grid-template-columns:repeat(auto-fill, minmax(280px, 1fr)); gap:16px; }
  .card { background:var(--surface); border:1px solid var(--line); border-radius:14px; padding:12px; display:flex; flex-direction:column; gap:10px; min-width:0; }
  .card__head h3 { margin:0; font-size:1rem; }
  .card--empty .state { color:var(--muted); margin:auto 0; }
  model-viewer { width:100%; height:260px; background:color-mix(in srgb, var(--line) 35%, transparent); border-radius:10px; --poster-color:transparent; }
  .ar-btn { position:absolute; bottom:10px; left:50%; transform:translateX(-50%); font:inherit; font-weight:600; padding:8px 16px; border:0; border-radius:999px; background:var(--accent); color:#fff; }
  .stats { margin:0; display:grid; grid-template-columns:1fr 1fr; gap:6px 12px; font-size:.9rem; }
  .stats dt { color:var(--muted); font-size:.8rem; }
  .stats dd { margin:0; }
  .warn { margin:0; padding:8px 10px 8px 28px; background:var(--warn-bg); color:var(--warn-ink); border-radius:8px; font-size:.85rem; }
  .rate { border:1px dashed var(--line); border-radius:10px; margin:0; padding:8px 10px; display:grid; gap:6px; font-size:.9rem; }
  .rate label { display:flex; justify-content:space-between; align-items:center; gap:8px; }
  .rate select { font:inherit; padding:2px 6px; border-radius:6px; border:1px solid var(--line); background:var(--surface); color:var(--ink); }
  @media (max-width: 720px) { .dish { grid-template-columns:1fr; } .dish__photo img { max-height:240px; } }
</style>
</head>
<body>
<main class="wrap">
  <h1>Prueba de modelos 3D generados con IA</h1>
  <p class="intro muted">Cada fila compara la foto real con el modelo actual de la biblioteca y con lo que generó cada proveedor.
  Todos están escalados al diámetro declarado del plato. Ábrelo en el celular y toca <strong>Ver en mi mesa</strong> para revisarlo en Realidad Aumentada.
  Las calificaciones se guardan en este navegador; exporta el CSV para juntar las del equipo.</p>
  <div class="toolbar">
    <button class="btn btn--primary" type="button" id="export">Exportar calificaciones (CSV)</button>
    <button class="btn" type="button" id="clear">Borrar mis calificaciones</button>
  </div>
  ${rows || '<p>No hay resultados todavía.</p>'}
</main>
<script>
  const KEY = 'platter.spike.ratings';
  const load = () => { try { return JSON.parse(localStorage.getItem(KEY) || '{}'); } catch { return {}; } };
  const store = (v) => { try { localStorage.setItem(KEY, JSON.stringify(v)); } catch {} };
  const ratings = load();
  for (const s of document.querySelectorAll('[data-rate]')) {
    s.value = ratings[s.dataset.rate]?.[s.dataset.field] ?? '';
    s.addEventListener('change', () => {
      (ratings[s.dataset.rate] ??= {})[s.dataset.field] = s.value;
      store(ratings);
    });
  }
  document.getElementById('export').addEventListener('click', () => {
    const lines = ['plato,proveedor,parecido,apetitoso,mesa'];
    for (const [k, v] of Object.entries(ratings)) {
      const [plato, proveedor] = k.split(':');
      lines.push([plato, proveedor, v.parecido ?? '', v.apetitoso ?? '', v.mesa ?? ''].join(','));
    }
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([lines.join('\\n')], { type: 'text/csv' }));
    a.download = 'calificaciones-modelos-3d.csv';
    a.click();
  });
  document.getElementById('clear').addEventListener('click', () => {
    if (!confirm('¿Borrar tus calificaciones de este navegador?')) return;
    store({});
    location.reload();
  });
</script>
</body>
</html>`;
  await writeFile(path.join(OUT_DIR, 'index.html'), html);
  return path.join(OUT_DIR, 'index.html');
}
