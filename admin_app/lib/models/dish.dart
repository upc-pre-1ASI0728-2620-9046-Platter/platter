import 'catalog.dart';
import 'json_utils.dart';

enum DishStatus {
  draft,
  published;

  static DishStatus fromJson(Object? v) =>
      v == 'PUBLISHED' ? DishStatus.published : DishStatus.draft;

  String get label => this == DishStatus.published ? 'Publicado' : 'Borrador';
}

class CalorieRange {
  const CalorieRange({this.min, this.max});

  final int? min;
  final int? max;

  static CalorieRange? fromJson(Object? json) {
    final m = asMap(json);
    if (m == null) return null;
    return CalorieRange(min: asIntOrNull(m['min']), max: asIntOrNull(m['max']));
  }

  bool get isEmpty => min == null && max == null;
}

class Dish {
  const Dish({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.priceSoles,
    this.ingredients = const [],
    this.allergens = const [],
    this.allergenFree = false,
    this.kitchenNotes,
    this.calories,
    this.vegetarian = false,
    this.vegan = false,
    this.photoUrl,
    this.model,
    this.status = DishStatus.draft,
    this.available = true,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String category;
  final double priceSoles;
  final List<String> ingredients;
  final List<String> allergens;
  final bool allergenFree;
  final String? kitchenNotes;
  final CalorieRange? calories;
  final bool vegetarian;
  final bool vegan;
  final String? photoUrl;
  final Model3D? model;
  final DishStatus status;
  final bool available;
  final DateTime? updatedAt;

  factory Dish.fromJson(Map<String, dynamic> json) {
    final model = asMap(json['model']);
    return Dish(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String? ?? '',
      priceSoles: asDouble(json['priceSoles']),
      ingredients: asStringList(json['ingredients']),
      allergens: asStringList(json['allergens']),
      allergenFree: json['allergenFree'] as bool? ?? false,
      kitchenNotes: json['kitchenNotes'] as String?,
      calories: CalorieRange.fromJson(json['calories']),
      vegetarian: json['vegetarian'] as bool? ?? false,
      vegan: json['vegan'] as bool? ?? false,
      photoUrl: json['photoUrl'] as String?,
      model: model == null ? null : Model3D.fromJson(model),
      status: DishStatus.fromJson(json['status']),
      available: json['available'] as bool? ?? true,
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }

  Dish copyWith({bool? available}) => Dish(
        id: id,
        name: name,
        description: description,
        category: category,
        priceSoles: priceSoles,
        ingredients: ingredients,
        allergens: allergens,
        allergenFree: allergenFree,
        kitchenNotes: kitchenNotes,
        calories: calories,
        vegetarian: vegetarian,
        vegan: vegan,
        photoUrl: photoUrl,
        model: model,
        status: status,
        available: available ?? this.available,
        updatedAt: updatedAt,
      );
}

/// Cuerpo de `POST /dishes` y `PUT /dishes/{id}`.
class DishInput {
  const DishInput({
    required this.name,
    this.description,
    required this.category,
    required this.priceSoles,
    this.ingredients = const [],
    this.allergens = const [],
    this.allergenFree = false,
    this.kitchenNotes,
    this.caloriesMin,
    this.caloriesMax,
    this.vegetarian = false,
    this.vegan = false,
    this.photoId,
    this.modelId,
  });

  final String name;
  final String? description;
  final String category;
  final double priceSoles;
  final List<String> ingredients;
  final List<String> allergens;
  final bool allergenFree;
  final String? kitchenNotes;
  final int? caloriesMin;
  final int? caloriesMax;
  final bool vegetarian;
  final bool vegan;

  /// Solo se envía cuando hay una foto nueva; al editar, omitirlo conserva la actual.
  final String? photoId;

  /// `null` = el backend asigna el modelo por defecto de la categoría.
  final String? modelId;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'category': category,
        'priceSoles': priceSoles,
        'ingredients': ingredients,
        'allergens': allergens,
        'allergenFree': allergenFree,
        'kitchenNotes': kitchenNotes,
        'caloriesMin': caloriesMin,
        'caloriesMax': caloriesMax,
        'vegetarian': vegetarian,
        'vegan': vegan,
        if (photoId != null) 'photoId': photoId,
        'modelId': modelId,
      };
}
