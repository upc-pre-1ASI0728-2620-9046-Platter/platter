// Meshy · API v1 (https://docs.meshy.ai/en/api/image-to-3d)
//   POST /openapi/v1/image-to-3d      { image_url: data URI, ... } → { result: taskId }
//   GET  /openapi/v1/image-to-3d/{id} status PENDING|IN_PROGRESS|SUCCEEDED|FAILED|CANCELED
// Tareas fallidas no consumen créditos (Meshy los devuelve).
import { requestJson } from './http.js';

const BASE = 'https://api.meshy.ai/openapi/v1';
const MODEL = process.env.MESHY_MODEL || 'latest';

export function createMeshy(apiKey) {
  const auth = { Authorization: `Bearer ${apiKey}` };

  return {
    id: 'meshy',
    label: `Meshy (${MODEL})`,

    async create(jpeg) {
      const body = await requestJson(`${BASE}/image-to-3d`, {
        method: 'POST',
        headers: { ...auth, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          image_url: `data:image/jpeg;base64,${Buffer.from(jpeg).toString('base64')}`,
          ai_model: MODEL,
          should_texture: true,
          enable_pbr: true,
          should_remesh: true,
          target_polycount: 30000,
          topology: 'triangle',
        }),
      });
      if (!body?.result) throw new Error(`Meshy: respuesta inesperada ${JSON.stringify(body).slice(0, 300)}`);
      return body.result;
    },

    async poll(taskId) {
      const t = await requestJson(`${BASE}/image-to-3d/${encodeURIComponent(taskId)}`, { headers: auth });
      if (t.status === 'PENDING' || t.status === 'IN_PROGRESS') {
        return { done: false, progress: t.progress ?? 0 };
      }
      if (t.status === 'SUCCEEDED') {
        return {
          done: true,
          modelUrl: t.model_urls?.glb,
          previewUrl: t.thumbnail_url ?? null,
          credits: t.consumed_credits ?? null,
        };
      }
      const err = new Error(`Meshy: la tarea terminó con estado "${t.status}" ${t.task_error?.message ?? ''}`);
      err.remoteFailure = true;
      throw err;
    },
  };
}
