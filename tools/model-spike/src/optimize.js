// Normaliza un GLB generado por IA al formato de la biblioteca de Platter:
//   1. Escala real: el lado mayor de la huella (X/Z) = diámetro declarado del plato.
//   2. Centrado en X/Z y apoyado en y = 0 (como espera ar-placement="floor").
//   3. Peso apto para datos móviles: simplificación de malla, texturas ≤ 1024 px y compresión Draco.
import { NodeIO, getBounds } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { center, dedup, draco, prune, simplify, textureCompress, weld } from '@gltf-transform/functions';
import draco3d from 'draco3dgltf';
import { MeshoptSimplifier } from 'meshoptimizer';
import sharp from 'sharp';

export const TARGET_TRIANGLES = 20000;
export const TEXTURE_SIZE = 1024;
export const MAX_MOBILE_BYTES = 5 * 1024 * 1024;

await MeshoptSimplifier.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({
  'draco3d.decoder': await draco3d.createDecoderModule(),
  'draco3d.encoder': await draco3d.createEncoderModule(),
});

function countTriangles(doc) {
  let tris = 0;
  for (const mesh of doc.getRoot().listMeshes()) {
    for (const prim of mesh.listPrimitives()) {
      const indices = prim.getIndices();
      const position = prim.getAttribute('POSITION');
      tris += Math.floor((indices ? indices.getCount() : position?.getCount() ?? 0) / 3);
    }
  }
  return tris;
}

function dims(scene) {
  const { min, max } = getBounds(scene);
  return { widthM: max[0] - min[0], depthM: max[2] - min[2], heightM: max[1] - min[1], minY: min[1] };
}

export async function inspect(bytes) {
  const doc = await io.readBinary(bytes);
  const scene = doc.getRoot().getDefaultScene() ?? doc.getRoot().listScenes()[0];
  return { triangles: countTriangles(doc), dimensions: dims(scene), bytes: bytes.byteLength };
}

export async function optimize(rawBytes, { diameterM }) {
  const doc = await io.readBinary(rawBytes);
  const root = doc.getRoot();
  const scene = root.getDefaultScene() ?? root.listScenes()[0];
  const raw = { triangles: countTriangles(doc), dimensions: dims(scene), bytes: rawBytes.byteLength };

  // Escala: se envuelve la escena en un nodo raíz para no depender de cómo vino la jerarquía.
  const wrapper = doc.createNode('platter-root');
  for (const child of scene.listChildren()) {
    scene.removeChild(child);
    wrapper.addChild(child);
  }
  scene.addChild(wrapper);
  const footprint = Math.max(raw.dimensions.widthM, raw.dimensions.depthM);
  if (!(footprint > 0)) throw new Error('El modelo generado está vacío o no tiene volumen');
  const factor = diameterM / footprint;
  wrapper.setScale([factor, factor, factor]);

  const ratio = Math.min(1, TARGET_TRIANGLES / Math.max(raw.triangles, 1));
  await doc.transform(
    center({ pivot: 'below' }),
    weld(),
    ...(ratio < 1 ? [simplify({ simplifier: MeshoptSimplifier, ratio, error: 0.01 })] : []),
    dedup(),
    prune(),
    // Color y oclusión en JPEG (mucho más livianos); los mapas de normales se quedan en su formato.
    textureCompress({ encoder: sharp, targetFormat: 'jpeg', quality: 85, resize: [TEXTURE_SIZE, TEXTURE_SIZE], slots: /^(baseColor|occlusion)/ }),
    textureCompress({ encoder: sharp, resize: [TEXTURE_SIZE, TEXTURE_SIZE] }),
    draco(),
  );

  const bytes = await io.writeBinary(doc);
  const final = { triangles: countTriangles(doc), dimensions: dims(scene), bytes: bytes.byteLength };

  const warnings = [];
  const finalFootprint = Math.max(final.dimensions.widthM, final.dimensions.depthM);
  if (final.dimensions.heightM > finalFootprint * 0.6) {
    warnings.push('Más alto que ancho: puede venir girado (el plato debería quedar plano sobre la mesa)');
  }
  if (final.bytes > MAX_MOBILE_BYTES) warnings.push('Pesa más de 5 MB: lento con datos móviles');
  if (raw.triangles < 2000) warnings.push('Muy pocos triángulos: puede verse tosco');

  return { bytes, raw, final, scaleFactor: factor, warnings };
}
