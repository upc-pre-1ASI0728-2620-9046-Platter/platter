import 'json_utils.dart';

class TopDish {
  const TopDish({required this.dishId, required this.name, required this.views, required this.arLaunches});

  final String dishId;
  final String name;
  final int views;
  final int arLaunches;

  factory TopDish.fromJson(Map<String, dynamic> json) => TopDish(
        dishId: json['dishId']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        views: asInt(json['views']),
        arLaunches: asInt(json['arLaunches']),
      );
}

class TopTable {
  const TopTable({required this.label, required this.scans});

  final String label;
  final int scans;

  factory TopTable.fromJson(Map<String, dynamic> json) =>
      TopTable(label: json['label'] as String? ?? '', scans: asInt(json['scans']));
}

class AnalyticsSummary {
  const AnalyticsSummary({
    required this.days,
    required this.qrScans,
    required this.dishViews,
    required this.arLaunches,
    required this.avgArSeconds,
    this.topDishes = const [],
    this.topTables = const [],
  });

  final int days;
  final int qrScans;
  final int dishViews;
  final int arLaunches;
  final double avgArSeconds;
  final List<TopDish> topDishes;
  final List<TopTable> topTables;

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) => AnalyticsSummary(
        days: asInt(json['days'], 7),
        qrScans: asInt(json['qrScans']),
        dishViews: asInt(json['dishViews']),
        arLaunches: asInt(json['arLaunches']),
        avgArSeconds: asDouble(json['avgArSeconds']),
        topDishes: (json['topDishes'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TopDish.fromJson)
            .toList(),
        topTables: (json['topTables'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TopTable.fromJson)
            .toList(),
      );
}
