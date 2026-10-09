import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/platter_api.dart';
import '../config.dart';
import '../models/models.dart';

/// Estado de sesión del dueño: JWT, usuario y restaurante.
///
/// Persiste el token y su vencimiento en `shared_preferences`. Cualquier 401
/// de una petición autenticada cierra la sesión.
class Session extends ChangeNotifier {
  Session({String baseUrl = AppConfig.apiBaseUrl, http.Client? httpClient}) {
    api = PlatterApi(ApiClient(
      baseUrl: baseUrl,
      tokenProvider: () => token,
      onUnauthorized: () => logout(expired: true),
      httpClient: httpClient,
    ));
  }

  static const _kToken = 'auth.token';
  static const _kExpiresAt = 'auth.expiresAt';
  static const _kUser = 'auth.user';
  static const _kRestaurant = 'auth.restaurant';

  late final PlatterApi api;

  String? _token;
  DateTime? _expiresAt;
  AppUser? user;
  Restaurant? restaurant;
  bool _loaded = false;

  /// `true` si la última salida fue por expiración / 401 (para avisar al usuario).
  bool expiredFlag = false;
  Timer? _expiryTimer;

  bool get isLoaded => _loaded;

  String? get token {
    if (_token == null || _expiresAt == null) return null;
    return DateTime.now().isBefore(_expiresAt!) ? _token : null;
  }

  bool get isAuthenticated => token != null;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kToken);
      _expiresAt = DateTime.tryParse(prefs.getString(_kExpiresAt) ?? '');
      final u = prefs.getString(_kUser);
      final r = prefs.getString(_kRestaurant);
      if (u != null) user = AppUser.fromJson(jsonDecode(u) as Map<String, dynamic>);
      if (r != null) restaurant = Restaurant.fromJson(jsonDecode(r) as Map<String, dynamic>);
    } catch (_) {
      _token = null;
    }
    if (!isAuthenticated) {
      await _clear();
    } else {
      _scheduleExpiry();
    }
    _loaded = true;
    notifyListeners();
    if (isAuthenticated) unawaited(refreshRestaurant());
  }

  Future<void> login(String email, String password) async {
    await _start(await api.login(email, password));
  }

  Future<void> register({
    required String ownerName,
    required String email,
    required String password,
    required String restaurantName,
    String? address,
  }) async {
    await _start(await api.register(
      ownerName: ownerName,
      email: email,
      password: password,
      restaurantName: restaurantName,
      address: address,
    ));
  }

  Future<void> _start(AuthResponse auth) async {
    _token = auth.token;
    _expiresAt = DateTime.now().add(Duration(seconds: auth.expiresIn));
    user = auth.user;
    restaurant = auth.restaurant;
    expiredFlag = false;
    _scheduleExpiry();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, auth.token);
    await prefs.setString(_kExpiresAt, _expiresAt!.toIso8601String());
    await prefs.setString(_kUser, jsonEncode(auth.user.toJson()));
    await prefs.setString(_kRestaurant, jsonEncode(auth.restaurant.toJson()));
    notifyListeners();
  }

  /// Vuelve a leer el restaurante (contadores de mesas/platos, plan).
  Future<void> refreshRestaurant() async {
    try {
      setRestaurant(await api.restaurant());
    } catch (_) {
      // Silencioso: la UI sigue con el último valor conocido.
    }
  }

  void setRestaurant(Restaurant r) {
    restaurant = r;
    SharedPreferences.getInstance()
        .then((p) => p.setString(_kRestaurant, jsonEncode(r.toJson())))
        .ignore();
    notifyListeners();
  }

  Future<void> logout({bool expired = false}) async {
    if (_token == null) return;
    expiredFlag = expired;
    await _clear();
    notifyListeners();
  }

  Future<void> _clear() async {
    _expiryTimer?.cancel();
    _token = null;
    _expiresAt = null;
    user = null;
    restaurant = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kExpiresAt);
    await prefs.remove(_kUser);
    await prefs.remove(_kRestaurant);
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final at = _expiresAt;
    if (at == null) return;
    _expiryTimer = Timer(at.difference(DateTime.now()), () => logout(expired: true));
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    api.client.close();
    super.dispose();
  }
}

/// Expone la [Session] al árbol de widgets.
class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({super.key, required Session session, required super.child})
      : super(notifier: session);

  static Session of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;

  /// Sin suscribirse a cambios (para callbacks).
  static Session read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}
