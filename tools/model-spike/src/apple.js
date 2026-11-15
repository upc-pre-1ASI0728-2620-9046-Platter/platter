// Fotogrametría gratuita con Apple Object Capture → GLB listo para el comparador.
//
//   npm run apple -- <carpeta-con-fotos> <plato@diámetro>  [preview|reduced|medium|full]
//   npm run apple -- ~/Desktop/fotos-lomo lomo-saltado@28
//
// Resultado: imports/<plato@diámetro>--apple.glb (+ .usdz). Luego `npm run generate` lo escala y lo agrega
// a la página comparativa. Si photos/ no tiene foto de ese plato, se copia una de la sesión como referencia.
import { execFile, spawn } from 'node:child_process';
import { existsSync, statSync } from 'node:fs';
import { copyFile, mkdir, readdir, readFile, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { promisify } from 'node:util';
import obj2gltf from 'obj2gltf';
import { DEFAULT_PHOTOS_DIR, TOOL_DIR } from './paths.js';

const run = promisify(execFile);
const SOURCE = path.join(TOOL_DIR, 'apple', 'capture.swift');
const BINARY = path.join(TOOL_DIR, 'apple', 'capture');
const IMPORTS = path.join(TOOL_DIR, 'imports');
const PHOTO_EXT = /\.(jpe?g|png|heic|heif)$/i;

const [inputArg, nameArg, detail = 'reduced'] = process.argv.slice(2);
if (!inputArg || !nameArg || !/^[^@/\\]+(@\d+(?:[.,]\d+)?)?$/.test(nameArg)) {
  console.error('Uso: npm run apple -- <carpeta-con-fotos> <plato@diámetro>   (ej. lomo-saltado@28)');
  process.exit(1);
}
if (process.platform !== 'darwin') {
  console.error('Object Capture solo funciona en macOS (Mac con Apple Silicon).');
  process.exit(1);
}
const input = path.resolve(inputArg.replace(/^~/, process.env.HOME));
if (!existsSync(input)) {
  console.error(`No existe la carpeta ${input}`);
  process.exit(1);
}
const photos = (await readdir(input)).filter((f) => PHOTO_EXT.test(f)).sort();
if (!photos.length) {
  console.error(`La carpeta ${input} no tiene fotos (JPG, PNG o HEIC).`);
  console.error('Toma 40–80 fotos alrededor del plato con el iPhone, pásalas por AirDrop a esa carpeta y vuelve a correr el comando.');
  process.exit(1);
}
if (photos.length < 20) {
  console.warn(`⚠ Solo hay ${photos.length} fotos. Object Capture necesita al menos 20 (ideal 40–80) para un buen resultado.`);
}

// 1. Compila la herramienta Swift la primera vez (o si cambió).
if (!existsSync(BINARY) || statSync(BINARY).mtimeMs < statSync(SOURCE).mtimeMs) {
  console.log('Compilando la herramienta de Object Capture (solo la primera vez)…');
  try {
    await run('swiftc', ['-O', SOURCE, '-o', BINARY]);
  } catch (e) {
    console.error(`No se pudo compilar con swiftc. ¿Está instalado Xcode o sus Command Line Tools?\n${e.stderr || e.message}`);
    process.exit(1);
  }
}

// 2. Fotogrametría.
const work = path.join(IMPORTS, '.work', nameArg);
await rm(work, { recursive: true, force: true });
await mkdir(work, { recursive: true });
console.log(`Procesando ${photos.length} fotos con Object Capture (${detail}). Suele tardar de 1 a 10 minutos…`);
const started = Date.now();
const code = await new Promise((resolve) => {
  const child = spawn(BINARY, [input, work, detail]);
  let lastShown = -1;
  const onLine = (line) => {
    if (line.startsWith('PROGRESS ')) {
      const pct = Math.floor(Number(line.slice(9)) * 100);
      if (pct >= lastShown + 10 || pct === 100) {
        lastShown = pct;
        process.stdout.write(`  ${String(pct).padStart(3)}%\n`);
      }
    } else if (line.startsWith('WARN ') || line.startsWith('ERROR ')) {
      console.log(`  ${line.startsWith('WARN') ? '⚠' : '✗'} ${line.replace(/^\w+ /, '')}`);
    }
  };
  for (const stream of [child.stdout, child.stderr]) {
    let buf = '';
    stream.on('data', (d) => {
      buf += d;
      const lines = buf.split('\n');
      buf = lines.pop();
      lines.forEach(onLine);
    });
  }
  child.on('close', resolve);
});
const objDir = path.join(work, 'obj');
const objFile = existsSync(objDir) ? (await readdir(objDir)).find((f) => f.endsWith('.obj')) : null;
if (code !== 0 || !objFile) {
  console.error('\nObject Capture no pudo armar el modelo. Revisa la guía de fotos del README (más fotos, más superposición, buena luz).');
  process.exit(1);
}

// 3. OBJ → GLB. Las texturas se leen del MTL que escribe Object Capture (map_Kd, norm, map_ao).
const mtlFile = (await readdir(objDir)).find((f) => f.endsWith('.mtl'));
const textures = {};
if (mtlFile) {
  for (const line of (await readFile(path.join(objDir, mtlFile), 'utf8')).split('\n')) {
    const [key, file] = line.trim().split(/\s+/);
    const full = file && path.join(objDir, file);
    if (key === 'map_Kd') textures.baseColorTexture = full;
    if (key === 'norm' || key === 'map_Bump' || key === 'bump') textures.normalTexture = full;
    if (key === 'map_ao') textures.occlusionTexture = full;
  }
}
const glb = await obj2gltf(path.join(objDir, objFile), { binary: true, overridingTextures: textures, logger: () => {} });
await mkdir(IMPORTS, { recursive: true });
await writeFile(path.join(IMPORTS, `${nameArg}--apple.glb`), glb);
await copyFile(path.join(work, 'model.usdz'), path.join(IMPORTS, `${nameArg}--apple.usdz`)).catch(() => {});

// 4. Foto de referencia para la página (y para comparar con la IA de una sola foto) si aún no hay una.
const base = nameArg.split('@')[0];
const existing = existsSync(DEFAULT_PHOTOS_DIR) ? (await readdir(DEFAULT_PHOTOS_DIR)).filter((f) => f.split('@')[0].replace(/\.\w+$/, '') === base) : [];
if (!existing.length) {
  const pick = photos[Math.floor(photos.length / 2)];
  await mkdir(DEFAULT_PHOTOS_DIR, { recursive: true });
  // sips (incluido en macOS) convierte también HEIC a JPG.
  await run('sips', ['-s', 'format', 'jpeg', path.join(input, pick), '--out', path.join(DEFAULT_PHOTOS_DIR, `${nameArg}.jpg`)]);
  console.log(`  Foto de referencia: photos/${nameArg}.jpg (cámbiala por una a 45° si quieres compararla con la IA)`);
}

await rm(path.join(IMPORTS, '.work'), { recursive: true, force: true });
console.log(`\n✓ imports/${nameArg}--apple.glb listo en ${Math.round((Date.now() - started) / 1000)} s.`);
console.log('  Ahora ejecuta:  npm run generate   (no gasta créditos si no hay API keys)  y luego  npm run serve');
