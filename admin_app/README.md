# Platter Admin (Flutter)

App de administración para dueños de restaurantes de **Platter**: digitaliza tu carta con una foto,
deja que la IA sugiera la ficha del plato, publícalo con un modelo 3D y genera los QR de tus mesas
para que tus comensales vean los platos en realidad aumentada (WebAR).

El contrato de la API está en [`../docs/api-contract.md`](../docs/api-contract.md).

## Requisitos

- Flutter 3.44+ / Dart 3.12+
- Backend de Platter corriendo (por defecto en `http://localhost:8080/api/v1`)

## Cómo ejecutar

```bash
cd admin_app
flutter pub get

# Web / macOS / simulador de iOS (backend en la misma máquina)
flutter run -d chrome
flutter run -d macos

# Emulador de Android: localhost del PC es 10.0.2.2
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1

# Teléfono físico en la misma red Wi-Fi
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8080/api/v1
```

La URL base de la API se configura con `--dart-define=API_BASE_URL=...`
(valor por defecto: `http://localhost:8080/api/v1`).

Notas:

- **Android**: el tráfico `http://` (sin TLS) solo está permitido en compilaciones *debug*
  (`android/app/src/debug/AndroidManifest.xml`). En producción usa `https://`.
- **iOS**: se incluyen los permisos de cámara y galería en `Info.plist` y
  `NSAllowsLocalNetworking` para desarrollo local.
- **Web**: el backend debe habilitar CORS para el origen de la app (p. ej. `http://localhost:xxxx`),
  incluyendo la cabecera `Authorization` (las imágenes QR se piden con el JWT en la cabecera).
  Con docker-compose y NGINX en el mismo origen no hace falta.

## Pruebas y calidad

```bash
flutter analyze
flutter test
flutter build web
```

## Funcionalidades

| Pestaña / pantalla | Historias |
|---|---|
| Inicio de sesión y registro (JWT persistido; un 401 cierra la sesión) | IAM |
| **Carta**: platos por categoría, estado Borrador/Publicado, interruptor "Agotado por hoy" | US18 |
| **Nuevo plato**: foto (cámara/galería, JPEG/PNG ≤ 10 MB) → subida → análisis con IA → ficha editable; si la IA no está disponible se continúa manualmente | US05–US09, QA-03 |
| Selector de modelo 3D de la biblioteca (con dimensiones reales en cm) | US10 |
| Guardar borrador / Publicar (muestra los motivos si no es publicable), editar y eliminar | US09 |
| **Mesas**: generar rango, agregar mesa, activar/desactivar, ver QR, abrir carta, descargar plantilla PDF | US11, US12 |
| **Métricas**: QR escaneados, vistas, lanzamientos AR, tiempo AR promedio, ranking de platos y mesas (7/30 días) | US19 |
| **Cuenta**: datos del restaurante, plan actual, uso (mesas/platos), cambio de plan, cerrar sesión | Planes |

## Estructura

```
lib/
  main.dart            # App, tema (terracota), localización es-PE, enrutamiento por sesión
  config.dart          # API_BASE_URL
  api/                 # ApiClient (http + JWT + errores), PlatterApi (endpoints tipados), mensajes
  models/              # Clases Dart con fromJson/toJson
  state/session.dart   # Sesión (ChangeNotifier) + SessionScope (InheritedNotifier)
  screens/             # auth, dishes, tables, metrics, account
  widgets/             # Estados vacío/carga/error, chips, fotos
  utils/               # Formato S/, validación de imágenes, selector de fotos, url_launcher
test/                  # Modelos, ApiClient/errores, login y ficha del plato
```
