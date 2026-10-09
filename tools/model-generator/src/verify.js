// Verifica los GLB generados: lectura con glTF-Transform (decodificando Draco),
// validación oficial Khronos (gltf-validator) y coherencia con models.json.
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { getBounds } from '@gltf-transform/core';
import draco3d from 'draco3dgltf';
import validator from 'gltf-validator';

const here = path.dirname(fileURLToPath(import.meta.url));
const lib = path.resolve(here, '../../../backend/src/main/resources/library');
const catalog = JSON.parse(await readFile(path.join(lib, 'models.json'), 'utf8'));
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({
  'draco3d.decoder': await draco3d.createDecoderModule(),
});

let failed = false;
for (const m of catalog) {
  const file = path.join(lib, 'models', `${m.id}.glb`);
  const bytes = new Uint8Array(await readFile(file));
  const doc = await io.readBinary(bytes);
  const scene = doc.getRoot().getDefaultScene();
  const { min, max } = getBounds(scene);
  const dims = { widthM: max[0] - min[0], depthM: max[2] - min[2], heightM: max[1] - min[1] };
  const report = await validator.validateBytes(bytes, { uri: `${m.id}.glb`, maxIssues: 20 });
  const { numErrors, numWarnings } = report.issues;
  const okDims = ['widthM', 'depthM', 'heightM'].every((k) => Math.abs(dims[k] - m.dimensions[k]) < 0.003);
  const okBase = Math.abs(min[1]) < 0.001 && Math.abs(min[0] + max[0]) < 0.002 && Math.abs(min[2] + max[2]) < 0.002;
  const okSize = bytes.byteLength < 1024 * 1024;
  const ok = numErrors === 0 && okDims && okBase && okSize;
  if (!ok) failed = true;
  console.log(
    `${ok ? 'OK  ' : 'FAIL'} ${m.id.padEnd(16)} ${(bytes.byteLength / 1024).toFixed(1).padStart(6)} KB  ` +
      `validator: ${numErrors} errores, ${numWarnings} avisos  ` +
      `bbox ${dims.widthM.toFixed(3)}×${dims.depthM.toFixed(3)}×${dims.heightM.toFixed(3)} m  minY=${min[1].toFixed(4)}`,
  );
  if (numErrors || numWarnings) {
    for (const i of report.issues.messages.slice(0, 5)) console.log(`      ${i.severity === 0 ? 'E' : 'W'} ${i.code}: ${i.message} ${i.pointer ?? ''}`);
  }
}
process.exit(failed ? 1 : 0);
