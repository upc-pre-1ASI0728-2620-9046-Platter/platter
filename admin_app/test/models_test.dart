import 'package:flutter_test/flutter_test.dart';
import 'package:platter_admin/models/models.dart';

void main() {
  group('Dish.fromJson', () {
    test('parsea un plato completo del contrato', () {
      final dish = Dish.fromJson({
        'id': 'd1',
        'name': 'Ceviche clásico',
        'description': 'Pescado fresco en leche de tigre',
        'category': 'Ceviches',
        'priceSoles': 35.5,
        'ingredients': ['pescado', 'limón', 'cebolla'],
        'allergens': ['FISH'],
        'allergenFree': false,
        'kitchenNotes': 'Misma tabla que mariscos',
        'calories': {'min': 300, 'max': 450},
        'vegetarian': false,
        'vegan': false,
        'photoUrl': '/api/v1/media/photos/p1',
        'model': {
          'id': 'm1',
          'name': 'Plato hondo',
          'category': 'Ceviches',
          'glbUrl': '/api/v1/assets/models/m1.glb',
          'dimensions': {'widthM': 0.28, 'depthM': 0.28, 'heightM': 0.05},
        },
        'status': 'PUBLISHED',
        'available': false,
        'updatedAt': '2026-10-01T12:00:00Z',
      });
      expect(dish.name, 'Ceviche clásico');
      expect(dish.priceSoles, 35.5);
      expect(dish.ingredients, hasLength(3));
      expect(dish.allergens, ['FISH']);
      expect(dish.calories!.min, 300);
      expect(dish.calories!.max, 450);
      expect(dish.status, DishStatus.published);
      expect(dish.status.label, 'Publicado');
      expect(dish.available, isFalse);
      expect(dish.model!.dimensions!.centimeters, '28 × 28 × 5 cm');
      expect(dish.updatedAt, DateTime.utc(2026, 10, 1, 12));
    });

    test('tolera nulos (borrador sin foto, sin modelo ni calorías)', () {
      final dish = Dish.fromJson({
        'id': 'd2',
        'name': 'Lomo saltado',
        'category': 'Criollos',
        'priceSoles': 28,
        'calories': null,
        'photoUrl': null,
        'model': null,
        'status': 'DRAFT',
        'available': true,
      });
      expect(dish.priceSoles, 28.0);
      expect(dish.calories, isNull);
      expect(dish.model, isNull);
      expect(dish.ingredients, isEmpty);
      expect(dish.status, DishStatus.draft);
    });
  });

  test('DishInput.toJson omite photoId nulo y conserva modelId nulo', () {
    const input = DishInput(name: 'Pizza', category: 'Pizzas', priceSoles: 30, allergenFree: true);
    final json = input.toJson();
    expect(json.containsKey('photoId'), isFalse);
    expect(json.containsKey('modelId'), isTrue);
    expect(json['modelId'], isNull);
    expect(json['allergenFree'], isTrue);
    expect(json['priceSoles'], 30);

    final withPhoto = const DishInput(name: 'x', category: 'y', priceSoles: 1, photoId: 'p1').toJson();
    expect(withPhoto['photoId'], 'p1');
  });

  test('Analysis.fromJson', () {
    final a = Analysis.fromJson({
      'photoId': 'p1',
      'photoUrl': '/api/v1/media/photos/p1',
      'suggestedName': 'Ají de gallina',
      'description': 'Crema de ají amarillo con gallina deshilachada',
      'category': 'Criollos',
      'ingredients': ['gallina', 'ají amarillo', 'pan', 'leche'],
      'allergens': ['GLUTEN', 'MILK'],
      'estimatedCalories': {'min': 550, 'max': 700},
      'confidence': 0.87,
      'lowConfidence': false,
      'suggestedModelId': 'm2',
    });
    expect(a.suggestedName, 'Ají de gallina');
    expect(a.allergens, ['GLUTEN', 'MILK']);
    expect(a.estimatedCalories!.max, 700);
    expect(a.confidence, closeTo(0.87, 1e-9));
    expect(a.lowConfidence, isFalse);
    expect(a.suggestedModelId, 'm2');
  });

  test('AuthResponse y Plan ilimitado', () {
    final auth = AuthResponse.fromJson({
      'token': 'jwt',
      'expiresIn': 3600,
      'user': {'id': 'u1', 'name': 'Rosa', 'email': 'rosa@example.pe'},
      'restaurant': {
        'id': 'r1',
        'name': 'La Picantería',
        'address': null,
        'plan': {
          'code': 'PRO',
          'name': 'Pro',
          'priceSoles': 149,
          'maxTables': null,
          'maxDishes': null,
          'aiAnalysis': true,
        },
        'tableCount': 3,
        'dishCount': 12,
      },
    });
    expect(auth.token, 'jwt');
    expect(auth.user.email, 'rosa@example.pe');
    expect(auth.restaurant.plan!.maxTables, isNull);
    expect(auth.restaurant.plan!.aiAnalysis, isTrue);
    expect(auth.restaurant.dishCount, 12);
  });

  test('AnalyticsSummary.fromJson', () {
    final s = AnalyticsSummary.fromJson({
      'days': 30,
      'qrScans': 120,
      'dishViews': 340,
      'arLaunches': 80,
      'avgArSeconds': 42.5,
      'topDishes': [
        {'dishId': 'd1', 'name': 'Ceviche', 'views': 90, 'arLaunches': 30},
      ],
      'topTables': [
        {'label': 'Mesa 1', 'scans': 25},
      ],
    });
    expect(s.days, 30);
    expect(s.topDishes.single.name, 'Ceviche');
    expect(s.topTables.single.scans, 25);
  });
}
