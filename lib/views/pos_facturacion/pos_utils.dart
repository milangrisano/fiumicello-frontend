import 'package:flutter/material.dart';

/// Helpers puros del POS (no dependen del State).

/// Convierte un valor (num o String numeric) a double.
double numVal(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0.0;
  return 0.0;
}

/// Calcula el precio dado el tamaño (personal/mediana/grande) o el precio base.
double precioDe(Map<String, dynamic> item, String? tamanio) {
  final t = tamanio?.toLowerCase() ?? '';
  if (t == 'personal') return numVal(item['precio_personal']);
  if (t == 'mediana') return numVal(item['precio_mediana']);
  if (t == 'grande') return numVal(item['precio_grande']);
  return numVal(item['precio'] ?? item['precio_personal']);
}

/// Ícono con el color primario del tema.
Icon appIcon(IconData i, {double size = 28, required BuildContext context}) {
  return Icon(i, size: size, color: Theme.of(context).colorScheme.primary);
}