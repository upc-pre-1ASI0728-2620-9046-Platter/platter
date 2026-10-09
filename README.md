# Platter — v0.1 (MVP)

Carta gastronómica en **Realidad Aumentada** para restaurantes MYPE: el dueño fotografía un plato, la IA
(Gemini) propone la ficha técnica, se publica con un modelo 3D a escala real y los comensales lo proyectan
sobre su mesa escaneando el QR, **sin instalar apps ni registrarse**.

Implementa la arquitectura del informe (Cap. IV): monolito modular Spring Boot por *bounded contexts*,
WebAR con estándares web, app Flutter para el dueño, PostgreSQL + Redis y un gateway NGINX.

## Estructura

| Carpeta | Contenedor C4 | Tecnología |
|---|---|---|
| [backend/](backend/) | Platter Core Backend + AI Analysis | Spring Boot 4.1 · Java 21 · PostgreSQL · Redis · Resilience4j |
| [webar/](webar/) | WebAR Dining Web App | HTML/JS sin build · `<model-viewer>` (WebXR / Scene Viewer / Quick Look) |
| [landing/](landing/) | Landing Page Web App | HTML/CSS/JS estático |
| [admin_app/](admin_app/) | Restaurant Admin App | Flutter (Android / iOS / web) |
| [infra/nginx/](infra/nginx/) | API Gateway & Reverse Proxy | NGINX |
| [tools/model-generator/](tools/model-generator/) | Biblioteca 3D normalizada 1:1 | Node · glTF-Transform |
| [docs/api-contract.md](docs/api-contract.md) | Contrato REST v1 (Published Language) | — |

### Bounded contexts del backend (`backend/src/main/java/pe/platter/`)

| Paquete | Contexto | Responsabilidad |
|---|---|---|
| `catalog` | Dish & Menu Catalog (core) | Platos, alérgenos, fotos, publicación, disponibilidad, carta activa cacheada |
| `analysis` | AI Gastronomic Analysis (core) | Puerto de inferencia + ACL `GeminiApiClientAdapter` + Circuit Breaker |
| `dining` | AR Dining Experience (core) | Sesión por token de mesa, filtro de alérgenos, métricas anónimas, analítica |
| `restaurants` | Restaurant & Table Management (supporting) | Restaurante, mesas, token criptográfico, QR PNG y plantilla PDF |
| `billing` | Subscription & Billing (generic) | Planes y límites de mesas/platos |
| `assets` | Asset pipeline | Biblioteca GLB con `ETag` + `Cache-Control: immutable` |
| `iam`, `leads` | — | Registro/login JWT HS256 (1 h) · solicitudes de piloto |

## Despliegue gratuito

Render (backend Docker + landing/carta + app de gestión web) y Supabase (PostgreSQL + fotos S3),
definidos en [`render.yaml`](render.yaml). Paso a paso en [docs/deploy.md](docs/deploy.md).

## Ejecutar todo con Docker

```bash
cp .env.example .env          # opcional: añade GEMINI_API_KEY
docker compose up --build
```

- Landing: <http://localhost:8081/>
- Carta demo (comensal): <http://localhost:8081/m/demo>
- API: <http://localhost:8081/api/v1> (o directo en `:8080`)
- Cuenta demo para la app: `demo@platter.pe` / `demo12345`
- Si el puerto 8080 está ocupado: `BACKEND_PORT=8090 docker compose up --build`

Para probar AR en un celular, usa la IP de tu PC en la red local en `PUBLIC_WEB_URL`
(ej. `http://192.168.1.20:8081`). WebXR y Quick Look requieren **HTTPS** fuera de `localhost`: expón el
puerto 8081 con un túnel HTTPS (p. ej. `cloudflared tunnel --url http://localhost:8081`) y pon esa URL en
`PUBLIC_WEB_URL` para que los QR apunten a ella. Sin HTTPS la carta y el visor 3D funcionan, pero el botón AR no.

### App Flutter

```bash
cd admin_app
flutter run --dart-define=API_BASE_URL=http://localhost:8080/api/v1
# Emulador Android: http://10.0.2.2:8080/api/v1
```

## Desarrollo del backend sin Docker

```bash
docker compose up -d postgres redis
cd backend && mvn spring-boot:run      # requiere JDK 21+
mvn test                               # H2 en modo PostgreSQL, sin servicios externos
```

Variables: `DATABASE_URL`, `DATABASE_USER`, `DATABASE_PASSWORD`, `CACHE_TYPE` (`simple`|`redis`),
`REDIS_HOST`, `JWT_SECRET` (≥ 32 bytes), `GEMINI_API_KEY`, `GEMINI_MODEL`, `PUBLIC_WEB_URL`,
`STORAGE_DIR`, `DEMO_DATA`, `DB_POOL_SIZE` y, para fotos en S3 (Supabase, R2, AWS):
`S3_BUCKET`, `S3_ENDPOINT`, `S3_REGION`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`.

## Cobertura del backlog en v0.1

| Historia | Estado |
|---|---|
| US01–US04 Landing, ROI, planes + calculadora, piloto | ✅ |
| US05–US09 Foto → IA → validación manual → publicación | ✅ (requiere `GEMINI_API_KEY`; sin ella, carga manual) |
| US10 Modelo 3D por categoría / selección manual | ✅ biblioteca de 10 modelos procedurales |
| US11–US12 Mesas, QR y plantilla PDF imprimible | ✅ (logo del restaurante en la plantilla: pendiente) |
| US13–US17 Carta sin registro, AR 1:1 con escala bloqueada, alérgenos | ✅ |
| US18 Agotado por hoy | ✅ invalida la caché de la carta al instante |
| US19 Analítica de interacciones | ✅ resumen 7/30 días (exportación de reporte: pendiente) |
| US20 Suscripción con pasarela de pagos | ⏳ v0.1 solo cambia de plan, sin cobro |
| US21 Inferencia Gemini con Circuit Breaker | ✅ timeout 5 s, ventana 10, 50 %, 30 s abierto → 503 controlado |
| US22 Despacho de GLB con caché y ETag/304 | ✅ (Draco y CDN: pendiente para producción) |

### Diferencias conscientes respecto al diseño (para la siguiente iteración)

- **Almacenamiento**: fotos en S3 compatible (o disco local en desarrollo) tras el puerto `ObjectStorage`; aún sin URLs prefirmadas (QA-07): el backend recibe y sirve las fotos.
- **AI Ingestion Service**: vive como módulo dentro del monolito (mismo proceso), aislado tras su puerto/ACL para extraerlo luego.
- **Modelos 3D**: son estilizados y generados por código; los fotorrealistas por fotogrametría los sustituyen sin cambiar la API.
- **Gemini**: el modelo es configurable (`GEMINI_MODEL`); el informe cita 1.5 Flash, que ya no está disponible.
