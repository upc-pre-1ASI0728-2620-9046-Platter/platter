import 'dart:async';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Traduce cualquier error a un mensaje amigable en español.
String friendlyError(Object error) {
  if (error is ApiException) {
    switch (error.code) {
      case 'INVALID_CREDENTIALS':
        return 'Correo o contraseña incorrectos.';
      case 'UNAUTHORIZED':
        return 'Tu sesión expiró. Vuelve a iniciar sesión.';
      case 'EMAIL_TAKEN':
        return 'Ya existe una cuenta con ese correo.';
      case 'PLAN_LIMIT_REACHED':
        return 'Alcanzaste el límite de tu plan. Puedes mejorarlo en la pestaña Cuenta.';
      case 'DUPLICATE_TABLE':
        return 'Ya existe una mesa con esa etiqueta.';
      case 'IMAGE_TOO_LARGE':
        return 'La foto supera los 10 MB. Prueba con otra imagen.';
      case 'UNSUPPORTED_IMAGE':
        return 'Formato no soportado. Usa una foto JPEG o PNG.';
      case 'AI_UNAVAILABLE':
        return 'El análisis con IA no está disponible ahora. '
            'Puedes completar la ficha manualmente.';
      case 'NOT_FOUND':
      case 'TABLE_NOT_FOUND':
        return error.message.isNotEmpty ? error.message : 'No se encontró el recurso.';
    }
    return error.message;
  }
  if (error is TimeoutException) {
    return 'El servidor tardó demasiado en responder. Inténtalo de nuevo.';
  }
  if (error is http.ClientException) {
    return 'No se pudo conectar con el servidor. Verifica tu conexión.';
  }
  return 'Ocurrió un error inesperado.';
}
