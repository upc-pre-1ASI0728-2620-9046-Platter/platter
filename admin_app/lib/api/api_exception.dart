import 'dart:convert';

/// Error devuelto por la API de Platter:
/// `{ "code": "STRING", "message": "texto", "details": {…} }`.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.details = const {},
    this.status = 0,
  });

  final String code;
  final String message;
  final Map<String, dynamic> details;

  /// Código HTTP (0 si el error no provino del servidor).
  final int status;

  /// Construye la excepción a partir de una respuesta HTTP de error.
  /// Tolera cuerpos vacíos o que no sean JSON.
  factory ApiException.fromResponse(int status, String body) {
    Map<String, dynamic>? json;
    if (body.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } on FormatException {
        json = null;
      }
    }
    final details = json?['details'];
    return ApiException(
      code: (json?['code'] as String?) ?? _defaultCode(status),
      message: (json?['message'] as String?) ?? 'Error inesperado del servidor ($status).',
      details: details is Map<String, dynamic> ? details : const {},
      status: status,
    );
  }

  static String _defaultCode(int status) => switch (status) {
        400 => 'VALIDATION_ERROR',
        401 => 'UNAUTHORIZED',
        403 => 'FORBIDDEN',
        404 => 'NOT_FOUND',
        413 => 'IMAGE_TOO_LARGE',
        415 => 'UNSUPPORTED_IMAGE',
        503 => 'SERVICE_UNAVAILABLE',
        _ => 'HTTP_$status',
      };

  /// Mensajes por campo (`details` de VALIDATION_ERROR / DISH_NOT_PUBLISHABLE).
  Map<String, String> get fieldErrors => {
        for (final e in details.entries)
          if (e.value is String) e.key: e.value as String,
      };

  @override
  String toString() => 'ApiException($status $code: $message)';
}
