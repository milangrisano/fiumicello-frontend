/// Centralized money formatting helper.
///
/// Formats a numeric value as Colombian-Peso style with thousand separators
/// using dots and a leading dollar sign (e.g. `$1.500`).
String money(dynamic value) {
  final n = value is num ? value.toDouble() : 0.0;
  final s = n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => '.',
      );
  return '\$$s';
}