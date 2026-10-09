// Geometría procedimental mínima (sin dependencias).
// Convenciones: 1 unidad = 1 metro, eje Y hacia arriba.
// Una "geometría" es { positions: number[], normals: number[], indices: number[], colors?: number[] }.

// ---------------------------------------------------------------------------
// RNG determinista (mulberry32) para que la salida sea reproducible.
export function rng(seed) {
  let a = seed >>> 0;
  const next = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  next.range = (min, max) => min + (max - min) * next();
  next.pick = (arr) => arr[Math.floor(next() * arr.length)];
  next.sign = () => (next() < 0.5 ? -1 : 1);
  return next;
}

// ---------------------------------------------------------------------------
// Vectores
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const norm = (a) => {
  const l = Math.hypot(a[0], a[1], a[2]) || 1;
  return [a[0] / l, a[1] / l, a[2] / l];
};

function emptyGeom() {
  return { positions: [], normals: [], indices: [] };
}
function pos(g, i) {
  return [g.positions[3 * i], g.positions[3 * i + 1], g.positions[3 * i + 2]];
}
function pushV(g, p, n = [0, 1, 0]) {
  g.positions.push(p[0], p[1], p[2]);
  g.normals.push(n[0], n[1], n[2]);
  return g.positions.length / 3 - 1;
}
/** Añade un triángulo; si se indica `expected`, corrige el orden para que la cara apunte hacia allí. */
function tri(g, a, b, c, expected) {
  if (expected) {
    const n = cross(sub(pos(g, b), pos(g, a)), sub(pos(g, c), pos(g, a)));
    if (dot(n, expected) < 0) {
      g.indices.push(a, c, b);
      return;
    }
  }
  g.indices.push(a, b, c);
}

/** Normales suaves ponderadas por área (por índice de vértice). */
export function computeNormals(g) {
  const n = new Float64Array(g.positions.length);
  for (let i = 0; i < g.indices.length; i += 3) {
    const [a, b, c] = [g.indices[i], g.indices[i + 1], g.indices[i + 2]];
    const fn = cross(sub(pos(g, b), pos(g, a)), sub(pos(g, c), pos(g, a)));
    for (const v of [a, b, c]) {
      n[3 * v] += fn[0];
      n[3 * v + 1] += fn[1];
      n[3 * v + 2] += fn[2];
    }
  }
  for (let v = 0; v < n.length / 3; v++) {
    const nn = norm([n[3 * v], n[3 * v + 1], n[3 * v + 2]]);
    g.normals[3 * v] = nn[0];
    g.normals[3 * v + 1] = nn[1];
    g.normals[3 * v + 2] = nn[2];
  }
  return g;
}

// ---------------------------------------------------------------------------
// Primitivas

/**
 * Torno: revoluciona un perfil [[r, y, sharp?], ...] alrededor del eje Y.
 * El perfil debe recorrerse de modo que la cara "exterior" quede a la izquierda
 * (p. ej. superficie superior: del centro hacia afuera). Los puntos con `sharp`
 * generan una arista viva (anillo duplicado).
 */
export function lathe(profile, segments = 48) {
  const g = emptyGeom();
  const ring = (r, y) => {
    const start = g.positions.length / 3;
    for (let j = 0; j < segments; j++) {
      const t = (j / segments) * Math.PI * 2;
      pushV(g, [r * Math.cos(t), y, r * Math.sin(t)]);
    }
    return { start, r };
  };
  const rings = [];
  let prevOut = null;
  const connect = (A, B) => {
    for (let j = 0; j < segments; j++) {
      const j1 = (j + 1) % segments;
      const a = A.start + j, b = B.start + j, c = B.start + j1, d = A.start + j1;
      // Orden (a, c, b) / (a, d, c) => normal a la izquierda del sentido del perfil.
      if (B.r > 1e-9 || A.r > 1e-9) {
        g.indices.push(a, c, b, a, d, c);
      }
    }
  };
  profile.forEach(([r, y, sharp], i) => {
    const rin = ring(r, y);
    rings.push(rin);
    if (prevOut) connect(prevOut, rin);
    if (sharp && i > 0 && i < profile.length - 1) {
      const rout = ring(r, y);
      rings.push(rout);
      prevOut = rout;
    } else prevOut = rin;
  });
  computeNormals(g);
  // Polos (r = 0): normal promedio del anillo, para evitar artefactos.
  for (const R of rings) {
    if (R.r > 1e-9) continue;
    let s = [0, 0, 0];
    for (let j = 0; j < segments; j++) {
      s = [s[0] + g.normals[3 * (R.start + j)], s[1] + g.normals[3 * (R.start + j) + 1], s[2] + g.normals[3 * (R.start + j) + 2]];
    }
    s = norm(s);
    for (let j = 0; j < segments; j++) g.normals.splice(3 * (R.start + j), 3, s[0], s[1], s[2]);
  }
  return g;
}

/** Esfera unitaria (radio 1) — usar escala para elipsoides. */
export function sphere(rings = 12, segments = 16) {
  const prof = [];
  for (let i = 0; i <= rings; i++) {
    const phi = (i / rings) * Math.PI;
    prof.push([Math.sin(phi), Math.cos(phi)]);
  }
  prof[0][0] = 0;
  prof[rings][0] = 0;
  return lathe(prof, segments);
}

/** Semiesfera (cúpula) de radio 1 apoyada en y=0, con base cerrada. */
export function dome(rings = 8, segments = 20) {
  const prof = [];
  for (let i = 0; i <= rings; i++) {
    const phi = (i / rings) * (Math.PI / 2);
    prof.push([Math.sin(phi), Math.cos(phi)]);
  }
  prof[0][0] = 0;
  prof[rings].push(true);
  prof.push([0, 0]);
  return lathe(prof, segments);
}

/** Cilindro de radio 1 y altura 1 (y de 0 a 1), con bisel opcional. */
export function cylinder(segments = 24, bevel = 0) {
  if (bevel <= 0) return lathe([[0, 1], [1, 1, true], [1, 0, true], [0, 0]], segments);
  const b = bevel;
  return lathe([[0, 1], [1 - b, 1], [1 - b * 0.3, 1 - b * 0.3], [1, 1 - b], [1, b], [1 - b * 0.3, b * 0.3], [1 - b, 0], [0, 0]], segments);
}

/** Caja centrada en el origen de tamaño 1×1×1 (normales planas). */
export function box() {
  const g = emptyGeom();
  const faces = [
    [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
    [[-1, 0, 0], [0, 1, 0], [0, 0, 1]],
    [[0, 1, 0], [1, 0, 0], [0, 0, 1]],
    [[0, -1, 0], [1, 0, 0], [0, 0, 1]],
    [[0, 0, 1], [1, 0, 0], [0, 1, 0]],
    [[0, 0, -1], [1, 0, 0], [0, 1, 0]],
  ];
  for (const [n, u, v] of faces) {
    const c = n.map((x) => x * 0.5);
    const corners = [[-1, -1], [1, -1], [1, 1], [-1, 1]].map(([a, b]) =>
      pushV(g, [c[0] + (u[0] * a + v[0] * b) * 0.5, c[1] + (u[1] * a + v[1] * b) * 0.5, c[2] + (u[2] * a + v[2] * b) * 0.5], n),
    );
    tri(g, corners[0], corners[1], corners[2], n);
    tri(g, corners[0], corners[2], corners[3], n);
  }
  return g;
}

/**
 * Extruye un polígono (convexo o estrellado respecto de su centroide) dado en el plano XZ,
 * desde y=0 hasta y=height. Las aristas con ángulo > `smoothAngle` quedan vivas.
 */
export function extrude(poly, height, smoothAngleDeg = 35) {
  const g = emptyGeom();
  const n = poly.length;
  const c = poly.reduce((s, p) => [s[0] + p[0] / n, s[1] + p[1] / n], [0, 0]);
  // Tapas
  for (const [y, up] of [[height, [0, 1, 0]], [0, [0, -1, 0]]]) {
    const ci = pushV(g, [c[0], y, c[1]], up);
    const idx = poly.map((p) => pushV(g, [p[0], y, p[1]], up));
    for (let k = 0; k < n; k++) tri(g, ci, idx[k], idx[(k + 1) % n], up);
  }
  // Lados
  const edgeN = [];
  for (let k = 0; k < n; k++) {
    const a = poly[k], b = poly[(k + 1) % n];
    let en = norm([b[1] - a[1], 0, -(b[0] - a[0])]);
    const mid = [(a[0] + b[0]) / 2 - c[0], 0, (a[1] + b[1]) / 2 - c[1]];
    if (dot(en, mid) < 0) en = en.map((x) => -x);
    edgeN.push(en);
  }
  const cosT = Math.cos((smoothAngleDeg * Math.PI) / 180);
  for (let k = 0; k < n; k++) {
    const a = poly[k], b = poly[(k + 1) % n];
    const prevN = edgeN[(k - 1 + n) % n], nextN = edgeN[(k + 1) % n];
    const blend = (o) => (dot(edgeN[k], o) > cosT ? norm([edgeN[k][0] + o[0], 0, edgeN[k][2] + o[2]]) : edgeN[k]);
    const naFix = blend(prevN);
    const nbFix = blend(nextN);
    const v0 = pushV(g, [a[0], 0, a[1]], naFix);
    const v1 = pushV(g, [b[0], 0, b[1]], nbFix);
    const v2 = pushV(g, [b[0], height, b[1]], nbFix);
    const v3 = pushV(g, [a[0], height, a[1]], naFix);
    tri(g, v0, v1, v2, edgeN[k]);
    tri(g, v0, v2, v3, edgeN[k]);
  }
  return g;
}

/** Rectángulo redondeado (polígono XZ) centrado en el origen. */
export function roundedRect(w, d, r, seg = 6) {
  const pts = [];
  const cs = [[w / 2 - r, d / 2 - r, 0], [-w / 2 + r, d / 2 - r, 90], [-w / 2 + r, -d / 2 + r, 180], [w / 2 - r, -d / 2 + r, 270]];
  for (const [cx, cz, a0] of cs) {
    for (let i = 0; i <= seg; i++) {
      const a = ((a0 + (90 * i) / seg) * Math.PI) / 180;
      pts.push([cx + r * Math.cos(a), cz + r * Math.sin(a)]);
    }
  }
  return pts;
}

/**
 * Superficie paramétrica fn(u, v) → [x,y,z] con u,v ∈ [0,1].
 * `normalFn(u, v)` (opcional) indica hacia dónde debe mirar la cara.
 */
export function paramSurface(nu, nv, fn, { closeU = false, closeV = false, normalFn } = {}) {
  const g = emptyGeom();
  const cu = closeU ? nu : nu + 1;
  const cv = closeV ? nv : nv + 1;
  for (let i = 0; i < cu; i++) for (let j = 0; j < cv; j++) pushV(g, fn(i / nu, j / nv));
  const id = (i, j) => (i % cu) * cv + (j % cv);
  for (let i = 0; i < nu; i++) {
    for (let j = 0; j < nv; j++) {
      const a = id(i, j), b = id(i + 1, j), c = id(i + 1, j + 1), d = id(i, j + 1);
      const exp = normalFn ? normalFn((i + 0.5) / nu, (j + 0.5) / nv) : null;
      tri(g, a, b, c, exp);
      tri(g, a, c, d, exp);
    }
  }
  return computeNormals(g);
}

/** Arco tubular (p. ej. aros de cebolla): radio R, sección elíptica (w ancho radial, t espesor), apertura `span` rad. */
export function arcStrip(R, w, t, span, nu = 10, nv = 8) {
  const f = (u, v) => {
    const a = u * span, b = v * Math.PI * 2;
    const rr = R + (w / 2) * Math.cos(b);
    return [rr * Math.cos(a), (t / 2) * Math.sin(b), rr * Math.sin(a)];
  };
  return paramSurface(nu, nv, f, {
    closeV: true,
    normalFn: (u, v) => {
      const a = u * span, b = v * Math.PI * 2;
      return [Math.cos(b) * Math.cos(a), Math.sin(b), Math.cos(b) * Math.sin(a)];
    },
  });
}

/** Hoja ondulada (lechuga, albahaca...): largo L en Z, ancho W en X. Cara de doble lado. */
export function leaf(L, W, { curl = 0.3, wave = 0.15, seed = 1, nu = 10, nv = 8 } = {}) {
  const r = rng(seed);
  const ph = r() * 6.28, ph2 = r() * 6.28;
  return paramSurface(nu, nv, (u, v) => {
    const s = u * 2 - 1; // -1..1 a lo ancho
    const width = Math.sin(Math.PI * Math.min(1, v * 1.05 + 0.02)) ** 0.7 * (W / 2);
    const x = s * width;
    const z = (v - 0.5) * L;
    const y = curl * W * s * s + wave * W * Math.sin(s * 5 + ph) * Math.sin(v * 7 + ph2) * Math.abs(s) + 0.08 * L * Math.sin(Math.PI * v);
    return [x, y, z];
  });
}

// ---------------------------------------------------------------------------
// Transformaciones

function eulerMat([rx, ry, rz]) {
  const [cx, sx, cy, sy, cz, sz] = [Math.cos(rx), Math.sin(rx), Math.cos(ry), Math.sin(ry), Math.cos(rz), Math.sin(rz)];
  // R = Rz * Ry * Rx
  return [
    [cy * cz, cz * sy * sx - sz * cx, cz * sy * cx + sz * sx],
    [cy * sz, sz * sy * sx + cz * cx, sz * sy * cx - cz * sx],
    [-sy, cy * sx, cy * cx],
  ];
}
const mul = (m, v) => [dot(m[0], v), dot(m[1], v), dot(m[2], v)];

/** Copia transformada: escala → rotación (Euler XYZ, rad) → traslación. */
export function place(g, { s = [1, 1, 1], r = [0, 0, 0], t = [0, 0, 0] } = {}) {
  if (typeof s === 'number') s = [s, s, s];
  const m = eulerMat(r);
  const out = { positions: [], normals: [], indices: g.indices.slice() };
  for (let i = 0; i < g.positions.length; i += 3) {
    const p = mul(m, [g.positions[i] * s[0], g.positions[i + 1] * s[1], g.positions[i + 2] * s[2]]);
    out.positions.push(p[0] + t[0], p[1] + t[1], p[2] + t[2]);
    const n = norm(mul(m, [g.normals[i] / s[0], g.normals[i + 1] / s[1], g.normals[i + 2] / s[2]]));
    out.normals.push(n[0], n[1], n[2]);
  }
  if (g.colors) out.colors = g.colors.slice();
  // Escala negativa (espejo) => invertir orden de triángulos
  if (s[0] * s[1] * s[2] < 0) {
    for (let i = 0; i < out.indices.length; i += 3) {
      const tmp = out.indices[i + 1];
      out.indices[i + 1] = out.indices[i + 2];
      out.indices[i + 2] = tmp;
    }
  }
  return out;
}

/** Desplaza vértices con una función f(p) → p' (recalcula normales). */
export function deform(g, f) {
  const out = { positions: [], normals: g.normals.slice(), indices: g.indices.slice() };
  for (let i = 0; i < g.positions.length; i += 3) {
    const p = f([g.positions[i], g.positions[i + 1], g.positions[i + 2]]);
    out.positions.push(p[0], p[1], p[2]);
  }
  return computeNormals(out);
}

/** Interpola linealmente y(r) en un perfil [[r,y],...] con r creciente. */
export function profileY(pts, r) {
  for (let i = 0; i < pts.length - 1; i++) {
    const [r0, y0] = pts[i], [r1, y1] = pts[i + 1];
    if (r >= r0 && r <= r1) return y0 + ((y1 - y0) * (r - r0)) / (r1 - r0 || 1);
  }
  return pts[pts.length - 1][1];
}
