// Definición procedimental de los platos de la biblioteca 3D de Platter.
// Todas las medidas en metros (escala real 1:1).
import { rng, lathe, sphere, dome, cylinder, box, extrude, roundedRect, paramSurface, arcStrip, leaf, place, deform, profileY } from './geom.js';

const PI = Math.PI;

// ---------------------------------------------------------------------------
// Materiales PBR (metallic-roughness). c = color base lineal-aproximado (sRGB 0..1), r = rugosidad, m = metalicidad.
export const MATERIALS = {
  ceramic: { c: [0.96, 0.95, 0.92], r: 0.22 },
  ceramicCream: { c: [0.93, 0.87, 0.76], r: 0.3 },
  wood: { c: [0.56, 0.36, 0.2], r: 0.65 },
  steel: { c: [0.87, 0.87, 0.89], r: 0.2, m: 1 },
  fish: { c: [0.97, 0.95, 0.9], r: 0.45 },
  onionRed: { c: [0.66, 0.2, 0.45], r: 0.35 },
  corn: { c: [0.97, 0.87, 0.52], r: 0.45 },
  cob: { c: [0.9, 0.85, 0.65], r: 0.7 },
  camote: { c: [0.95, 0.5, 0.15], r: 0.45 },
  lettuce: { c: [0.42, 0.7, 0.22], r: 0.5, ds: true },
  herb: { c: [0.16, 0.45, 0.1], r: 0.5, ds: true },
  lecheTigre: { c: [0.93, 0.91, 0.82], r: 0.06 },
  chili: { c: [0.85, 0.12, 0.08], r: 0.35 },
  beef: { c: [0.5, 0.25, 0.12], r: 0.32 },
  tomato: { c: [0.86, 0.16, 0.09], r: 0.28 },
  onion: { c: [0.86, 0.62, 0.68], r: 0.35 },
  fries: { c: [0.98, 0.78, 0.38], r: 0.55 },
  rice: { c: [0.96, 0.94, 0.87], r: 0.8 },
  ajiCream: { c: [0.98, 0.76, 0.2], r: 0.35 },
  eggWhite: { c: [0.98, 0.97, 0.95], r: 0.3 },
  yolk: { c: [1.0, 0.72, 0.12], r: 0.4 },
  olive: { c: [0.17, 0.08, 0.12], r: 0.15 },
  potato: { c: [0.96, 0.86, 0.55], r: 0.5 },
  causa: { c: [1.0, 0.82, 0.22], r: 0.55 },
  chicken: { c: [0.95, 0.9, 0.78], r: 0.5 },
  avocado: { c: [0.55, 0.72, 0.25], r: 0.4 },
  mayo: { c: [0.98, 0.95, 0.85], r: 0.3 },
  huancaina: { c: [1.0, 0.7, 0.15], r: 0.3 },
  bun: { c: [0.86, 0.55, 0.25], r: 0.5 },
  sesame: { c: [0.97, 0.92, 0.78], r: 0.5 },
  patty: { c: [0.3, 0.16, 0.08], r: 0.6 },
  cheese: { c: [1.0, 0.72, 0.15], r: 0.35, ds: true },
  ketchup: { c: [0.7, 0.06, 0.04], r: 0.15 },
  dough: { c: [0.93, 0.75, 0.45], r: 0.6 },
  crust: { c: [0.86, 0.58, 0.3], r: 0.6 },
  pizzaCheese: { c: [0.99, 0.86, 0.5], r: 0.45 },
  pepperoni: { c: [0.7, 0.15, 0.08], r: 0.35 },
  cucumber: { c: [0.65, 0.8, 0.45], r: 0.4 },
  carrot: { c: [0.97, 0.5, 0.1], r: 0.45 },
  queso: { c: [0.98, 0.97, 0.92], r: 0.6 },
  sponge: { c: [0.95, 0.8, 0.5], r: 0.75 },
  manjar: { c: [0.72, 0.42, 0.18], r: 0.25 },
  cream: { c: [0.99, 0.97, 0.93], r: 0.45 },
  strawberry: { c: [0.85, 0.08, 0.12], r: 0.25 },
  chocolate: { c: [0.25, 0.12, 0.06], r: 0.2 },
  glass: { c: [0.92, 0.96, 1.0], a: 0.22, r: 0.05, blend: true },
  chicha: { c: [0.32, 0.04, 0.2], r: 0.08 },
  ice: { c: [0.9, 0.95, 1.0], a: 0.55, r: 0.05, blend: true },
  lime: { c: [0.6, 0.8, 0.2], r: 0.4 },
  pineapple: { c: [0.98, 0.85, 0.35], r: 0.5 },
  strawRed: { c: [0.9, 0.25, 0.2], r: 0.4 },
  lemonPulp: { c: [0.86, 0.93, 0.5], r: 0.35 },
};

// ---------------------------------------------------------------------------
// Contenedor de partes agrupadas por material.
class Dish {
  constructor(id, seed) {
    this.id = id;
    this.parts = new Map();
    this.rand = rng(seed);
  }
  /**
   * @param mat     nombre de material
   * @param geom    geometría base (sin transformar)
   * @param xf      transformación {s, r, t}
   * @param opts    tint: multiplicador RGB; colorFn(pLocal) → multiplicador RGB por vértice
   */
  add(mat, geom, xf = {}, { tint = [1, 1, 1], colorFn } = {}) {
    if (!MATERIALS[mat]) throw new Error(`Material desconocido: ${mat}`);
    const colors = [];
    for (let i = 0; i < geom.positions.length; i += 3) {
      const c = colorFn ? colorFn([geom.positions[i], geom.positions[i + 1], geom.positions[i + 2]]) : [1, 1, 1];
      colors.push(...[0, 1, 2].map((k) => Math.max(0, Math.min(1, c[k] * tint[k]))));
    }
    const g = place(geom, xf);
    g.colors = colors;
    if (!this.parts.has(mat)) this.parts.set(mat, []);
    this.parts.get(mat).push(g);
    return this;
  }
  /** Variación de tono aleatoria (vertex color) alrededor de 1. */
  jitter(amount = 0.08) {
    const v = 1 - this.rand() * amount;
    return [v, v * (1 - this.rand() * amount * 0.3), v * (1 - this.rand() * amount * 0.3)];
  }
}

// Ruido de valor barato y determinista para colorFn/deform.
function hashNoise(x, y, z) {
  const s = Math.sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453;
  return s - Math.floor(s);
}
const speckle = (amount, freq = 600) => (p) => {
  const v = 1 - amount * hashNoise(Math.floor(p[0] * freq), Math.floor(p[1] * freq), Math.floor(p[2] * freq));
  return [v, v, v];
};

// ---------------------------------------------------------------------------
// Vajilla

/** Plato llano de diámetro D. Devuelve la altura de la superficie útil (fondo) y su radio. */
function plate(d, D, mat = 'ceramic') {
  const R = D / 2;
  const Rw = R * 0.64; // radio del fondo (pozo)
  const wellY = 0.011;
  const foot = R * 0.45;
  const prof = [
    [0, wellY],
    [Rw, wellY],
    [Rw + (R - Rw) * 0.3, wellY + 0.003],
    [R - 0.006, 0.0195],
    [R - 0.0015, 0.0215],
    [R, 0.0205],
    [R - 0.0015, 0.0185],
    [R - 0.008, 0.0155],
    [Rw + 0.008, 0.0065],
    [foot + 0.004, 0.005],
    [foot, 0.0, true],
    [foot - 0.006, 0.0, true],
    [foot - 0.008, 0.003],
    [0, 0.003],
  ];
  d.add(mat, lathe(prof, 64));
  return { y: wellY, r: Rw };
}

/** Bowl de diámetro D y alto H. Devuelve la función de altura interior y(r) y el radio interior r(y). */
function bowl(d, D, H, mat = 'ceramic', { footR = 0.05, base = 0.01, p = 2.4 } = {}) {
  const R = D / 2;
  const t = 0.0045; // espesor de pared
  const N = 16;
  const inner = [];
  for (let i = 0; i <= N; i++) {
    const s = i / N;
    inner.push([(R - t) * s, base + (H - base) * s ** p]);
  }
  const outer = [];
  for (let i = N; i >= 0; i--) {
    const s = i / N;
    const rr = footR + (R - footR) * s;
    outer.push([rr, 0.004 + (H - 0.006) * s ** (p * 0.95)]);
  }
  const prof = [
    ...inner.slice(0, -1),
    [R - t * 0.6, H + 0.0012],
    [R - t * 0.2, H + 0.0012],
    [R, H - 0.001],
    ...outer.slice(1),
    [footR, 0, true],
    [footR - 0.006, 0, true],
    [footR - 0.008, 0.003],
    [0, 0.003],
  ];
  d.add(mat, lathe(prof, 64));
  const yAt = (r) => profileY(inner, Math.min(r, R - t));
  const rAt = (y) => {
    for (let i = 0; i < inner.length - 1; i++) {
      if (y >= inner[i][1] && y <= inner[i + 1][1]) {
        const f = (y - inner[i][1]) / (inner[i + 1][1] - inner[i][1] || 1);
        return inner[i][0] + f * (inner[i + 1][0] - inner[i][0]);
      }
    }
    return R - t;
  };
  return { yAt, rAt, R, H };
}

/** Disco paramétrico (con suficientes vértices para colorFn) de radio r. */
function disc(r, bump = 0, seed = 3, nr = 10, na = 48) {
  const rr = rng(seed);
  const ph = rr() * 6;
  return paramSurface(nr, na, (u, v) => {
    const a = v * 2 * PI;
    const rad = u * r;
    const y = bump * Math.sin(a * 5 + ph) * Math.sin(u * 9) * u;
    return [rad * Math.cos(a), y, rad * Math.sin(a)];
  }, { normalFn: () => [0, 1, 0] });
}

// Montículo: altura de un domo parabólico en (x,z).
const mound = (x, z, cx, cz, R, H) => {
  const q = ((x - cx) ** 2 + (z - cz) ** 2) / (R * R);
  return q >= 1 ? 0 : H * (1 - q);
};

function herbs(d, n, cx, cz, R, yFn, size = 0.008) {
  for (let i = 0; i < n; i++) {
    const a = d.rand() * 2 * PI, rr = Math.sqrt(d.rand()) * R;
    const x = cx + rr * Math.cos(a), z = cz + rr * Math.sin(a);
    d.add('herb', leaf(size, size * 0.6, { seed: i + 11, nu: 3, nv: 3 }), { t: [x, yFn(x, z) + 0.001, z], r: [d.rand() * 0.6, d.rand() * 6.28, d.rand() * 0.6] }, { tint: d.jitter(0.25) });
  }
}

function riceDome(d, x, y, z, r, h) {
  const g = deform(dome(10, 28), (p) => {
    const n = 1 + 0.035 * (hashNoise(Math.round(p[0] * 40), Math.round(p[1] * 40), Math.round(p[2] * 40)) - 0.5);
    return [p[0] * n, p[1] * n, p[2] * n];
  });
  d.add('rice', g, { s: [r, h, r], t: [x, y, z] }, { colorFn: speckle(0.2, 45) });
}

function fry(d, x, y, z, ry, rz = 0, len = 0.07, th = 0.011) {
  d.add('fries', box(), { s: [len, th, th * d.rand.range(0.9, 1.1)], r: [d.rand.range(-0.2, 0.2), ry, rz], t: [x, y, z] }, {
    tint: d.jitter(0.12),
    colorFn: (p) => {
      const e = Math.abs(p[0]) * 2; // 0 centro, 1 extremos
      const v = 1 - 0.25 * e ** 3;
      return [v, v * 0.95, v * 0.85];
    },
  });
}


// ---------------------------------------------------------------------------
// Utilidades de composición
const rotY = (p, a) => [p[0] * Math.cos(a) + p[2] * Math.sin(a), p[1], -p[0] * Math.sin(a) + p[2] * Math.cos(a)];
const add3 = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
const polar = (rand, R, cx = 0, cz = 0) => {
  const a = rand() * 2 * PI, r = Math.sqrt(rand()) * R;
  return [cx + r * Math.cos(a), cz + r * Math.sin(a)];
};
const lumpy = (g, amt, freq = 30) =>
  deform(g, (p) => {
    const n = 1 + amt * (hashNoise(Math.round(p[0] * freq), Math.round(p[1] * freq), Math.round(p[2] * freq)) - 0.5);
    return [p[0] * n, p[1] * n, p[2] * n];
  });

/** Gajo/trozo de tomate: elipsoide con una cara plana. */
const tomatoWedge = () => deform(sphere(8, 12), (p) => [p[0], p[1], Math.max(p[2], -0.25)]);

// ---------------------------------------------------------------------------
// Platos

function ceviche() {
  const d = new Dish('ceviche', 101);
  const b = bowl(d, 0.24, 0.055, 'ceramic', { footR: 0.045, base: 0.009, p: 2.2 });
  const yl = 0.017; // nivel de la leche de tigre
  d.add('lecheTigre', disc(b.rAt(yl) - 0.0006, 0.0003, 7, 8, 64), { t: [0, yl, 0] });

  // Hoja de lechuga apoyada contra la pared
  d.add('lettuce', leaf(0.1, 0.085, { curl: 0.25, wave: 0.2, seed: 5, nu: 12, nv: 10 }), { r: [0, 0.35, 0.3], t: [-0.058, yl + 0.003, -0.012] });

  // Cubos de pescado en montículo
  const [mx, mz, MR, MH] = [0.01, 0.012, 0.062, 0.03];
  const top = (x, z) => yl + 0.006 + mound(x, z, mx, mz, MR, MH);
  for (let i = 0; i < 30; i++) {
    const [x, z] = polar(d.rand, MR * 0.95, mx, mz);
    const s = d.rand.range(0.015, 0.021);
    d.add('fish', box(), { s: [s, s * d.rand.range(0.8, 1), s * d.rand.range(0.85, 1.1)], r: [d.rand() * 0.8, d.rand() * 6.3, d.rand() * 0.8], t: [x, top(x, z) - s * 0.2, z] }, { tint: d.jitter(0.06) });
  }
  // Cebolla morada en tiras
  for (let i = 0; i < 16; i++) {
    const [x, z] = polar(d.rand, MR * 0.75, mx, mz);
    const purple = d.rand() < 0.75;
    d.add(purple ? 'onionRed' : 'onion', arcStrip(d.rand.range(0.012, 0.022), 0.0045, 0.0022, d.rand.range(1.3, 2.4), 10, 6), {
      r: [d.rand.range(-0.4, 0.4), d.rand() * 6.3, d.rand.range(-0.4, 0.4)],
      t: [x, top(x, z) + 0.008, z],
    }, { tint: d.jitter(0.1) });
  }
  // Choclo (trozo de mazorca acostado)
  {
    const c = [0.06, 0, -0.048];
    const len = 0.04, rc = 0.011, ang = 0.7;
    const cy = b.yAt(0.075) + rc + 0.006;
    d.add('cob', cylinder(20, 0.1), { s: [rc, len, rc], r: [0, ang, PI / 2], t: add3(c, add3(rotY([len / 2, 0, 0], ang), [0, cy, 0])) });
    for (let k = 0; k < 5; k++) {
      for (let j = 0; j < 14; j++) {
        const a = ((j + (k % 2) * 0.5) / 14) * 2 * PI;
        const local = [-len / 2 + ((k + 0.5) * len) / 5, Math.cos(a) * (rc + 0.0025), Math.sin(a) * (rc + 0.0025)];
        const w = rotY(local, ang);
        d.add('corn', sphere(4, 6), { s: [0.0042, 0.0045, 0.0045], r: [a, ang, 0], t: add3(c, add3(w, [0, cy, 0])) }, { tint: d.jitter(0.08) });
      }
    }
  }
  // Camote
  d.add('camote', cylinder(28, 0.3), { s: [0.026, 0.016, 0.023], r: [0.25, 0.4, -0.15], t: [-0.045, b.yAt(0.065) + 0.004, 0.058] }, { colorFn: speckle(0.08, 300) });
  // Ají limo picado y culantro
  for (let i = 0; i < 12; i++) {
    const [x, z] = polar(d.rand, MR * 0.6, mx, mz);
    d.add(d.rand() < 0.4 ? 'huancaina' : 'chili', box(), { s: [0.004, 0.003, 0.004], r: [d.rand(), d.rand() * 3, 0], t: [x, top(x, z) + 0.011, z] });
  }
  herbs(d, 18, mx, mz, MR * 0.7, (x, z) => top(x, z) + 0.01, 0.009);
  return d;
}

function lomoSaltado() {
  const d = new Dish('lomo-saltado', 202);
  const p = plate(d, 0.28);
  const py = p.y;
  riceDome(d, -0.06, py, -0.05, 0.045, 0.042);
  // Jugo del saltado
  const [cx, cz, R, H] = [0.02, 0.025, 0.07, 0.03];
  d.add('beef', disc(0.075, 0.0004, 9), { t: [cx, py + 0.0006, cz] }, { tint: [0.9, 0.85, 0.85] });
  const top = (x, z) => py + 0.006 + mound(x, z, cx, cz, R, H);
  for (let i = 0; i < 22; i++) {
    const [x, z] = polar(d.rand, R * 0.9, cx, cz);
    d.add('beef', box(), { s: [d.rand.range(0.035, 0.05), 0.01, d.rand.range(0.012, 0.016)], r: [d.rand.range(-0.4, 0.4), d.rand() * 6.3, d.rand.range(-0.3, 0.3)], t: [x, top(x, z) * d.rand.range(0.85, 1), z] }, {
      tint: d.jitter(0.15),
      colorFn: (q) => { const v = 1 - 0.3 * Math.min(1, Math.abs(q[0]) * 2) ** 4; return [v, v, v]; },
    });
  }
  for (let i = 0; i < 7; i++) {
    const [x, z] = polar(d.rand, R * 0.8, cx, cz);
    d.add('tomato', tomatoWedge(), { s: [0.016, 0.011, 0.0095], r: [d.rand.range(-0.5, 0.5), d.rand() * 6.3, d.rand.range(-0.3, 0.3)], t: [x, top(x, z) + 0.006, z] }, { tint: d.jitter(0.1) });
  }
  for (let i = 0; i < 12; i++) {
    const [x, z] = polar(d.rand, R * 0.85, cx, cz);
    d.add('onion', arcStrip(d.rand.range(0.015, 0.025), 0.008, 0.003, d.rand.range(1.0, 1.9), 10, 6), { r: [d.rand.range(-0.5, 0.5), d.rand() * 6.3, d.rand.range(-0.5, 0.5)], t: [x, top(x, z) + 0.005, z] }, { tint: d.jitter(0.12) });
  }
  // Papas fritas
  for (let i = 0; i < 18; i++) {
    const layer = Math.floor(i / 7);
    const x = d.rand.range(-0.1, -0.02), z = d.rand.range(0.03, 0.08);
    fry(d, x, py + 0.0055 + layer * 0.01, z, d.rand.range(-0.6, 0.9), d.rand.range(-0.1, 0.1));
  }
  herbs(d, 16, cx, cz, R * 0.7, (x, z) => top(x, z) + 0.008);
  return d;
}

function ajiDeGallina() {
  const d = new Dish('aji-de-gallina', 303);
  const p = plate(d, 0.27);
  const py = p.y;
  riceDome(d, -0.055, py, -0.045, 0.042, 0.04);
  const [cx, cz] = [0.03, 0.015];
  const cream = lumpy(dome(12, 36), 0.12, 14);
  d.add('ajiCream', cream, { s: [0.07, 0.033, 0.062], t: [cx, py, cz] }, { colorFn: speckle(0.14, 250) });
  // Papas sancochadas
  d.add('potato', dome(8, 20), { s: [0.026, 0.024, 0.032], r: [0, 0.5, 0], t: [-0.072, py, 0.04] }, { colorFn: speckle(0.06, 200) });
  d.add('potato', dome(8, 20), { s: [0.025, 0.022, 0.03], r: [0, -0.3, 0], t: [-0.025, py, 0.078] }, { colorFn: speckle(0.06, 200) });
  // Medio huevo duro sobre la crema
  const ex = cx + 0.012, ez = cz - 0.005;
  const eTop = py + 0.033 + 0.014;
  d.add('eggWhite', dome(8, 20), { s: [0.016, 0.014, 0.025], r: [PI, 0.6, 0], t: [ex, eTop, ez] });
  d.add('yolk', dome(6, 16), { s: [0.0095, 0.004, 0.0105], r: [0, 0.6, 0], t: [ex, eTop - 0.0005, ez] });
  // Aceituna(s)
  d.add('olive', sphere(8, 12), { s: [0.009, 0.008, 0.012], r: [0.3, 1.2, 0], t: [cx - 0.022, py + 0.033, cz + 0.02] });
  d.add('olive', sphere(8, 12), { s: [0.009, 0.008, 0.012], r: [0.2, -0.5, 0], t: [-0.06, py + 0.024 + 0.006, 0.04] });
  herbs(d, 10, cx, cz, 0.04, (x, z) => py + 0.03 + mound(x, z, cx, cz, 0.07, 0.003), 0.007);
  return d;
}

function causa() {
  const d = new Dish('causa', 404);
  const p = plate(d, 0.22);
  let y = p.y;
  const R = 0.04;
  d.add('causa', cylinder(40, 0.12), { s: [R, 0.022, R], t: [0, y, 0] }, { colorFn: speckle(0.06, 400) });
  y += 0.022;
  d.add('chicken', cylinder(40, 0), { s: [R - 0.0008, 0.009, R - 0.0008], t: [0, y, 0] }, { colorFn: speckle(0.15, 250) });
  y += 0.009;
  d.add('avocado', cylinder(40, 0), { s: [R - 0.0008, 0.006, R - 0.0008], t: [0, y, 0] });
  y += 0.006;
  d.add('causa', cylinder(40, 0.18), { s: [R, 0.022, R], t: [0, y, 0] }, { colorFn: speckle(0.06, 400) });
  y += 0.022;
  // Cobertura: mayonesa, huevo, aceituna, perejil
  d.add('mayo', lumpy(dome(8, 24), 0.1, 12), { s: [0.024, 0.007, 0.024], t: [0, y - 0.001, 0] });
  d.add('eggWhite', cylinder(20, 0.3), { s: [0.012, 0.004, 0.016], r: [0.15, 0.4, 0], t: [0.009, y + 0.005, -0.006] });
  d.add('yolk', cylinder(16, 0.2), { s: [0.0065, 0.0042, 0.0065], r: [0.15, 0.4, 0], t: [0.009, y + 0.0052, -0.006] });
  d.add('olive', sphere(8, 12), { s: [0.008, 0.007, 0.011], r: [0, 0.9, 0], t: [-0.011, y + 0.009, 0.009] });
  herbs(d, 5, 0, 0, 0.015, () => y + 0.008, 0.008);
  // Puntos de salsa huancaína y palta en el plato
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * 2 * PI + 0.2;
    const r = 0.06;
    d.add(i % 2 ? 'huancaina' : 'avocado', dome(6, 14), { s: [0.006, 0.0035, 0.006], t: [r * Math.cos(a), p.y, r * Math.sin(a)] });
  }
  return d;
}

function hamburguesa() {
  const d = new Dish('hamburguesa', 505);
  const bh = 0.018;
  d.add('wood', extrude(roundedRect(0.3, 0.2, 0.025, 6), bh), {}, { tint: [1, 1, 1] });
  // Vetas de madera: listones finos con ligera variación de tono
  for (let i = 0; i < 6; i++) {
    const z = -0.075 + i * 0.03;
    d.add('wood', box(), { s: [0.26, 0.0006, 0.004], t: [0, bh + 0.0001, z + d.rand.range(-0.006, 0.006)] }, { tint: [0.78, 0.75, 0.72] });
  }
  const [bx, bz] = [-0.055, 0.0];
  let y = bh;
  d.add('bun', cylinder(36, 0.35), { s: [0.054, 0.02, 0.054], t: [bx, y, bz] });
  y += 0.02;
  // Lechuga ondulada
  d.add('lettuce', paramSurface(6, 48, (u, v) => {
    const a = v * 2 * PI, r = u * 0.062;
    return [r * Math.cos(a), 0.004 * Math.sin(a * 9) * u * u, r * Math.sin(a)];
  }), { t: [bx, y + 0.001, bz] });
  y += 0.004;
  d.add('patty', lumpy(cylinder(36, 0.3), 0.04, 12), { s: [0.057, 0.016, 0.057], t: [bx, y, bz] }, { colorFn: speckle(0.3, 300) });
  y += 0.016;
  // Queso derretido (lámina que cae en las esquinas)
  d.add('cheese', paramSurface(10, 10, (u, v) => {
    const x = (u - 0.5) * 0.1, z = (v - 0.5) * 0.1;
    const dd = Math.hypot(x, z);
    return [x, -0.35 * Math.max(0, dd - 0.045) * (1 + 6 * Math.max(0, dd - 0.045)), z];
  }, { normalFn: () => [0, 1, 0] }), { r: [0, PI / 4, 0], t: [bx, y + 0.0012, bz] });
  y += 0.0025;
  for (const [ox, oz] of [[-0.018, 0.012], [0.02, -0.01]]) {
    d.add('tomato', cylinder(28, 0.2), { s: [0.029, 0.006, 0.029], t: [bx + ox, y, bz + oz] }, { colorFn: (q) => (Math.hypot(q[0], q[2]) > 0.9 ? [0.8, 0.8, 0.8] : [1, 1, 1]) });
  }
  y += 0.006;
  d.add('bun', lumpy(dome(10, 36), 0.02, 8), { s: [0.057, 0.042, 0.057], t: [bx, y, bz] });
  for (let i = 0; i < 30; i++) {
    const th = Math.acos(d.rand.range(0.45, 1)), ph = d.rand() * 2 * PI;
    const q = [0.057 * Math.sin(th) * Math.cos(ph), 0.042 * Math.cos(th), 0.057 * Math.sin(th) * Math.sin(ph)];
    d.add('sesame', sphere(3, 6), { s: [0.0022, 0.0011, 0.0036], r: [Math.sin(ph) * th, -ph, -Math.cos(ph) * th], t: [bx + q[0], y + q[1] - 0.0002, bz + q[2]] }, { tint: d.jitter(0.1) });
  }
  // Papas fritas
  for (let i = 0; i < 22; i++) {
    const layer = Math.floor(i / 8);
    fry(d, d.rand.range(0.045, 0.1), bh + 0.0055 + layer * 0.0105, d.rand.range(-0.04, 0.07), d.rand.range(-1, 1) + PI / 2, d.rand.range(-0.08, 0.08), d.rand.range(0.06, 0.085), 0.01);
  }
  // Ramekin con kétchup
  const [kx, kz] = [0.11, -0.068];
  d.add('ceramic', lathe([[0, 0.006], [0.0185, 0.006], [0.0195, 0.008], [0.02, 0.024], [0.0215, 0.025], [0.0225, 0.024], [0.022, 0.001], [0.021, 0, true], [0, 0]], 32), { t: [kx, bh, kz] });
  d.add('ketchup', disc(0.0198, 0, 4, 4, 32), { t: [kx, bh + 0.02, kz] });
  return d;
}

function pizza() {
  const d = new Dish('pizza', 606);
  d.add('steel', lathe([[0, 0.003], [0.155, 0.003], [0.162, 0.0075], [0.1645, 0.0085], [0.1655, 0.0075], [0.159, 0.002], [0.155, 0, true], [0, 0]], 72));
  const y0 = 0.003;
  d.add('dough', cylinder(64, 0.2), { s: [0.14, 0.006, 0.14], t: [0, y0, 0] });
  const yc = y0 + 0.0062;
  d.add('pizzaCheese', disc(0.133, 0.0007, 12, 16, 96), { t: [0, yc, 0] }, {
    colorFn: (q) => {
      const r = Math.hypot(q[0], q[2]);
      if (r > 0.124) return [0.86, 0.36, 0.26]; // salsa visible en el borde
      const n = hashNoise(Math.floor(q[0] * 90), 0, Math.floor(q[2] * 90));
      return n > 0.82 ? [0.82, 0.72, 0.6] : [1, 1, 1];
    },
  });
  d.add('crust', arcStrip(0.137, 0.022, 0.018, 2 * PI, 96, 10), { t: [0, y0 + 0.0085, 0] }, {
    colorFn: (q) => {
      const n = hashNoise(Math.floor(q[0] * 150), Math.floor(q[1] * 150), Math.floor(q[2] * 150));
      const top = q[1] > 0.004 ? 0.85 : 1;
      const v = top * (1 - 0.15 * n);
      return [v, v * 0.97, v * 0.93];
    },
  });
  const placed = [];
  let tries = 0;
  while (placed.length < 17 && tries++ < 2000) {
    const [x, z] = polar(d.rand, 0.11);
    if (placed.some(([a, b]) => Math.hypot(a - x, b - z) < 0.036)) continue;
    placed.push([x, z]);
    d.add('pepperoni', cylinder(20, 0.3), { s: [0.016, 0.0032, 0.016], r: [d.rand.range(-0.05, 0.05), 0, d.rand.range(-0.05, 0.05)], t: [x, yc - 0.0004, z] }, { tint: d.jitter(0.12), colorFn: speckle(0.2, 400) });
  }
  for (let i = 0; i < 12; i++) {
    const [x, z] = polar(d.rand, 0.115);
    if (placed.some(([a, b]) => Math.hypot(a - x, b - z) < 0.02)) continue;
    d.add('olive', arcStrip(0.0045, 0.004, 0.004, 2 * PI, 12, 6), { t: [x, yc + 0.0015, z] });
  }
  for (let i = 0; i < 6; i++) {
    const [x, z] = polar(d.rand, 0.09);
    d.add('lettuce', leaf(0.028, 0.017, { seed: 70 + i, curl: 0.15, nu: 6, nv: 6 }), { r: [0, d.rand() * 6.3, 0], t: [x, yc + 0.0035, z] }, { tint: [0.55, 0.75, 0.55] });
  }
  return d;
}

function ensalada() {
  const d = new Dish('ensalada', 707);
  const b = bowl(d, 0.22, 0.075, 'ceramicCream', { footR: 0.045, base: 0.01, p: 2.0 });
  const hTop = (r) => 0.074 + 0.022 * (1 - Math.min(1, (r / 0.09) ** 2));
  const surf = (x, z) => hTop(Math.hypot(x, z));
  for (let i = 0; i < 55; i++) {
    const [x, z] = polar(d.rand, 0.068);
    const r = Math.hypot(x, z);
    const y = b.yAt(r) + (hTop(r) - b.yAt(r)) * d.rand.range(0.45, 0.95);
    const L = d.rand.range(0.05, 0.075);
    const g = [d.rand.range(0.75, 1.15), d.rand.range(0.8, 1.2), d.rand.range(0.7, 1.1)];
    d.add('lettuce', leaf(L, L * d.rand.range(0.55, 0.75), { seed: 200 + i, curl: d.rand.range(0.2, 0.5), wave: 0.15, nu: 7, nv: 7 }), { r: [d.rand.range(-0.7, 0.7), d.rand() * 6.3, d.rand.range(-0.7, 0.7)], t: [x, y, z] }, { tint: g });
  }
  for (let i = 0; i < 8; i++) {
    const [x, z] = polar(d.rand, 0.06);
    d.add('tomato', sphere(10, 14), { s: 0.0115, t: [x, surf(x, z) + 0.004, z] }, { tint: d.jitter(0.1) });
  }
  for (let i = 0; i < 7; i++) {
    const [x, z] = polar(d.rand, 0.06);
    d.add('cucumber', cylinder(20, 0.1), { s: [0.015, 0.004, 0.015], r: [d.rand.range(-0.4, 0.4), 0, d.rand.range(-0.4, 0.4)], t: [x, surf(x, z), z] }, { colorFn: (q) => (Math.hypot(q[0], q[2]) > 0.85 ? [0.45, 0.6, 0.4] : [1.1, 1.1, 1.1]) });
  }
  for (let i = 0; i < 8; i++) {
    const [x, z] = polar(d.rand, 0.055);
    const s = d.rand.range(0.011, 0.014);
    d.add('queso', box(), { s, r: [d.rand(), d.rand() * 3, d.rand()], t: [x, surf(x, z) + 0.002, z] });
  }
  for (let i = 0; i < 16; i++) {
    const [x, z] = polar(d.rand, 0.06);
    d.add('carrot', box(), { s: [0.03, 0.0022, 0.0022], r: [d.rand() * 0.5, d.rand() * 6.3, d.rand() * 0.5], t: [x, surf(x, z) + 0.003, z] }, { tint: d.jitter(0.08) });
  }
  for (let i = 0; i < 16; i++) {
    const [x, z] = polar(d.rand, 0.06);
    d.add('corn', sphere(4, 6), { s: [0.004, 0.0035, 0.0045], r: [d.rand(), d.rand() * 3, 0], t: [x, surf(x, z) + 0.003, z] }, { tint: d.jitter(0.1) });
  }
  return d;
}

function postre() {
  const d = new Dish('postre', 808);
  const p = plate(d, 0.18);
  const R = 0.095, half = (20 * PI) / 180;
  const poly = [[0, 0]];
  for (let i = 0; i <= 10; i++) {
    const a = -half + (2 * half * i) / 10;
    poly.push([R * Math.cos(a), R * Math.sin(a)]);
  }
  const shift = -R * 0.55;
  const ang = 2.2; // giro para que la punta mire hacia delante
  const C = [0, 0, 0.005];
  const layers = [['sponge', 0.018], ['manjar', 0.005], ['sponge', 0.018], ['cream', 0.006], ['manjar', 0.003]];
  let y = p.y;
  const shifted = poly.map(([x, z]) => [x + shift, z]);
  for (const [mat, h] of layers) {
    d.add(mat, extrude(shifted, h), { r: [0, ang, 0], t: [C[0], y, C[2]] }, mat === 'sponge' ? { colorFn: speckle(0.08, 500) } : {});
    y += h;
  }
  // Decoración sobre la tajada (en coordenadas locales de la tajada)
  const onSlice = (lx, lz, dy = 0) => add3(rotY([lx + shift, 0, lz], ang), [C[0], y + dy, C[2]]);
  d.add('cream', lathe([[0, 0.022], [0.004, 0.018], [0.0085, 0.011], [0.011, 0.004], [0.011, 0, true], [0, 0]], 10), { t: onSlice(R * 0.75, 0, -0.0005) });
  d.add('strawberry', lathe([[0, 0.022], [0.006, 0.019], [0.0095, 0.012], [0.0085, 0.005], [0.0045, 0.001], [0, 0]], 16), { r: [0.35, 0, 0], t: onSlice(R * 0.75, 0, 0.018) }, { colorFn: speckle(0.25, 900) });
  d.add('lettuce', leaf(0.016, 0.01, { seed: 9, nu: 4, nv: 4 }), { r: [0.4, 1, 0], t: onSlice(R * 0.72, 0.008, 0.026) }, { tint: [0.6, 0.85, 0.6] });
  // Hilos y puntos de chocolate en el plato
  for (let i = 0; i < 3; i++) {
    d.add('chocolate', arcStrip(0.05 + i * 0.006, 0.0026, 0.0012, 1.3, 20, 6), { r: [0, 3.6 + i * 0.25, 0], t: [0, p.y + 0.0005, 0] });
  }
  for (let i = 0; i < 6; i++) {
    const a = 0.8 + i * 0.32;
    d.add('chocolate', dome(5, 12), { s: [0.004, 0.0022, 0.004], t: [0.052 * Math.cos(a), p.y, 0.052 * Math.sin(a)] });
  }
  return d;
}

function bebida() {
  const d = new Dish('bebida', 909);
  const innerR = (y) => 0.031 + ((0.037 - 0.031) * (y - 0.0095)) / (0.149 - 0.0095);
  d.add('glass', lathe([
    [0, 0.008], [0.0302, 0.008], [0.031, 0.0095], [0.037, 0.149],
    [0.0378, 0.1503], [0.0392, 0.1503], [0.04, 0.149],
    [0.0342, 0.0015], [0.0335, 0, true], [0, 0],
  ], 48));
  const lvl = 0.118;
  d.add('chicha', lathe([[0, lvl], [innerR(lvl) - 0.0004, lvl, true], [innerR(0.0095) - 0.0004, 0.0095, true], [0, 0.0095]], 48));
  for (let i = 0; i < 3; i++) {
    const a = (i / 3) * 2 * PI + 0.4;
    d.add('ice', box(), { s: 0.019, r: [0.3 + i * 0.4, a, 0.2], t: [0.012 * Math.cos(a), lvl + 0.002, 0.012 * Math.sin(a)] });
  }
  for (let i = 0; i < 3; i++) {
    const a = (i / 3) * 2 * PI + 1.4;
    d.add('pineapple', box(), { s: [0.01, 0.008, 0.01], r: [0.2, a, 0.3], t: [0.02 * Math.cos(a), lvl - 0.001, 0.02 * Math.sin(a)] });
  }
  // Rodaja de limón en el borde
  d.add('lemonPulp', cylinder(28, 0.15), { s: [0.017, 0.005, 0.017], r: [PI / 2, 0, 0], t: [0.037, 0.142, 0.0025] }, {
    colorFn: (q) => (Math.hypot(q[0], q[2]) > 0.86 ? [0.62, 0.82, 0.32] : [1, 1, 1]),
  });
  // Sorbete
  d.add('strawRed', cylinder(12), { s: [0.0032, 0.2, 0.0032], r: [0.12, 0, 0.22], t: [-0.004, 0.01, -0.006] });
  return d;
}

function generico() {
  const d = new Dish('generico', 1010);
  const p = plate(d, 0.27);
  const py = p.y;
  const prof = [];
  const R = 0.112, H = 0.088;
  for (let i = 0; i <= 14; i++) {
    const ph = (i / 14) * (PI / 2);
    prof.push([R * Math.sin(ph), py + 0.006 + H * Math.cos(ph) ** 0.9]);
  }
  prof[0][0] = 0;
  prof.push([0.117, py + 0.005], [0.118, py + 0.0005, true], [0.11, py + 0.0005, true]);
  for (let i = 14; i >= 0; i--) {
    const ph = (i / 14) * (PI / 2);
    prof.push([(R - 0.002) * Math.sin(ph), py + 0.006 + (H - 0.002) * Math.cos(ph) ** 0.9]);
  }
  prof[prof.length - 1][0] = 0;
  d.add('steel', lathe(prof, 64));
  const yTop = py + 0.006 + H;
  d.add('steel', cylinder(16), { s: [0.005, 0.012, 0.005], t: [0, yTop - 0.002, 0] });
  d.add('steel', sphere(10, 16), { s: [0.013, 0.009, 0.013], t: [0, yTop + 0.016, 0] });
  // Ramita de perejil en el borde del plato
  herbs(d, 4, 0.0, 0.122, 0.006, () => 0.021, 0.012);
  return d;
}

export const DISHES = [
  { id: 'ceviche', name: 'Cebiche clásico', category: 'Ceviches', build: ceviche },
  { id: 'lomo-saltado', name: 'Lomo saltado', category: 'Fondos', build: lomoSaltado },
  { id: 'aji-de-gallina', name: 'Ají de gallina', category: 'Criollos', build: ajiDeGallina },
  { id: 'causa', name: 'Causa limeña', category: 'Entradas', build: causa },
  { id: 'hamburguesa', name: 'Hamburguesa con papas', category: 'Hamburguesas', build: hamburguesa },
  { id: 'pizza', name: 'Pizza pepperoni', category: 'Pizzas', build: pizza },
  { id: 'ensalada', name: 'Ensalada fresca', category: 'Ensaladas', build: ensalada },
  { id: 'postre', name: 'Tajada de torta', category: 'Postres', build: postre },
  { id: 'bebida', name: 'Chicha morada', category: 'Bebidas', build: bebida },
  { id: 'generico', name: 'Plato genérico', category: null, build: generico },
];
