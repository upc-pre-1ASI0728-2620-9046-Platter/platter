// Genera la biblioteca 3D de Platter:
//   backend/src/main/resources/library/models/{id}.glb
//   backend/src/main/resources/library/models.json
// Uso: npm run build            (con compresión Draco)
//      npm run build -- --no-draco
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Document, NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { dedup, prune, draco } from '@gltf-transform/functions';
import draco3d from 'draco3dgltf';
import { DISHES, MATERIALS } from './dishes.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '../../..');
const outDir = path.join(repoRoot, 'backend/src/main/resources/library');
const modelsDir = path.join(outDir, 'models');
const useDraco = !process.argv.includes('--no-draco');

const srgbToLinear = (c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);

function bbox(parts) {
  const min = [Infinity, Infinity, Infinity], max = [-Infinity, -Infinity, -Infinity];
  for (const list of parts.values()) {
    for (const g of list) {
      for (let i = 0; i < g.positions.length; i += 3) {
        for (let k = 0; k < 3; k++) {
          min[k] = Math.min(min[k], g.positions[i + k]);
          max[k] = Math.max(max[k], g.positions[i + k]);
        }
      }
    }
  }
  return { min, max };
}

function buildDocument(dish, meta) {
  // Recentrar: centro XZ en el origen y base apoyada en y = 0.
  const { min, max } = bbox(dish.parts);
  const off = [-(min[0] + max[0]) / 2, -min[1], -(min[2] + max[2]) / 2];
  const dims = {
    widthM: +(max[0] - min[0]).toFixed(3),
    depthM: +(max[2] - min[2]).toFixed(3),
    heightM: +(max[1] - min[1]).toFixed(3),
  };

  const doc = new Document();
  doc.getRoot().getAsset().generator = 'Platter model-generator 1.0 (glTF-Transform)';
  const buffer = doc.createBuffer();
  const mesh = doc.createMesh(dish.id);

  for (const [matName, list] of dish.parts) {
    const def = MATERIALS[matName];
    const mat = doc
      .createMaterial(matName)
      .setBaseColorFactor([...def.c.map(srgbToLinear), def.a ?? 1])
      .setRoughnessFactor(def.r ?? 0.5)
      .setMetallicFactor(def.m ?? 0)
      .setDoubleSided(!!def.ds);
    if (def.blend) mat.setAlphaMode('BLEND');

    const nV = list.reduce((s, g) => s + g.positions.length / 3, 0);
    const P = new Float32Array(nV * 3), N = new Float32Array(nV * 3), C = new Float32Array(nV * 3);
    const nI = list.reduce((s, g) => s + g.indices.length, 0);
    const I = nV > 65535 ? new Uint32Array(nI) : new Uint16Array(nI);
    let vo = 0, io = 0;
    for (const g of list) {
      const n = g.positions.length / 3;
      for (let v = 0; v < n; v++) {
        for (let k = 0; k < 3; k++) {
          P[(vo + v) * 3 + k] = g.positions[v * 3 + k] + off[k];
          N[(vo + v) * 3 + k] = g.normals[v * 3 + k];
          C[(vo + v) * 3 + k] = srgbToLinear(g.colors[v * 3 + k]);
        }
      }
      for (let i = 0; i < g.indices.length; i++) I[io + i] = g.indices[i] + vo;
      vo += n;
      io += g.indices.length;
    }
    const prim = doc
      .createPrimitive()
      .setMaterial(mat)
      .setIndices(doc.createAccessor().setType('SCALAR').setArray(I).setBuffer(buffer))
      .setAttribute('POSITION', doc.createAccessor().setType('VEC3').setArray(P).setBuffer(buffer))
      .setAttribute('NORMAL', doc.createAccessor().setType('VEC3').setArray(N).setBuffer(buffer))
      .setAttribute('COLOR_0', doc.createAccessor().setType('VEC3').setArray(C).setBuffer(buffer));
    mesh.addPrimitive(prim);
  }
  const node = doc.createNode(dish.id).setMesh(mesh);
  const scene = doc.createScene(meta.name).addChild(node);
  scene.setExtras({ platter: { id: meta.id, name: meta.name, units: 'meters', dimensions: dims } });
  doc.getRoot().setDefaultScene(scene);
  return { doc, dims };
}

async function main() {
  await mkdir(modelsDir, { recursive: true });
  const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
  if (useDraco) {
    io.registerDependencies({
      'draco3d.encoder': await draco3d.createEncoderModule(),
      'draco3d.decoder': await draco3d.createDecoderModule(),
    });
  }
  const catalog = [];
  for (const meta of DISHES) {
    const dish = meta.build();
    const { doc, dims } = buildDocument(dish, meta);
    const transforms = [dedup(), prune()];
    if (useDraco) {
      transforms.push(draco({ method: 'edgebreaker', quantizePosition: 14, quantizeNormal: 10, quantizeColor: 8 }));
    }
    await doc.transform(...transforms);
    const glb = await io.writeBinary(doc);
    const file = path.join(modelsDir, `${meta.id}.glb`);
    await writeFile(file, glb);
    const tris = doc.getRoot().listMeshes().flatMap((m) => m.listPrimitives()).reduce((s, p) => s + (p.getIndices()?.getCount() ?? 0) / 3, 0);
    catalog.push({ id: meta.id, name: meta.name, category: meta.category, dimensions: dims });
    console.log(`${meta.id.padEnd(16)} ${(glb.byteLength / 1024).toFixed(1).padStart(7)} KB  ${String(tris).padStart(6)} tris  ` +
      `${(dims.widthM * 100).toFixed(1)} × ${(dims.depthM * 100).toFixed(1)} × ${(dims.heightM * 100).toFixed(1)} cm`);
  }
  await writeFile(path.join(outDir, 'models.json'), JSON.stringify(catalog, null, 2) + '\n');
  console.log(`\n${catalog.length} modelos → ${path.relative(repoRoot, modelsDir)} (Draco: ${useDraco ? 'sí' : 'no'})`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
