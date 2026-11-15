// Tripo 3D · API v3 (https://developers.tripo3d.ai)
//   POST /v3/files                      multipart "file"  → data.file_token
//   POST /v3/generation/image-to-model  { input, model, ... } → data.task_id
//   GET  /v3/tasks/{id}                 status queued|running|success|failed|cancelled
// Las URLs del resultado caducan a los 5 min: se descargan apenas termina la tarea.
import { requestJson } from './http.js';

const BASE = 'https://openapi.tripo3d.ai/v3';
const MODEL = process.env.TRIPO_MODEL || 'v3.1-20260211';

export function createTripo(apiKey) {
  const auth = { Authorization: `Bearer ${apiKey}` };

  function check(body, what) {
    if (!body || body.code !== 0) {
      throw new Error(`Tripo ${what}: respuesta inesperada ${JSON.stringify(body).slice(0, 300)}`);
    }
    return body.data;
  }

  return {
    id: 'tripo',
    label: `Tripo (${MODEL})`,

    async create(jpeg, name) {
      const form = new FormData();
      form.append('file', new Blob([jpeg], { type: 'image/jpeg' }), `${name}.jpg`);
      const upload = check(await requestJson(`${BASE}/files`, { method: 'POST', headers: auth, body: form }), 'upload');

      const task = check(
        await requestJson(`${BASE}/generation/image-to-model`, {
          method: 'POST',
          headers: { ...auth, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            input: upload.file_token,
            model: MODEL,
            texture: true,
            pbr: true,
            texture_quality: 'standard',
            face_limit: 50000,
            // Tripo estima el tamaño real en metros; lo registramos para compararlo con el diámetro declarado.
            auto_size: true,
          }),
        }),
        'image-to-model',
      );
      return task.task_id;
    },

    async poll(taskId) {
      const data = check(await requestJson(`${BASE}/tasks/${encodeURIComponent(taskId)}`, { headers: auth }), 'task');
      if (['queued', 'running', 'unknown'].includes(data.status)) {
        return { done: false, progress: data.progress ?? 0 };
      }
      if (data.status === 'success') {
        return {
          done: true,
          modelUrl: data.output?.model_url,
          previewUrl: data.output?.rendered_image_url ?? null,
          credits: data.consumed_credit ?? data.credits ?? null,
        };
      }
      const err = new Error(`Tripo: la tarea terminó con estado "${data.status}" ${JSON.stringify(data.error ?? '')}`);
      err.remoteFailure = true;
      throw err;
    },
  };
}
