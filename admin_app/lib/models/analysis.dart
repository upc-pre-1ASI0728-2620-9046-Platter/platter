import 'dish.dart';
import 'json_utils.dart';

/// Sugerencias de la IA para una foto (`POST /dishes/analyze`).
class Analysis {
  const Analysis({
    required this.photoId,
    this.photoUrl,
    this.suggestedName,
    this.description,
    this.category,
    this.ingredients = const [],
    this.allergens = const [],
    this.estimatedCalories,
    this.confidence = 0,
    this.lowConfidence = false,
    this.suggestedModelId,
  });

  final String photoId;
  final String? photoUrl;
  final String? suggestedName;
  final String? description;
  final String? category;
  final List<String> ingredients;
  final List<String> allergens;
  final CalorieRange? estimatedCalories;
  final double confidence;
  final bool lowConfidence;
  final String? suggestedModelId;

  factory Analysis.fromJson(Map<String, dynamic> json) => Analysis(
        photoId: json['photoId']?.toString() ?? '',
        photoUrl: json['photoUrl'] as String?,
        suggestedName: json['suggestedName'] as String?,
        description: json['description'] as String?,
        category: json['category'] as String?,
        ingredients: asStringList(json['ingredients']),
        allergens: asStringList(json['allergens']),
        estimatedCalories: CalorieRange.fromJson(json['estimatedCalories']),
        confidence: asDouble(json['confidence']),
        lowConfidence: json['lowConfidence'] as bool? ?? false,
        suggestedModelId: json['suggestedModelId']?.toString(),
      );
}

/// Respuesta de `POST /dishes/photos`.
class UploadedPhoto {
  const UploadedPhoto({required this.photoId, required this.photoUrl});

  final String photoId;
  final String photoUrl;

  factory UploadedPhoto.fromJson(Map<String, dynamic> json) => UploadedPhoto(
        photoId: json['photoId']?.toString() ?? '',
        photoUrl: json['photoUrl'] as String? ?? '',
      );
}
