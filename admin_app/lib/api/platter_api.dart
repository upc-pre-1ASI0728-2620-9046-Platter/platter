import 'dart:typed_data';

import '../models/models.dart';
import 'api_client.dart';

/// Endpoints tipados de la API v1 (ver `docs/api-contract.md`).
class PlatterApi {
  PlatterApi(this.client);

  final ApiClient client;

  static List<T> _list<T>(Object? json, T Function(Map<String, dynamic>) f) =>
      (json as List? ?? const []).whereType<Map<String, dynamic>>().map(f).toList();

  // ---- IAM ----
  Future<AuthResponse> login(String email, String password) async => AuthResponse.fromJson(
      await client.post('/auth/login', {'email': email, 'password': password}));

  Future<AuthResponse> register({
    required String ownerName,
    required String email,
    required String password,
    required String restaurantName,
    String? address,
  }) async =>
      AuthResponse.fromJson(await client.post('/auth/register', {
        'ownerName': ownerName,
        'email': email,
        'password': password,
        'restaurantName': restaurantName,
        if (address != null && address.isNotEmpty) 'address': address,
      }));

  // ---- Restaurante y planes ----
  Future<List<Plan>> plans() async => _list(await client.get('/plans'), Plan.fromJson);

  Future<Restaurant> restaurant() async => Restaurant.fromJson(await client.get('/restaurant'));

  Future<Restaurant> updateRestaurant({required String name, String? address}) async =>
      Restaurant.fromJson(await client.put('/restaurant', {'name': name, 'address': address}));

  Future<Restaurant> changePlan(String planCode) async =>
      Restaurant.fromJson(await client.put('/restaurant/plan', {'planCode': planCode}));

  // ---- Mesas ----
  Future<List<DiningTable>> tables() async =>
      _list(await client.get('/tables'), DiningTable.fromJson);

  Future<List<DiningTable>> createTablesBatch({
    required int from,
    required int to,
    required String prefix,
  }) async =>
      _list(await client.post('/tables/batch', {'from': from, 'to': to, 'prefix': prefix}),
          DiningTable.fromJson);

  Future<DiningTable> createTable(String label) async =>
      DiningTable.fromJson(await client.post('/tables', {'label': label}));

  Future<DiningTable> setTableActive(String id, bool active) async =>
      DiningTable.fromJson(await client.patch('/tables/$id', {'active': active}));

  String tableQrUrl(String id, {int size = 512}) =>
      client.uri('/tables/$id/qr.png', {'size': '$size'}).toString();

  /// URL de la plantilla PDF con `access_token` para abrirla en un navegador externo.
  Uri qrSheetUri({List<String>? ids, required String token}) => client.uri('/tables/qr-sheet.pdf', {
        if (ids != null && ids.isNotEmpty) 'ids': ids.join(','),
        'access_token': token,
      });

  // ---- Catálogo ----
  Future<List<Allergen>> allergens() async =>
      _list(await client.get('/allergens'), Allergen.fromJson);

  Future<List<String>> categories() async =>
      ((await client.get('/categories')) as List? ?? const []).map((e) => e.toString()).toList();

  Future<List<Model3D>> models() async => _list(await client.get('/models'), Model3D.fromJson);

  Future<UploadedPhoto> uploadPhoto(Uint8List bytes, {required String fileName, required String contentType}) async =>
      UploadedPhoto.fromJson(await client.multipart(
        '/dishes/photos',
        fileField: 'image',
        fileBytes: bytes,
        fileName: fileName,
        fileContentType: contentType,
        timeout: const Duration(seconds: 60),
      ));

  Future<Analysis> analyzePhoto(String photoId) async => Analysis.fromJson(await client.multipart(
        '/dishes/analyze',
        fields: {'photoId': photoId},
        timeout: const Duration(seconds: 90),
      ));

  Future<List<Dish>> dishes() async => _list(await client.get('/dishes'), Dish.fromJson);

  Future<Dish> dish(String id) async => Dish.fromJson(await client.get('/dishes/$id'));

  Future<Dish> createDish(DishInput input) async =>
      Dish.fromJson(await client.post('/dishes', input.toJson()));

  Future<Dish> updateDish(String id, DishInput input) async =>
      Dish.fromJson(await client.put('/dishes/$id', input.toJson()));

  Future<Dish> publishDish(String id) async => Dish.fromJson(await client.post('/dishes/$id/publish'));

  Future<Dish> setDishAvailability(String id, bool available) async =>
      Dish.fromJson(await client.patch('/dishes/$id/availability', {'available': available}));

  Future<void> deleteDish(String id) => client.delete('/dishes/$id');

  // ---- Analítica ----
  Future<AnalyticsSummary> analyticsSummary({int days = 7}) async => AnalyticsSummary.fromJson(
      await client.get('/analytics/summary', query: {'days': '$days'}));
}
