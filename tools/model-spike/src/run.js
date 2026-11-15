// Prueba comparativa de generación 3D a partir de fotos reales de platos.
//
//   npm run generate                 todas las fotos de photos/ con los proveedores que tengan API key
//   npm run generate -- --providers=tripo --limit=2
//   npm run mock                     flujo completo sin red ni créditos
//   npm run report                   solo regenera out/index.html
//
// Nombre de la foto: "<plato>@<diámetro en cm>.jpg", p. ej. "lomo-saltado@28.jpg" (sin @ → 27 cm).
// El progreso se guarda en out/results.json: volver a ejecutar NO repite tareas ya pagadas.
import { copyFile, mkdir, readFile, readdir, stat, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';
import { DEFAULT_PHOTOS_DIR, LIBRARY_DIR, OUT_DIR } from './paths.js';
import { inspect, optimize } from './optimize.js';
import { writeReport } from './report.js';
import { download, sleep } from './providers/http.js';

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, '').split('=');
    return [k, v ?? true];
  }),
);
const DEFAULT_DIAMETER_CM = Number(args.diameter) || 27;
const POLL_MS = 4000;
const TIMEOUT_MS = 15 * 60 * 1000;
const PHOTOS_DIR = path.resolve(args.photos || DEFAULT_PHOTOS_DIR);
const RESULTS_FILE = path.join(OUT_DIR, 'results.json');

await mkdir(path.join(OUT_DIR, 'models'), { recursive: true });
await mkdir(path.join(OUT_DIR, 'photos'), { recursive: true });

const results = existsSync(RESULTS_FILE) ? JSON.parse(await readFile(RESULTS_FILE, 'utf8')) : { photos: {} };
const save = () => writeFile(RESULTS_FILE, JSON.stringify(results, null, 2));

if (args['report-only']) {
  await writeReport(results);
  process.exit(0);
}

// ---------------------------------------------------------------- proveedores
async function loadProviders() {
  if (args.mock) return [(await import('./providers/mock.js')).createMock()];
  const wanted = typeof args.providers === 'string' ? args.providers.split(',') : ['tripo', 'meshy'];
  const list = [];
  if (wanted.includes('tripo')) {
    if (process.env.TRIPO_API_KEY) list.push((await import('./providers/tripo.js')).createTripo(process.env.TRIPO_API_KEY));
    else console.warn('· Tripo omitido: falta TRIPO_API_KEY en .env');
  }
  if (wanted.includes('meshy')) {
    if (process.env.MESHY_API_KEY) list.push((await import('./providers/meshy.js')).createMeshy(process.env.MESHY_API_KEY));
    else console.warn('· Meshy omitido: falta MESHY_API_KEY en .env');
  }
  if (!list.length) console.warn('· Sin proveedores de IA activos: solo se procesan los modelos de imports/ (no se gastan créditos).');
  return list;
}

// ---------------------------------------------------------------- modelos importados (Apple, TRELLIS, etc.)
// imports/<plato@diámetro>--<fuente>.glb, p. ej. "lomo-saltado@28--trellis.glb" o "...--apple.glb".
const IMPORTS_DIR = path.join(path.dirname(OUT_DIR), 'imports');
const IMPORT_LABELS = {
  apple: 'Apple Object Capture (fotogrametría)',
  trellis: 'TRELLIS.2 (Hugging Face)',
};

async function listImports() {
  if (args.mock || !existsSync(IMPORTS_DIR)) return [];
  return (await readdir(IMPORTS_DIR))
    .filter((f) => /--[a-z0-9_-]+\.glb$/i.test(f))
    .sort()
    .map((f) => {
      const [, base, source] = f.match(/^(.*)--([a-z0-9_-]+)\.glb$/i);
      return { ...parsePhoto(path.join(IMPORTS_DIR, `${base}.glb`)), source: source.toLowerCase(), file: path.join(IMPORTS_DIR, f) };
    });
}

async function processImport(item) {
  const record = (results.photos[item.id] ??= { providers: {} });
  record.name ??= item.name;
  record.diameterCm = item.diameterCm;
  if (!record.photo && existsSync(path.join(OUT_DIR, 'photos', `${item.id}.jpg`))) record.photo = `photos/${item.id}.jpg`;
  record.providers.biblioteca ??= await baseline(item);
  const entry = (record.providers[item.source] ??= {});
  const mtime = (await stat(item.file)).mtimeMs;
  if (entry.status === 'done' && entry.sourceMtime === mtime && entry.diameterCm === item.diameterCm) {
    console.log(`    ${item.source.padEnd(6)} ${item.id}: sin cambios`);
    return;
  }
  entry.label = IMPORT_LABELS[item.source] ?? `${item.source} (importado)`;
  try {
    const out = await optimize(new Uint8Array(await readFile(item.file)), { diameterM: item.diameterCm / 100 });
    await writeFile(path.join(OUT_DIR, 'models', `${item.id}.${item.source}.glb`), out.bytes);
    Object.assign(entry, {
      status: 'done', file: `models/${item.id}.${item.source}.glb`, raw: out.raw, final: out.final,
      scaleFactor: out.scaleFactor, warnings: out.warnings, sourceMtime: mtime, diameterCm: item.diameterCm, error: undefined,
    });
    const f = entry.final;
    console.log(`    ${item.source.padEnd(6)} ${item.id}: ✓ ${(f.bytes / 1024 / 1024).toFixed(2)} MB · ${f.triangles} triángulos${entry.warnings.length ? ` · ⚠ ${entry.warnings.join('; ')}` : ''}`);
  } catch (e) {
    Object.assign(entry, { status: 'error', error: e.message });
    console.log(`    ${item.source.padEnd(6)} ${item.id}: ✗ ${e.message}`);
  }
  await save();
}

// ---------------------------------------------------------------- fotos
function parsePhoto(file) {
  const base = path.basename(file, path.extname(file));
  const m = base.match(/^(.*?)@(\d+(?:[.,]\d+)?)$/);
  const name = (m ? m[1] : base).trim();
  const id = name.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  return { id, name: name.replace(/[-_]+/g, ' '), diameterCm: m ? Number(m[2].replace(',', '.')) : DEFAULT_DIAMETER_CM, file };
}

async function listPhotos() {
  if (!existsSync(PHOTOS_DIR)) return [];
  const files = (await readdir(PHOTOS_DIR)).filter((f) => /\.(jpe?g|png|webp)$/i.test(f)).sort();
  const photos = files.map((f) => parsePhoto(path.join(PHOTOS_DIR, f)));
  return args.limit ? photos.slice(0, Number(args.limit)) : photos;
}

/** JPEG ≤ 2048 px, orientado según EXIF y sin metadatos (la ubicación GPS no sale del equipo). */
async function preparePhoto(photo) {
  const jpeg = await sharp(photo.file).rotate().resize({ width: 2048, height: 2048, fit: 'inside', withoutEnlargement: true }).jpeg({ quality: 90 }).toBuffer();
  await sharp(jpeg).resize({ width: 900, height: 900, fit: 'inside' }).jpeg({ quality: 80 }).toFile(path.join(OUT_DIR, 'photos', `${photo.id}.jpg`));
  return jpeg;
}

// ---------------------------------------------------------------- biblioteca actual (línea base)
const KEYWORDS = [
  ['cebiche', 'ceviche'], ['ceviche', 'ceviche'], ['tiradito', 'ceviche'], ['lomo', 'lomo-saltado'], ['saltado', 'lomo-saltado'],
  ['aji', 'aji-de-gallina'], ['causa', 'causa'], ['hamburguesa', 'hamburguesa'], ['burger', 'hamburguesa'], ['sanguch', 'hamburguesa'],
  ['pizza', 'pizza'], ['ensalada', 'ensalada'], ['postre', 'postre'], ['suspiro', 'postre'], ['torta', 'postre'],
  ['chicha', 'bebida'], ['jugo', 'bebida'], ['limonada', 'bebida'], ['bebida', 'bebida'],
];
const library = JSON.parse(await readFile(path.join(LIBRARY_DIR, 'models.json'), 'utf8'));

async function baseline(photo) {
  const modelId = KEYWORDS.find(([k]) => photo.id.includes(k))?.[1] ?? 'generico';
  const meta = library.find((m) => m.id === modelId);
  const target = path.join(OUT_DIR, 'models', `${photo.id}.biblioteca.glb`);
  await copyFile(path.join(LIBRARY_DIR, 'models', `${modelId}.glb`), target);
  const info = await inspect(new Uint8Array(await readFile(target)));
  return { status: 'done', label: `Biblioteca actual (${meta?.name ?? modelId})`, file: `models/${photo.id}.biblioteca.glb`, final: info, warnings: [] };
}

// ---------------------------------------------------------------- generación
async function generate(provider, photo, jpeg, entry) {
  const rawPath = path.join(OUT_DIR, 'models', `${photo.id}.${provider.id}.raw.glb`);
  let raw;

  if (existsSync(rawPath) && !args.force) {
    raw = new Uint8Array(await readFile(rawPath)); // ya descargado: solo se vuelve a optimizar
  } else {
    if (!entry.taskId || entry.status === 'done' || (entry.status === 'error' && (args.force || args['retry-failed']))) {
      entry.taskId = await provider.create(jpeg, photo.id);
      entry.startedAt = Date.now();
    }
    entry.status = 'pending';
    await save();

    let result;
    let lastLog = 0;
    for (;;) {
      result = await provider.poll(entry.taskId);
      if (result.done) break;
      if (Date.now() - entry.startedAt > TIMEOUT_MS) throw new Error('Tiempo de espera agotado (15 min)');
      if (Date.now() - lastLog > 15000) {
        console.log(`    ${provider.id.padEnd(6)} ${photo.id}: ${result.progress}%`);
        lastLog = Date.now();
      }
      await sleep(POLL_MS);
    }
    entry.seconds = Math.round((Date.now() - entry.startedAt) / 1000);
    entry.credits = result.credits;
    if (result.previewUrl) {
      try {
        await writeFile(path.join(OUT_DIR, 'models', `${photo.id}.${provider.id}.preview.png`), await download(result.previewUrl));
        entry.preview = `models/${photo.id}.${provider.id}.preview.png`;
      } catch { /* la vista previa es opcional */ }
    }
    raw = result.modelBytes ?? (await download(result.modelUrl));
    await writeFile(rawPath, raw);
  }

  const out = await optimize(raw, { diameterM: photo.diameterCm / 100 });
  await writeFile(path.join(OUT_DIR, 'models', `${photo.id}.${provider.id}.glb`), out.bytes);
  Object.assign(entry, {
    status: 'done',
    file: `models/${photo.id}.${provider.id}.glb`,
    raw: out.raw,
    final: out.final,
    scaleFactor: out.scaleFactor,
    warnings: out.warnings,
    error: undefined,
  });
}

// ---------------------------------------------------------------- principal
const providers = await loadProviders();
const photos = await listPhotos();
const imports = await listImports();
if (!photos.length && !imports.length) {
  console.error(`No hay fotos en ${PHOTOS_DIR} ni modelos en imports/. Agrega JPG/PNG con nombre "<plato>@<diámetro cm>.jpg" (ver README.md).`);
  process.exit(1);
}
if (!providers.length && !imports.length) {
  console.error('No hay proveedores de IA activos ni modelos en imports/: no hay nada que generar. Descarga un GLB (p. ej. de TRELLIS) a imports/<plato>@<cm>--trellis.glb, o usa npm run mock para probar el flujo.');
  process.exit(1);
}
if (providers.length) console.log(`${photos.length} foto(s) × ${providers.map((p) => p.label).join(', ')}\n`);

for (const photo of photos) {
  const record = (results.photos[photo.id] ??= { providers: {} });
  Object.assign(record, { name: photo.name, diameterCm: photo.diameterCm, photo: `photos/${photo.id}.jpg` });
  const jpeg = await preparePhoto(photo);
  record.providers.biblioteca = await baseline(photo);
  console.log(`▸ ${photo.name} (${photo.diameterCm} cm)`);

  await Promise.all(
    providers.map(async (provider) => {
      const entry = (record.providers[provider.id] ??= {});
      entry.label = provider.label;
      if (entry.status === 'done' && !args.force) {
        console.log(`    ${provider.id.padEnd(6)} ya generado (usa --force para repetir y pagar de nuevo)`);
        return;
      }
      if (entry.status === 'error' && entry.remoteFailure && !args['retry-failed'] && !args.force) {
        console.log(`    ${provider.id.padEnd(6)} falló antes (${entry.error}); usa --retry-failed para reintentar`);
        return;
      }
      try {
        await generate(provider, photo, jpeg, entry);
        const f = entry.final;
        console.log(`    ${provider.id.padEnd(6)} ✓ ${entry.seconds ?? '-'} s · ${(f.bytes / 1024 / 1024).toFixed(2)} MB · ${f.triangles} triángulos${entry.warnings.length ? ` · ⚠ ${entry.warnings.join('; ')}` : ''}`);
      } catch (e) {
        Object.assign(entry, { status: 'error', error: e.message, remoteFailure: !!e.remoteFailure });
        console.log(`    ${provider.id.padEnd(6)} ✗ ${e.message}`);
      }
      await save();
    }),
  );
  await save();
}

if (imports.length) {
  console.log(`\nModelos importados (${imports.length}):`);
  for (const item of imports) await processImport(item);
}

await writeReport(results);
const failed = photos.flatMap((p) => providers.filter((pr) => results.photos[p.id]?.providers[pr.id]?.status !== 'done'));
console.log(failed.length
  ? `\nTerminado con ${failed.length} generación(es) sin resultado (ver mensajes ✗). Revisa lo que salió con:  npm run serve`
  : '\nListo. Revisa los resultados con:  npm run serve');
