/// Centralized money formatting helper.
///
/// Formats a numeric value as Colombian-Peso style with thousand separators
/// using dots and a leading dollar sign (e.g. `$1.500`).
///
/// Accepts `num`, or a numeric-looking string (Postgres `numeric` columns
/// come over the API as strings, e.g. "20200.0000"). Non-numeric input yields
/// `$0`.
String money(dynamic value) {
  double n;
  if (value is num) {
    n = value.toDouble();
  } else if (value is String) {
    n = double.tryParse(value.trim()) ?? 0.0;
  } else {
    n = 0.0;
  }
  final s = n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => '.',
      );
  return '\$$s';
}