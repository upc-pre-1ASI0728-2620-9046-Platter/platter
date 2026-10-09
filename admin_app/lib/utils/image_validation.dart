import 'dart:typed_data';

import '../config.dart';

/// Detecta JPEG/PNG por sus bytes mágicos. Devuelve el MIME o `null`.
String? detectImageMime(Uint8List bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return 'image/png';
  }
  return null;
}

/// Valida una foto antes de subirla. Devuelve un mensaje de error o `null` si es válida.
String? validatePhotoBytes(Uint8List bytes, {int maxBytes = AppConfig.maxPhotoBytes}) {
  if (bytes.isEmpty) return 'La imagen está vacía.';
  if (detectImageMime(bytes) == null) return 'Formato no soportado. Usa una foto JPEG o PNG.';
  if (bytes.length > maxBytes) {
    final mb = (maxBytes / (1024 * 1024)).toStringAsFixed(0);
    return 'La foto supera los $mb MB. Prueba con otra imagen.';
  }
  return null;
}
