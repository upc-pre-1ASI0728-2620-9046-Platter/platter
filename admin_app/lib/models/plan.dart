import 'json_utils.dart';

class Plan {
  const Plan({
    required this.code,
    required this.name,
    required this.priceSoles,
    this.maxTables,
    this.maxDishes,
    required this.aiAnalysis,
  });

  /// `EMPRENDEDOR` | `CRECIMIENTO` | `PRO`.
  final String code;
  final String name;
  final double priceSoles;

  /// `null` = ilimitado.
  final int? maxTables;
  final int? maxDishes;
  final bool aiAnalysis;

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        priceSoles: asDouble(json['priceSoles']),
        maxTables: asIntOrNull(json['maxTables']),
        maxDishes: asIntOrNull(json['maxDishes']),
        aiAnalysis: json['aiAnalysis'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'priceSoles': priceSoles,
        'maxTables': maxTables,
        'maxDishes': maxDishes,
        'aiAnalysis': aiAnalysis,
      };
}
