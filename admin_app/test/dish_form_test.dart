import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:platter_admin/main.dart';
import 'package:platter_admin/models/models.dart';
import 'package:platter_admin/screens/dishes/dish_form_screen.dart';
import 'package:platter_admin/state/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  final requests = <String>[];

  setUp(() {
    requests.clear();
    SharedPreferences.setMockInitialValues({
      'auth.token': 'jwt',
      'auth.expiresAt': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    });
  });

  Future<Session> pumpForm(WidgetTester tester, DishFormSeed seed) async {
    final session = Session(
      baseUrl: 'http://api.test/api/v1',
      httpClient: MockClient((req) async {
        final key = '${req.method} ${req.url.path.replaceFirst('/api/v1', '')}';
        requests.add(key);
        return switch (key) {
          'GET /restaurant' => _json({'id': 'r1', 'name': 'La Picantería', 'tableCount': 0, 'dishCount': 0}),
          'GET /allergens' => _json([
              {'code': 'FISH', 'label': 'Pescado', 'icon': '🐟'},
              {'code': 'MILK', 'label': 'Leche', 'icon': '🥛'},
            ]),
          'GET /categories' => _json(['Ceviches', 'Criollos']),
          'GET /models' => _json([
              {
                'id': 'm1',
                'name': 'Plato hondo',
                'category': 'Ceviches',
                'glbUrl': '/assets/models/m1.glb',
                'dimensions': {'widthM': 0.28, 'depthM': 0.28, 'heightM': 0.05},
              },
            ]),
          'POST /dishes' => _json({
              'id': 'd1',
              'name': 'Ceviche',
              'category': 'Ceviches',
              'priceSoles': 30,
              'status': 'DRAFT',
              'available': true,
            }, 201),
          'POST /dishes/d1/publish' => _json({
              'code': 'DISH_NOT_PUBLISHABLE',
              'message': 'No publicable',
              'details': {'photo': 'Agrega una foto del plato'},
            }, 422),
          _ => _json({'code': 'NOT_FOUND', 'message': 'no'}, 404),
        };
      }),
    );
    await session.load();
    expect(session.isAuthenticated, isTrue);
    await tester.pumpWidget(SessionScope(
      session: session,
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: DishFormScreen.create(seed: seed),
      ),
    ));
    await tester.pumpAndSettle();
    return session;
  }

  /// Desmonta el árbol y cancela el temporizador de expiración del JWT.
  Future<void> teardown(WidgetTester tester, Session session) async {
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  }

  testWidgets('prellena con las sugerencias de la IA y el modelo sugerido', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await pumpForm(
      tester,
      DishFormSeed(
        photoId: 'p1',
        analysis: Analysis.fromJson({
          'photoId': 'p1',
          'suggestedName': 'Ceviche',
          'description': 'Pescado en leche de tigre',
          'category': 'Ceviches',
          'ingredients': ['pescado', 'limón'],
          'allergens': ['FISH'],
          'estimatedCalories': {'min': 300, 'max': 400},
          'confidence': 0.9,
          'lowConfidence': false,
          'suggestedModelId': 'm1',
        }),
      ),
    );
    expect(find.text('Sugerencias generadas con IA'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Ceviche'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'limón'), findsOneWidget);
    final fish = tester.widget<FilterChip>(find.widgetWithText(FilterChip, '🐟 Pescado'));
    expect(fish.selected, isTrue);
    expect(find.text('28 × 28 × 5 cm'), findsOneWidget);
    await teardown(tester, session);
  });

  testWidgets('muestra los motivos de un 422 DISH_NOT_PUBLISHABLE', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await pumpForm(tester, const DishFormSeed(notice: 'El análisis con IA no está disponible ahora.'));
    expect(find.text('El análisis con IA no está disponible ahora.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre del plato *'), 'Ceviche');
    await tester.enterText(find.widgetWithText(TextFormField, 'Categoría *'), 'Ceviches');
    await tester.enterText(find.widgetWithText(TextFormField, 'Precio *'), '30');
    await tester.tap(find.text('Libre de alérgenos'));
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();

    expect(requests, containsAllInOrder(['POST /dishes', 'POST /dishes/d1/publish']));
    expect(find.text('Se guardó como borrador, pero aún no se puede publicar:'), findsOneWidget);
    expect(find.text('• Foto: Agrega una foto del plato'), findsOneWidget);
    await teardown(tester, session);
  });
}
