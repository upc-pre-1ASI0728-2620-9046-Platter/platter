import 'json_utils.dart';

class Allergen {
  const Allergen({required this.code, required this.label, this.icon});

  final String code;
  final String label;
  final String? icon;

  factory Allergen.fromJson(Map<String, dynamic> json) => Allergen(
        code: json['code'] as String? ?? '',
        label: json['label'] as String? ?? json['code'] as String? ?? '',
        icon: json['icon'] as String?,
      );
}

class ModelDimensions {
  const ModelDimensions({required this.widthM, required this.depthM, required this.heightM});

  final double widthM;
  final double depthM;
  final double heightM;

  factory ModelDimensions.fromJson(Map<String, dynamic> json) => ModelDimensions(
        widthM: asDouble(json['widthM']),
        depthM: asDouble(json['depthM']),
        heightM: asDouble(json['heightM']),
      );

  /// Ej.: "28 × 28 × 4 cm" (ancho × profundidad × alto).
  String get centimeters {
    String cm(double m) {
      final v = (m * 1000).round() / 10; // cm con 1 decimal
      return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    }

    return '${cm(widthM)} × ${cm(depthM)} × ${cm(heightM)} cm';
  }
}

/// Modelo 3D de la biblioteca.
class Model3D {
  const Model3D({
    required this.id,
    required this.name,
    required this.category,
    required this.glbUrl,
    this.dimensions,
  });

  final String id;
  final String name;
  final String category;
  final String glbUrl;
  final ModelDimensions? dimensions;

  factory Model3D.fromJson(Map<String, dynamic> json) {
    final dims = asMap(json['dimensions']);
    return Model3D(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      glbUrl: json['glbUrl'] as String? ?? '',
      dimensions: dims == null ? null : ModelDimensions.fromJson(dims),
    );
  }
}
