# Platter API v1 — Contrato

Base: `/api/v1`. JSON UTF-8. Fechas ISO-8601. Montos en soles (`priceSoles`, número decimal).
Autenticación del dueño: `Authorization: Bearer <JWT HS256, 1h>`. Las rutas `/public/**`, `/auth/**`,
`/plans`, `/allergens`, `/models`, `/assets/**`, `/media/**` son anónimas.
Las descargas binarias autenticadas (`qr.png`, `qr-sheet.pdf`) también aceptan `?access_token=<jwt>`
para poder abrirse en un navegador externo.

## Errores

Todo error responde `{ "code": "STRING", "message": "texto en español", "details": {…opcional} }`.

| HTTP | code | Cuándo |
|---|---|---|
| 400 | `VALIDATION_ERROR` | `details` = `{campo: mensaje}` |
| 401 | `UNAUTHORIZED` / `INVALID_CREDENTIALS` | |
| 403 | `PLAN_LIMIT_REACHED` | límite de mesas/platos del plan |
| 404 | `NOT_FOUND` / `TABLE_NOT_FOUND` | |
| 409 | `EMAIL_TAKEN` / `DUPLICATE_TABLE` | |
| 413 / 415 | `IMAGE_TOO_LARGE` / `UNSUPPORTED_IMAGE` | JPEG/PNG ≤ 10 MB |
| 422 | `DISH_NOT_PUBLISHABLE` | `details` = `{campo: motivo}` |
| 503 | `AI_UNAVAILABLE` | `details` = `{ "retryable": true, "manualEntryAllowed": true }` |

## IAM

- `POST /auth/register` `{ownerName, email, password(min 8), restaurantName, address?}` → 201 `AuthResponse`
- `POST /auth/login` `{email, password}` → 200 `AuthResponse`
- `GET /me` → `{user, restaurant}`

`AuthResponse` = `{ token, expiresIn: 3600, user: {id, name, email}, restaurant: Restaurant }`

## Restaurante y planes

- `GET /plans` → `Plan[]`
- `GET /restaurant` → `Restaurant`
- `PUT /restaurant` `{name, address?}` → `Restaurant`
- `PUT /restaurant/plan` `{planCode}` → `Restaurant` (v1: sin pasarela de pago)

`Plan` = `{code: "EMPRENDEDOR"|"CRECIMIENTO"|"PRO", name, priceSoles, maxTables, maxDishes, aiAnalysis: bool}`
(`maxTables`/`maxDishes` = `null` → ilimitado)
`Restaurant` = `{id(uuid), name, address, plan: Plan, tableCount, dishCount}`

## Mesas y QR

- `GET /tables` → `Table[]`
- `POST /tables/batch` `{from: 1, to: 20, prefix: "Mesa"}` → 201 `Table[]` (solo las nuevas; etiquetas existentes se omiten)
- `POST /tables` `{label: "Terraza 01"}` → 201 `Table`
- `PATCH /tables/{id}` `{active: bool}` → `Table`
- `GET /tables/{id}/qr.png?size=1024` → `image/png`
- `GET /tables/qr-sheet.pdf?ids=<uuid,uuid>` (sin `ids` = todas) → `application/pdf` (una tarjeta por mesa con nombre del restaurante, mesa e instrucciones)

`Table` = `{id, label, token, active, menuUrl}` — `token`: 22 chars base64url aleatorio (no secuencial).
`menuUrl` = `{PUBLIC_WEB_URL}/m/{token}`.

## Catálogo

- `GET /allergens` → `[{code, label, icon}]`. Códigos: `GLUTEN, CRUSTACEANS, MOLLUSCS, FISH, EGGS, MILK, PEANUTS, TREE_NUTS, SOY, SESAME, CELERY, MUSTARD, SULPHITES, LUPIN`
- `GET /categories` → `string[]` sugeridas (`Entradas, Ceviches, Fondos, Criollos, Sánguches, Hamburguesas, Pizzas, Ensaladas, Postres, Bebidas`)
- `POST /dishes/photos` multipart `image` → 201 `{photoId, photoUrl}`
- `POST /dishes/analyze` multipart: `image` **o** `photoId` → 200 `Analysis` | 503 `AI_UNAVAILABLE`
- `GET /dishes` → `Dish[]`
- `GET /dishes/{id}` → `Dish`
- `POST /dishes` `DishInput` → 201 `Dish` (estado `DRAFT`)
- `PUT /dishes/{id}` `DishInput` → `Dish`
- `POST /dishes/{id}/publish` → `Dish` | 422 `DISH_NOT_PUBLISHABLE`
- `PATCH /dishes/{id}/availability` `{available: bool}` → `Dish`
- `DELETE /dishes/{id}` → 204

`Analysis` = `{ photoId, photoUrl, suggestedName, description, category, ingredients: string[], allergens: string[], estimatedCalories: {min, max}, confidence: 0..1, lowConfidence: bool, suggestedModelId }`

`DishInput` = `{ name, description?, category, priceSoles, ingredients: string[], allergens: string[], allergenFree: bool, kitchenNotes?, caloriesMin?, caloriesMax?, vegetarian: bool, vegan: bool, photoId?, modelId? }`

`Dish` = `{ id, name, description, category, priceSoles, ingredients, allergens, allergenFree, kitchenNotes, calories: {min,max}|null, vegetarian, vegan, photoUrl|null, model: Model|null, status: "DRAFT"|"PUBLISHED", available, updatedAt }`

Reglas de publicación: nombre, categoría, precio > 0, foto, modelo 3D y declaración explícita de alérgenos
(`allergens` no vacío **o** `allergenFree = true`).
Si `modelId` es nulo al crear, se asigna el modelo por defecto de la categoría (US10).

## Biblioteca 3D y activos

- `GET /models` → `Model[]`
- `GET /assets/models/{id}.glb` → `model/gltf-binary`, `ETag`, `Cache-Control: public, max-age=31536000, immutable`, soporta `If-None-Match` → 304
- `GET /media/photos/{photoId}` → imagen (caché pública)

`Model` = `{ id, name, category, glbUrl, dimensions: {widthM, depthM, heightM} }` (escala real en metros)

## Experiencia del comensal (público)

- `GET /public/tables/{token}` → `{ table: {label, active}, restaurant: {id, name} }` | 404 `TABLE_NOT_FOUND`
- `GET /public/restaurants/{restaurantId}/menu?exclude=GLUTEN,FISH` → `PublicMenu`
- `POST /public/events` `{type, tableToken?, dishId?, durationSeconds?}` → 202. `type`: `QR_SCAN | DISH_VIEW | AR_LAUNCH | AR_SESSION_END`
- `POST /public/leads` `{restaurantName, contactName, email, phone, tables}` → 201 `{message}`

`PublicMenu` = `{ restaurant: {id, name}, excludedAllergens: string[], categories: [{name, dishes: PublicDish[]}] }`
Solo platos `PUBLISHED`. Platos agotados se incluyen con `available: false`. Platos con algún alérgeno excluido se omiten.
`PublicDish` = `Dish` sin `status`/`updatedAt`.

## Analítica (dueño)

- `GET /analytics/summary?days=7` → `{ days, qrScans, dishViews, arLaunches, avgArSeconds, topDishes: [{dishId, name, views, arLaunches}], topTables: [{label, scans}] }`

## URLs web

- Carta del comensal: `{PUBLIC_WEB_URL}/m/{token}` (también `/m/?t={token}`); demo sin mesa: `/m/demo`.
- Landing: `{PUBLIC_WEB_URL}/`.
- En docker-compose un NGINX sirve ambos y enruta `/api/**` al backend (mismo origen).
