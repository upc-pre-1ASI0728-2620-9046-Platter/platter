/// Utilidades pequeñas para leer JSON de forma tolerante.
double asDouble(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? fallback : fallback);

double? asDoubleOrNull(Object? v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

int asInt(Object? v, [int fallback = 0]) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? fallback : fallback);

int? asIntOrNull(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

List<String> asStringList(Object? v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];

Map<String, dynamic>? asMap(Object? v) => v is Map<String, dynamic> ? v : null;
