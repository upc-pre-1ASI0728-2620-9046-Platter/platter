// Servidor estático de out/ accesible desde la red local (para abrir la comparación en el celular).
// La AR necesita HTTPS fuera de localhost: expón el puerto con un túnel, p. ej.
//   cloudflared tunnel --url http://localhost:5180
import { createReadStream, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { networkInterfaces } from 'node:os';
import path from 'node:path';
import { OUT_DIR } from './paths.js';

const PORT = Number(process.env.PORT) || 5180;
const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.glb': 'model/gltf-binary',
  '.jpg': 'image/jpeg',
  '.png': 'image/png',
  '.csv': 'text/csv; charset=utf-8',
};

if (!existsSync(path.join(OUT_DIR, 'index.html'))) {
  console.error('Todavía no hay resultados. Ejecuta primero npm run generate (o npm run mock).');
  process.exit(1);
}

createServer((req, res) => {
  const urlPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  const file = path.normalize(path.join(OUT_DIR, urlPath === '/' ? 'index.html' : urlPath));
  if (!file.startsWith(OUT_DIR) || !existsSync(file) || !statSync(file).isFile() || file.endsWith('.raw.glb')) {
    res.writeHead(404).end('No encontrado');
    return;
  }
  res.writeHead(200, {
    'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream',
    'Cache-Control': 'no-cache',
    'Access-Control-Allow-Origin': '*',
  });
  createReadStream(file).pipe(res);
}).listen(PORT, '0.0.0.0', () => {
  const ips = Object.values(networkInterfaces()).flat().filter((i) => i && i.family === 'IPv4' && !i.internal).map((i) => i.address);
  console.log(`Comparación lista:\n  http://localhost:${PORT}`);
  for (const ip of ips) console.log(`  http://${ip}:${PORT}   (celular en la misma red: visor 3D, sin AR)`);
  console.log(`\nPara probar la AR en el celular necesitas HTTPS:\n  cloudflared tunnel --url http://localhost:${PORT}`);
});
