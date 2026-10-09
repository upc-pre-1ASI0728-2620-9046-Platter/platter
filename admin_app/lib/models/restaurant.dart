import 'json_utils.dart';
import 'plan.dart';

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    this.address,
    this.plan,
    this.tableCount = 0,
    this.dishCount = 0,
  });

  final String id;
  final String name;
  final String? address;
  final Plan? plan;
  final int tableCount;
  final int dishCount;

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    final plan = asMap(json['plan']);
    return Restaurant(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
      plan: plan == null ? null : Plan.fromJson(plan),
      tableCount: asInt(json['tableCount']),
      dishCount: asInt(json['dishCount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'plan': plan?.toJson(),
        'tableCount': tableCount,
        'dishCount': dishCount,
      };
}
