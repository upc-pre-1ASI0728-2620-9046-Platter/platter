// Logo de Platter: una campana (cloche) con su órbita, dentro del marco de escaneo de la cámara (AR).
// Genera los SVG maestros en brand/ y todas las exportaciones que usan los productos.
//
//   npm run build
//
// Salidas:
//   brand/platter-mark.svg         isotipo a color
//   brand/platter-logo.svg         isotipo + "platter" (fondo claro)
//   brand/platter-logo-dark.svg    isotipo + "platter" en crema (fondo oscuro)
//   brand/platter-app-icon.svg     ícono de app (tile naranja, isotipo crema)
//   brand/preview.png              lámina de control
//   + exportaciones a landing/, webar/ y admin_app/ (íconos web, Android, iOS, macOS)
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import opentype from 'opentype.js';
import sharp from 'sharp';

const here = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(here, '../..');
const BRAND = path.join(ROOT, 'brand');

export const COLORS = {
  orange: '#F27321',
  orangeLight: '#FF9A4A',
  orangeDeep: '#E2471A',
  espresso: '#2B1712',
  cream: '#FFF6EC',
};

const font = opentype.parse(
  (await readFile(path.join(here, 'node_modules/@fontsource/fredoka/files/fredoka-latin-600-normal.woff'))).buffer,
);

/**
 * Texto convertido a trazo SVG. Se serializa a mano porque toPathData() de opentype.js 2.0 introduce NaN
 * al optimizar algunos glifos. Devuelve un objeto compatible con lo que usa el resto del script.
 */
function textPath(text, x, y, size) {
  const p = font.getPath(text, x, y, size);
  const n = (v) => Number(v.toFixed(2));
  const d = p.commands
    .map((c) => {
      switch (c.type) {
        case 'M':
        case 'L':
          return `${c.type}${n(c.x)} ${n(c.y)}`;
        case 'Q':
          return `Q${n(c.x1)} ${n(c.y1)} ${n(c.x)} ${n(c.y)}`;
        case 'C':
          return `C${n(c.x1)} ${n(c.y1)} ${n(c.x2)} ${n(c.y2)} ${n(c.x)} ${n(c.y)}`;
        default:
          return 'Z';
      }
    })
    .join('');
  return {
    toPathData: () => d,
    toSVG: () => `<path d="${d}" fill="${p.fill ?? '#000'}"/>`,
    getBoundingBox: () => p.getBoundingBox(),
    set fill(v) {
      p.fill = v;
    },
  };
}

// ---------------------------------------------------------------- isotipo (viewBox 0 0 600 520)
function mark({ id = 'm', mono = null } = {}) {
  const c = mono ?? COLORS.orange;
  const domeFill = mono ? `url(#${id}-domeMono)` : `url(#${id}-dome)`;
  const corner = (d) => `<path d="${d}" fill="none" stroke="${c}" stroke-width="26" stroke-linecap="round" stroke-linejoin="round"/>`;
  return `
  <defs>
    <linearGradient id="${id}-dome" x1="0.2" y1="0" x2="0.85" y2="1">
      <stop offset="0" stop-color="${COLORS.orangeLight}"/>
      <stop offset="0.55" stop-color="${COLORS.orange}"/>
      <stop offset="1" stop-color="${COLORS.orangeDeep}"/>
    </linearGradient>
    <linearGradient id="${id}-domeMono" x1="0.2" y1="0" x2="0.85" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="1" stop-color="#F6DCC8"/>
    </linearGradient>
  </defs>
  ${corner('M112 116 V64 a22 22 0 0 1 22 -22 H184')}
  ${corner('M416 42 H466 a22 22 0 0 1 22 22 V116')}
  ${corner('M488 404 V456 a22 22 0 0 1 -22 22 H416')}
  ${corner('M184 478 H134 a22 22 0 0 1 -22 -22 V404')}
  <ellipse cx="300" cy="378" rx="128" ry="16" fill="${mono ? '#000' : COLORS.orangeDeep}" opacity="${mono ? 0.12 : 0.16}"/>
  <path d="M58 320 A242 54 0 0 1 542 320" fill="none" stroke="${c}" stroke-width="12" stroke-linecap="round" opacity="0.85"/>
  <rect x="289" y="146" width="22" height="26" rx="6" fill="${mono ? '#F6DCC8' : COLORS.orangeDeep}"/>
  <circle cx="300" cy="140" r="21" fill="${domeFill}"/>
  <path d="M132 322 A168 160 0 0 1 468 322 Z" fill="${domeFill}"/>
  <ellipse cx="226" cy="232" rx="34" ry="17" transform="rotate(-38 226 232)" fill="#FFFFFF" opacity="${mono ? 0.7 : 0.42}"/>
  <rect x="118" y="316" width="364" height="18" rx="9" fill="${mono ? '#F6DCC8' : COLORS.orangeDeep}"/>
  <path d="M58 320 A242 54 0 0 0 542 320" fill="none" stroke="${c}" stroke-width="18" stroke-linecap="round"/>`;
}

// ---------------------------------------------------------------- logotipo
function wordmark(fill, x, baseline, size) {
  const p = textPath('platter', x, baseline, size);
  p.fill = fill;
  const bb = p.getBoundingBox();
  return { svg: p.toSVG({ decimalPlaces: 2 }), bb };
}

function logo({ dark = false } = {}) {
  const size = 340;
  const w = wordmark(dark ? COLORS.cream : COLORS.espresso, 630, 372, size);
  const width = Math.ceil(w.bb.x2 + 20);
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} 520" width="${width}" height="520" role="img" aria-label="Platter">
  <title>Platter</title>${mark({ id: dark ? 'd' : 'l' })}
  ${w.svg}
</svg>`;
}

const markSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 520" width="600" height="520" role="img" aria-label="Platter"><title>Platter</title>${mark()}</svg>`;

/** Ícono cuadrado. rounded=false → a sangre (iOS aplica su propia máscara). */
function appIcon({ rounded = true, pad = 0.16 } = {}) {
  const s = 1024;
  const inner = s * (1 - pad * 2);
  const scale = inner / 600;
  const tx = (s - 600 * scale) / 2;
  const ty = (s - 520 * scale) / 2 + 10;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${s} ${s}" width="${s}" height="${s}">
  <defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FF8E3C"/><stop offset="1" stop-color="#E4461B"/></linearGradient></defs>
  <rect width="${s}" height="${s}" rx="${rounded ? 228 : 0}" fill="url(#bg)"/>
  <g transform="translate(${tx} ${ty}) scale(${scale})">${mark({ id: 'i', mono: COLORS.cream })}</g>
</svg>`;
}

// ---------------------------------------------------------------- exportación
const png = (svg, width, out, opts = {}) =>
  sharp(Buffer.from(svg), { density: 300 }).resize({ width, height: opts.height, fit: 'contain', background: opts.background ?? { r: 0, g: 0, b: 0, alpha: 0 } })
    .flatten(opts.flatten ? { background: opts.flatten } : false)
    .png({ compressionLevel: 9 })
    .toFile(out);

async function main() {
  await mkdir(BRAND, { recursive: true });
  const files = {
    'platter-mark.svg': markSvg,
    'platter-logo.svg': logo(),
    'platter-logo-dark.svg': logo({ dark: true }),
    'platter-app-icon.svg': appIcon(),
    'platter-app-icon-square.svg': appIcon({ rounded: false }),
  };
  for (const [name, svg] of Object.entries(files)) await writeFile(path.join(BRAND, name), svg);

  // Lámina de control.
  const board = await sharp({ create: { width: 1600, height: 1000, channels: 4, background: '#FCF8F3' } })
    .composite([
      { input: await sharp(Buffer.from(files['platter-logo.svg'])).resize({ width: 1200 }).png().toBuffer(), left: 200, top: 60 },
      { input: await sharp(Buffer.from(files['platter-app-icon.svg'])).resize(300).png().toBuffer(), left: 80, top: 640 },
      { input: await sharp(Buffer.from(files['platter-logo.svg'])).resize({ width: 420 }).png().toBuffer(), left: 470, top: 740 },
      {
        input: await sharp({ create: { width: 560, height: 360, channels: 4, background: COLORS.espresso } })
          .composite([{ input: await sharp(Buffer.from(files['platter-logo-dark.svg'])).resize({ width: 440 }).png().toBuffer(), left: 60, top: 140 }])
          .png().toBuffer(),
        left: 1040, top: 640,
      },
    ])
    .png().toFile(path.join(BRAND, 'preview.png'));
  return board;
}

/** Imagen para compartir el enlace (Open Graph, 1200×630). */
function ogImage(logoSvg) {
  const inner = logoSvg.replace(/^<svg[^>]*>/, '').replace(/<\/svg>$/, '');
  const vb = logoSvg.match(/viewBox="0 0 (\d+) (\d+)"/);
  const lw = 470;
  const scale = lw / Number(vb[1]);
  const title = textPath('Tu carta en', 80, 330, 84).toPathData({ decimalPlaces: 2 });
  const title2 = textPath('Realidad Aumentada', 80, 425, 84).toPathData({ decimalPlaces: 2 });
  const sub = textPath('Platos en 3D a tamaño real, sobre la mesa.', 82, 492, 34).toPathData({ decimalPlaces: 2 });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <defs><radialGradient id="glow" cx="90%" cy="0%" r="75%"><stop offset="0" stop-color="${COLORS.orange}" stop-opacity=".22"/><stop offset="1" stop-color="${COLORS.orange}" stop-opacity="0"/></radialGradient></defs>
  <rect width="1200" height="630" fill="#FCF7F1"/><rect width="1200" height="630" fill="url(#glow)"/>
  <g transform="translate(80 70) scale(${scale})">${inner}</g>
  <path d="${title}" fill="${COLORS.espresso}"/>
  <path d="${title2}" fill="#CC4F16"/>
  <path d="${sub}" fill="#6B5B50"/>
  <rect x="80" y="528" width="300" height="56" rx="28" fill="#CC4F16"/>
  <path d="${textPath('Desde S/ 49 al mes', 112, 566, 28).toPathData({ decimalPlaces: 2 })}" fill="#FFFFFF"/>
  <g transform="translate(905 300) scale(0.55)" opacity="0.95">${mark({ id: 'og' })}</g>
</svg>`;
}

async function exports() {
  const read = (n) => readFile(path.join(BRAND, n), 'utf8');
  const [logoSvg, logoDarkSvg, markSvgFile, iconSvg, iconSquare] = await Promise.all(
    ['platter-logo.svg', 'platter-logo-dark.svg', 'platter-mark.svg', 'platter-app-icon.svg', 'platter-app-icon-square.svg'].map(read),
  );
  const write = async (rel, data) => {
    const out = path.join(ROOT, rel);
    await mkdir(path.dirname(out), { recursive: true });
    await writeFile(out, data);
  };

  // Landing + carta del comensal (comparten origen: /brand/… e /icon.svg sirven también en /m/).
  await write('landing/brand/platter-logo.svg', logoSvg);
  await write('landing/brand/platter-logo-dark.svg', logoDarkSvg);
  await write('landing/brand/platter-mark.svg', markSvgFile);
  await write('landing/icon.svg', iconSvg);
  await png(iconSquare, 180, path.join(ROOT, 'landing/apple-touch-icon.png'));
  await png(iconSvg, 48, path.join(ROOT, 'landing/favicon.png'));
  await sharp(Buffer.from(ogImage(logoSvg))).png({ compressionLevel: 9 }).toFile(path.join(ROOT, 'landing/og.png'));

  // Panel (Flutter): logos para la interfaz.
  const A = 'admin_app/assets/brand';
  await mkdir(path.join(ROOT, A), { recursive: true });
  await png(logoSvg, 900, path.join(ROOT, A, 'logo.png'));
  await png(logoDarkSvg, 900, path.join(ROOT, A, 'logo-dark.png'));
  await png(markSvgFile, 480, path.join(ROOT, A, 'mark.png'));

  // Panel web (PWA).
  await png(iconSvg, 64, path.join(ROOT, 'admin_app/web/favicon.png'));
  await png(iconSvg, 192, path.join(ROOT, 'admin_app/web/icons/Icon-192.png'));
  await png(iconSvg, 512, path.join(ROOT, 'admin_app/web/icons/Icon-512.png'));
  const maskable = appIcon({ rounded: false, pad: 0.24 });
  await png(maskable, 192, path.join(ROOT, 'admin_app/web/icons/Icon-maskable-192.png'));
  await png(maskable, 512, path.join(ROOT, 'admin_app/web/icons/Icon-maskable-512.png'));

  // Android (ic_launcher heredado, con esquinas redondeadas).
  for (const [dir, size] of [['mdpi', 48], ['hdpi', 72], ['xhdpi', 96], ['xxhdpi', 144], ['xxxhdpi', 192]]) {
    await png(iconSvg, size, path.join(ROOT, `admin_app/android/app/src/main/res/mipmap-${dir}/ic_launcher.png`));
  }

  // iOS: a sangre y sin transparencia (el sistema aplica la máscara).
  const iosDir = path.join(ROOT, 'admin_app/ios/Runner/Assets.xcassets/AppIcon.appiconset');
  const ios = JSON.parse(await readFile(path.join(iosDir, 'Contents.json'), 'utf8'));
  for (const img of ios.images) {
    const px = Math.round(parseFloat(img.size) * parseFloat(img.scale));
    await png(iconSquare, px, path.join(iosDir, img.filename), { flatten: '#F27321' });
  }

  // macOS: tile redondeado con margen, como los íconos del sistema.
  const macDir = path.join(ROOT, 'admin_app/macos/Runner/Assets.xcassets/AppIcon.appiconset');
  const macIcon = iconSvg.replace(/viewBox="0 0 1024 1024"/, 'viewBox="-100 -100 1224 1224"');
  for (const px of [16, 32, 64, 128, 256, 512, 1024]) {
    await png(macIcon, px, path.join(macDir, `app_icon_${px}.png`));
  }
}

await main();
await exports();
console.log('Logo generado en brand/ y exportado a landing, carta y panel');
