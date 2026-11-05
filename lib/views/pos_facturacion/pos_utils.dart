import 'package:flutter/material.dart';

/// Helpers puros del POS (no dependen del State).

/// Convierte un valor (num o String numeric) a double.
double numVal(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0.0;
  return 0.0;
}

/// Calcula el precio dado el tamaño (personal/mediana/grande, 1/2 Mediana, ...)
/// o el precio base. Busca primero en los `tamanios[]` dinámicos de la carta
/// (por nombre, sin distinguir mayúsculas) y cae a las columnas fijas si no.
double precioDe(Map<String, dynamic> item, String? tamanio) {
  final t = (tamanio ?? '').trim();
  if (t.isNotEmpty) {
    final din = (item['tamanios'] as List?) ?? const <dynamic>[];
    final tl = t.toLowerCase();
    for (final opt in din.cast<Map<String, dynamic>>()) {
      if (('${opt['nombre']}').toLowerCase() == tl) {
        final v = numVal(opt['precio']);
        if (v > 0) return v;
      }
    }
    // Fallback: columnas fijas por nombre.
    if (tl == 'personal') {
      final v = numVal(item['precio_personal']);
      if (v > 0) return v;
    } else if (tl == 'mediana') {
      final v = numVal(item['precio_mediana']);
      if (v > 0) return v;
    } else if (tl == 'grande') {
      final v = numVal(item['precio_grande']);
      if (v > 0) return v;
    }
  }
  return numVal(item['precio'] ?? item['precio_personal']);
}

/// Ícono con el color primario del tema.
Icon appIcon(IconData i, {double size = 28, required BuildContext context}) {
  return Icon(i, size: size, color: Theme.of(context).colorScheme.primary);
}