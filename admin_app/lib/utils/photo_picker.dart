import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'image_validation.dart';

/// Foto elegida y validada en el dispositivo.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.fileName, required this.mimeType});

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

class PhotoValidationException implements Exception {
  const PhotoValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

final ImagePicker _picker = ImagePicker();

bool cameraSupported() {
  try {
    return _picker.supportsImageSource(ImageSource.camera);
  } catch (_) {
    return false;
  }
}

/// Abre la cámara o la galería, comprime (85 %, máx. 1600 px) y valida JPEG/PNG ≤ 10 MB.
/// Devuelve `null` si el usuario cancela; lanza [PhotoValidationException] si no es válida.
Future<PickedPhoto?> pickPhoto(ImageSource source) async {
  final file = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final error = validatePhotoBytes(bytes);
  if (error != null) throw PhotoValidationException(error);
  final mime = detectImageMime(bytes)!;
  final ext = mime == 'image/png' ? 'png' : 'jpg';
  var name = file.name.isNotEmpty ? file.name : 'plato.$ext';
  if (!name.toLowerCase().endsWith('.$ext') && !(ext == 'jpg' && name.toLowerCase().endsWith('.jpeg'))) {
    name = '$name.$ext';
  }
  return PickedPhoto(bytes: bytes, fileName: name, mimeType: mime);
}
