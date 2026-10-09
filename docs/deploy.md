# Despliegue gratuito: Render + Supabase

| Pieza | Servicio | URL esperada |
|---|---|---|
| Landing + carta WebAR (`/m/{token}`) | Render · Static Site | `https://platter-web.onrender.com` |
| App de gestión (Flutter web) | Render · Static Site | `https://platter-admin.onrender.com` |
| Backend Spring Boot (Docker) | Render · Web Service (free) | `https://platter-api.onrender.com` |
| PostgreSQL | Supabase (free) | — |
| Fotos de platos (S3) | Supabase Storage (free) | — |

Los modelos 3D viajan dentro de la imagen del backend, así que no necesitan almacenamiento externo.
Redis no se usa en este entorno: la caché de la carta queda en memoria (`CACHE_TYPE=simple`), suficiente con una sola instancia.

## 1. Supabase: base de datos y almacenamiento

1. Entra a <https://supabase.com> con tu cuenta de GitHub → **New project**.
   - Nombre: `platter` · Región: **East US (North Virginia)** (la misma zona que el backend en Render).
   - Guarda la **contraseña de la base de datos**.
2. **Cadena de conexión** → botón **Connect** → pestaña **Connection string** → **Session pooler**.
   Usa el *Session pooler* (no la *Direct connection*, que solo funciona por IPv6, ni el *Transaction pooler*,
   que no es compatible con Flyway/JPA). Toma de ahí:
   - `DATABASE_URL` = `jdbc:postgresql://<host-del-pooler>:5432/postgres?sslmode=require`
     (ej. `jdbc:postgresql://aws-0-us-east-1.pooler.supabase.com:5432/postgres?sslmode=require`)
   - `DATABASE_USER` = el usuario que aparece, con el formato `postgres.<project-ref>`
   - `DATABASE_PASSWORD` = la contraseña del paso 1
3. **Bucket de fotos** → **Storage** → **New bucket** → nombre `photo`, **privado** (el backend las sirve).
4. **Credenciales S3** → **Storage** → **S3 Configuration** (o *Settings → Storage*):
   - `S3_ENDPOINT` = el *Endpoint* (ej. `https://<project-ref>.storage.supabase.co/storage/v1/s3`)
   - `S3_REGION` = la *Region* (ej. `us-east-1`)
   - **New access key** → `S3_ACCESS_KEY` y `S3_SECRET_KEY`. Dan acceso total al storage: solo van en Render.

## 2. Render: los tres servicios

1. Entra a <https://render.com> con tu cuenta de GitHub y autoriza el acceso a la organización
   `upc-pre-1ASI0728-2620-9046-Platter`.
2. **New → Blueprint** → elige el repositorio `platter` → Render lee [`render.yaml`](../render.yaml).
3. Te pedirá los valores marcados como secretos; pega los del paso 1:
   `DATABASE_URL`, `DATABASE_USER`, `DATABASE_PASSWORD`, `S3_ENDPOINT`, `S3_REGION`, `S3_ACCESS_KEY`,
   `S3_SECRET_KEY`. `GEMINI_API_KEY` es opcional (sin ella, el análisis con IA pasa a carga manual);
   se obtiene gratis en <https://aistudio.google.com/apikey>.
   `JWT_SECRET` se genera solo.
4. **Apply**. El primer despliegue tarda: backend ~5–8 min (imagen Docker), app Flutter ~5 min.

### Si Render asigna otras URLs

Si los nombres `platter-api` o `platter-web` ya estaban tomados, Render añade un sufijo
(ej. `platter-api-ab12.onrender.com`). En ese caso:

- `render.yaml` → regla `/api/*` de `platter-web` y `API_BASE_URL` de `platter-admin` → URL real del backend.
- Variable `PUBLIC_WEB_URL` de `platter-api` → URL real de `platter-web` (es la que se imprime en los QR).
- Variable de repositorio `BACKEND_HEALTH_URL` en GitHub (*Settings → Secrets and variables → Actions → Variables*)
  → `https://<backend>/actuator/health`, para el workflow *Keep alive*.

Haz commit y push: Render vuelve a desplegar solo.

## 3. Comprobar

- `https://platter-api.onrender.com/actuator/health` → `{"status":"UP"}`
- `https://platter-web.onrender.com/` → landing con la demo 3D
- `https://platter-web.onrender.com/m/demo` → carta demo; en el celular, "Ver en mi mesa" abre la AR
- `https://platter-admin.onrender.com/` → inicia sesión con `demo@platter.pe` / `demo12345`

## Limitaciones del plan gratuito

- **El backend duerme tras 15 min sin tráfico** y tarda ~1 min en despertar. El workflow
  [`keep-alive.yml`](../.github/workflows/keep-alive.yml) lo despierta cada 10 min de 8:00 a 23:59 (hora de Lima).
  Render da 750 h gratis al mes, suficientes para una sola instancia.
- **Supabase pausa el proyecto tras 1 semana sin actividad**; el mismo ping lo evita. Si se pausa, se reactiva
  desde el panel de Supabase.
- 512 MB de RAM y CPU compartida: bien para demos y pilotos pequeños, no para carga real (QA-06).
- La cuenta demo es pública: cambia su contraseña o desactiva `DEMO_DATA` si el despliegue deja de ser una demo.
