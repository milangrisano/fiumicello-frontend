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

/// Convierte una fecha ISO (el backend guarda en UTC) a la hora de BOGOTÁ
/// (UTC-5). Si la fecha no trae zona (ej. "2026-09-18T00:00:00" sin Z), se
/// interpreta como ya local y se devuelve igual. Útil para mostrar horas en
/// la zona horaria de Colombia.
DateTime fechaBogota(String iso) {
  if (iso.endsWith('Z')) {
    return DateTime.parse(iso).toUtc().add(const Duration(hours: -5));
  }
  return DateTime.parse(iso);
}

/// Formatea ISO → hora HH:MM de Bogotá.
String horaBogota(dynamic iso) {
  if (iso == null) return '';
  try {
    final d = fechaBogota(iso.toString());
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}

/// Formatea ISO → fecha DD/MM (de Bogotá).
String fechaCortaBogota(dynamic iso) {
  if (iso == null) return '';
  try {
    final d = fechaBogota(iso.toString());
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}

/// Formatea ISO → fecha DD/MM/AAAA (de Bogotá).
String fechaCompletaBogota(dynamic iso) {
  if (iso == null) return '';
  try {
    final d = fechaBogota(iso.toString());
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  } catch (_) {
    return iso.toString();
  }
}