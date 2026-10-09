/// Mesa del restaurante (`Table` en el contrato; renombrada para no chocar
/// con el widget `Table` de Flutter).
class DiningTable {
  const DiningTable({
    required this.id,
    required this.label,
    required this.token,
    required this.active,
    required this.menuUrl,
  });

  final String id;
  final String label;
  final String token;
  final bool active;
  final String menuUrl;

  factory DiningTable.fromJson(Map<String, dynamic> json) => DiningTable(
        id: json['id']?.toString() ?? '',
        label: json['label'] as String? ?? '',
        token: json['token'] as String? ?? '',
        active: json['active'] as bool? ?? true,
        menuUrl: json['menuUrl'] as String? ?? '',
      );

  DiningTable copyWith({bool? active}) => DiningTable(
        id: id,
        label: label,
        token: token,
        active: active ?? this.active,
        menuUrl: menuUrl,
      );
}
