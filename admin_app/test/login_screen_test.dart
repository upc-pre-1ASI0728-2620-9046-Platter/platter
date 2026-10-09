import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:platter_admin/main.dart';
import 'package:platter_admin/state/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Session> pumpApp(WidgetTester tester) async {
    final session = Session(
      baseUrl: 'http://api.test/api/v1',
      httpClient: MockClient((_) async => http.Response('', 500)),
    );
    await session.load();
    await tester.pumpWidget(PlatterAdminApp(session: session));
    await tester.pumpAndSettle();
    return session;
  }

  testWidgets('sin sesión muestra el login', (tester) async {
    final session = await pumpApp(tester);
    expect(session.isAuthenticated, isFalse);
    expect(find.text('Platter'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('¿Nuevo en Platter? Registra tu restaurante'), findsOneWidget);
  });

  testWidgets('valida campos vacíos y correo inválido', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();
    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('login-email')), 'no-es-correo');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump();
    expect(find.text('Correo no válido'), findsOneWidget);
  });

  testWidgets('un error de conexión muestra un mensaje amigable', (tester) async {
    final session = Session(
      baseUrl: 'http://api.test/api/v1',
      httpClient: MockClient((_) async => throw http.ClientException('sin red')),
    );
    await session.load();
    await tester.pumpWidget(PlatterAdminApp(session: session));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login-email')), 'rosa@example.pe');
    await tester.enterText(find.byKey(const Key('login-password')), 'secreta123');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo conectar con el servidor. Verifica tu conexión.'), findsOneWidget);
  });
}
