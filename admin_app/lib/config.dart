/// Configuración de compilación.
///
/// Se sobrescribe con `--dart-define=API_BASE_URL=...`.
/// En el emulador de Android usa `http://10.0.2.2:8080/api/v1`.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  /// Tamaño máximo de foto aceptado por el backend (10 MB).
  static const int maxPhotoBytes = 10 * 1024 * 1024;
}
