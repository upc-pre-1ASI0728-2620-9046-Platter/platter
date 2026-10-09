import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_exception.dart';

/// Envoltura mínima sobre `package:http`: agrega el JWT, decodifica JSON
/// y convierte las respuestas de error en [ApiException].
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokenProvider,
    this.onUnauthorized,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String? Function() tokenProvider;

  /// Se invoca cuando una petición autenticada recibe 401.
  final void Function()? onUnauthorized;
  final http.Client _http;

  static const _timeout = Duration(seconds: 30);

  Uri uri(String path, [Map<String, String>? query]) {
    final u = Uri.parse('$baseUrl$path');
    return (query == null || query.isEmpty) ? u : u.replace(queryParameters: query);
  }

  /// Convierte una URL devuelta por la API (absoluta o relativa) en absoluta.
  String resolveUrl(String url) {
    final parsed = Uri.parse(url);
    if (parsed.hasScheme) return url;
    final base = Uri.parse(baseUrl);
    if (url.startsWith('/')) return base.resolve(url).toString();
    return Uri.parse('$baseUrl/').resolve(url).toString();
  }

  Map<String, String> get authHeaders {
    final token = tokenProvider();
    return token == null ? {} : {'Authorization': 'Bearer $token'};
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);

  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);

  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Envía `multipart/form-data` con campos de texto y, opcionalmente, una imagen.
  Future<dynamic> multipart(
    String path, {
    Map<String, String> fields = const {},
    String? fileField,
    Uint8List? fileBytes,
    String? fileName,
    String? fileContentType,
    Duration timeout = _timeout,
  }) async {
    final request = http.MultipartRequest('POST', uri(path))
      ..headers.addAll(authHeaders)
      ..headers['Accept'] = 'application/json'
      ..fields.addAll(fields);
    if (fileField != null && fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: fileName ?? 'foto.jpg',
        contentType: fileContentType != null ? MediaType.parse(fileContentType) : null,
      ));
    }
    final hadToken = request.headers.containsKey('Authorization');
    final streamed = await _http.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed);
    return _handle(response, hadToken);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final headers = {
      ...authHeaders,
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json; charset=utf-8',
    };
    final request = http.Request(method, uri(path, query))..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _http.send(request).timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    return _handle(response, headers.containsKey('Authorization'));
  }

  dynamic _handle(http.Response response, bool hadToken) {
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body.trim().isEmpty) return null;
      return jsonDecode(body);
    }
    if (response.statusCode == 401 && hadToken) {
      onUnauthorized?.call();
    }
    throw ApiException.fromResponse(response.statusCode, body);
  }

  void close() => _http.close();
}
