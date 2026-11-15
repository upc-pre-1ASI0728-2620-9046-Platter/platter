// Proveedor simulado (--mock): sin red ni créditos. Devuelve un GLB de la biblioteca actual deformado
// como llegaría de una IA (escala arbitraria y desplazado del origen) para probar todo el flujo.
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import draco3d from 'draco3dgltf';
import { LIBRARY_DIR } from '../paths.js';

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({
  'draco3d.decoder': await draco3d.createDecoderModule(),
  'draco3d.encoder': await draco3d.createEncoderModule(),
});

const SOURCES = ['ceviche', 'lomo-saltado', 'causa', 'postre', 'hamburguesa'];

export function createMock() {
  const pending = new Map();
  return {
    id: 'mock',
    label: 'Simulado (sin IA)',

    async create(_jpeg, name) {
      const id = `mock-${name}-${Date.now()}`;
      pending.set(id, { at: Date.now(), source: SOURCES[[...name].reduce((a, c) => a + c.charCodeAt(0), 0) % SOURCES.length] });
      return id;
    },

    async poll(taskId) {
      const task = pending.get(taskId) ?? { at: 0, source: 'generico' };
      const elapsed = Date.now() - task.at;
      if (elapsed < 1500) return { done: false, progress: Math.round((elapsed / 1500) * 100) };
      const doc = await io.readBinary(new Uint8Array(await readFile(path.join(LIBRARY_DIR, 'models', `${task.source}.glb`))));
      const scene = doc.getRoot().getDefaultScene();
      const wrapper = doc.createNode('ai-output').setScale([3.7, 3.7, 3.7]).setTranslation([0.4, -0.2, 0.15]);
      for (const child of scene.listChildren()) {
        scene.removeChild(child);
        wrapper.addChild(child);
      }
      scene.addChild(wrapper);
      return { done: true, modelBytes: await io.writeBinary(doc), previewUrl: null, credits: 0 };
    },
  };
}
