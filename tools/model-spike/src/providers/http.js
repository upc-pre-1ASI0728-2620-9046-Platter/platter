// Utilidades HTTP compartidas por los proveedores.

export async function requestJson(url, options = {}) {
  let res;
  try {
    res = await fetch(url, options);
  } catch (e) {
    throw new Error(`${options.method || 'GET'} ${url}: sin conexión (${e.message})`);
  }
  const text = await res.text();
  let body;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  if (!res.ok) {
    const detail = typeof body === 'string' ? body : JSON.stringify(body);
    const err = new Error(`${options.method || 'GET'} ${url} → HTTP ${res.status}: ${String(detail).slice(0, 400)}`);
    err.status = res.status;
    throw err;
  }
  return body;
}

export async function download(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Descarga fallida (${res.status}): ${url}`);
  return new Uint8Array(await res.arrayBuffer());
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
