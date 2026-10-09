/// "S/ 25.00"
String formatSoles(num amount) => 'S/ ${amount.toStringAsFixed(2)}';

/// "42 s", "1 min 05 s"
String formatSeconds(num seconds) {
  final total = seconds.round();
  if (total < 60) return '$total s';
  final m = total ~/ 60;
  final s = total % 60;
  return '$m min ${s.toString().padLeft(2, '0')} s';
}

/// Interpreta "25", "25.5" o "25,50" como número.
double? parseDecimal(String text) => double.tryParse(text.trim().replaceAll(',', '.'));
