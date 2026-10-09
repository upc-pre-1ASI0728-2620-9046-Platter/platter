import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:platter_admin/api/api_client.dart';
import 'package:platter_admin/api/api_exception.dart';
import 'package:platter_admin/api/error_messages.dart';
import 'package:platter_admin/api/platter_api.dart';
import 'package:platter_admin/utils/format.dart';
import 'package:platter_admin/utils/image_validation.dart';

http.Response jsonResponse(Object body, int status) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  group('ApiException.fromResponse', () {
    test('parsea code, message y details', () {
      final e = ApiException.fromResponse(
        422,
        jsonEncode({
          'code': 'DISH_NOT_PUBLISHABLE',
          'message': 'El plato no se puede publicar',
          'details': {'photo': 'Falta la foto', 'allergens': 'Declara los alérgenos'},
        }),
      );
      expect(e.status, 422);
      expect(e.code, 'DISH_NOT_PUBLISHABLE');
      expect(e.message, 'El plato no se puede publicar');
      expect(e.fieldErrors, {'photo': 'Falta la foto', 'allergens': 'Declara los alérgenos'});
    });

    test('details no textuales no aparecen en fieldErrors', () {
      final e = ApiException.fromResponse(
        503,
        jsonEncode({
          'code': 'AI_UNAVAILABLE',
          'message': 'IA no disponible',
          'details': {'retryable': true, 'manualEntryAllowed': true},
        }),
      );
      expect(e.details['manualEntryAllowed'], isTrue);
      expect(e.fieldErrors, isEmpty);
      expect(friendlyError(e), contains('completar la ficha manualmente'));
    });

    test('cuerpo vacío o no JSON usa un código por defecto', () {
      final e = ApiException.fromResponse(502, '<html>Bad gateway</html>');
      expect(e.code, 'HTTP_502');
      expect(e.details, isEmpty);
      expect(ApiException.fromResponse(404, '').code, 'NOT_FOUND');
    });
  });

  group('ApiClient', () {
    test('envía el JWT y decodifica JSON UTF-8', () async {
      late http.Request seen;
      final client = ApiClient(
        baseUrl: 'http://api.test/api/v1',
        tokenProvider: () => 'abc',
        httpClient: MockClient((req) async {
          seen = req;
          return jsonResponse(['Entradas', 'Sánguches'], 200);
        }),
      );
      final cats = await PlatterApi(client).categories();
      expect(seen.url.toString(), 'http://api.test/api/v1/categories');
      expect(seen.headers['Authorization'], 'Bearer abc');
      expect(cats, ['Entradas', 'Sánguches']);
    });

    test('un 401 autenticado dispara onUnauthorized', () async {
      var loggedOut = false;
      final client = ApiClient(
        baseUrl: 'http://api.test/api/v1',
        tokenProvider: () => 'expired',
        onUnauthorized: () => loggedOut = true,
        httpClient: MockClient((_) async => jsonResponse({'code': 'UNAUTHORIZED', 'message': 'x'}, 401)),
      );
      await expectLater(client.get('/dishes'), throwsA(isA<ApiException>()));
      expect(loggedOut, isTrue);
    });

    test('un 401 de login (sin token) no cierra sesión', () async {
      var loggedOut = false;
      final client = ApiClient(
        baseUrl: 'http://api.test/api/v1',
        tokenProvider: () => null,
        onUnauthorized: () => loggedOut = true,
        httpClient: MockClient(
            (_) async => jsonResponse({'code': 'INVALID_CREDENTIALS', 'message': 'Credenciales inválidas'}, 401)),
      );
      try {
        await PlatterApi(client).login('a@b.pe', 'x');
        fail('debió lanzar');
      } on ApiException catch (e) {
        expect(e.code, 'INVALID_CREDENTIALS');
      }
      expect(loggedOut, isFalse);
    });

    test('analyze envía photoId como campo multipart y mapea 503', () async {
      late http.BaseRequest seen;
      String? body;
      final client = ApiClient(
        baseUrl: 'http://api.test/api/v1',
        tokenProvider: () => 't',
        httpClient: MockClient((req) async {
          seen = req;
          body = req.body;
          return jsonResponse({
            'code': 'AI_UNAVAILABLE',
            'message': 'No disponible',
            'details': {'retryable': true, 'manualEntryAllowed': true},
          }, 503);
        }),
      );
      try {
        await PlatterApi(client).analyzePhoto('photo-123');
        fail('debió lanzar');
      } on ApiException catch (e) {
        expect(e.status, 503);
        expect(e.code, 'AI_UNAVAILABLE');
      }
      expect(seen.url.path, '/api/v1/dishes/analyze');
      expect(seen.headers['content-type'], startsWith('multipart/form-data'));
      expect(body, contains('name="photoId"'));
      expect(body, contains('photo-123'));
    });

    test('resolveUrl acepta URLs absolutas y relativas', () {
      final client = ApiClient(baseUrl: 'http://api.test:8080/api/v1', tokenProvider: () => null);
      expect(client.resolveUrl('https://cdn.test/x.jpg'), 'https://cdn.test/x.jpg');
      expect(client.resolveUrl('/api/v1/media/photos/p1'), 'http://api.test:8080/api/v1/media/photos/p1');
      expect(client.resolveUrl('media/photos/p1'), 'http://api.test:8080/api/v1/media/photos/p1');
    });

    test('URL de la plantilla PDF incluye ids y access_token', () {
      final api = PlatterApi(ApiClient(baseUrl: 'http://api.test/api/v1', tokenProvider: () => null));
      final uri = api.qrSheetUri(ids: ['a', 'b'], token: 'jwt');
      expect(uri.path, '/api/v1/tables/qr-sheet.pdf');
      expect(uri.queryParameters, {'ids': 'a,b', 'access_token': 'jwt'});
      expect(api.qrSheetUri(token: 'jwt').queryParameters.containsKey('ids'), isFalse);
    });
  });

  group('utilidades', () {
    test('formatSoles y formatSeconds', () {
      expect(formatSoles(25), 'S/ 25.00');
      expect(formatSoles(12.5), 'S/ 12.50');
      expect(formatSeconds(42), '42 s');
      expect(formatSeconds(65.2), '1 min 05 s');
      expect(parseDecimal('25,50'), 25.5);
    });

    test('validación de fotos JPEG/PNG ≤ 10 MB', () {
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0]);
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]);
      final gif = Uint8List.fromList(ascii.encode('GIF89a......'));
      expect(detectImageMime(jpeg), 'image/jpeg');
      expect(detectImageMime(png), 'image/png');
      expect(validatePhotoBytes(jpeg), isNull);
      expect(validatePhotoBytes(png), isNull);
      expect(validatePhotoBytes(gif), contains('JPEG o PNG'));
      expect(validatePhotoBytes(jpeg, maxBytes: 4), contains('MB'));
    });
  });
}
