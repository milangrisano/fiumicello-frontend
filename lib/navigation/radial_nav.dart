import 'dart:math';
import 'package:flutter/material.dart';
import 'app_sections.dart';

/// Floating radial navigation (replaces the bottom NavigationBar on mobile).
///
/// A FloatingActionButton sits in the bottom-right corner. Tapping it toggles a
/// set of icon buttons that fan out in an arc of ~90° towards up-left. The arc
/// is INSET (angled so no icon touches the screen edges). Tapping an icon
/// navigates to its section. Each icon is a mini circular FAB.
class RadialNav extends StatefulWidget {
  final List<SectionEntry> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const RadialNav({
    super.key,
    required this.sections,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  State<RadialNav> createState() => _RadialNavState();
}

class _RadialNavState extends State<RadialNav> {
  bool _abierto = false;

  /// Íconos del arco distribuidos en un cuarto de círculo (0..90°) insertado.
  List<_ArcoIcono> _arcos(double radio, double m) {
    final n = widget.sections.length;
    final out = <_ArcoIcono>[];
    if (n == 0) return out;
    // Ángulo inset FIJO en grados, para que ni el primer ni el último ícono
    // toquen los bordes (top y lateral). Con 5 íconos y margen ~22°, quedan
    // repartidos en 90-44 = ~46° útiles, bien separados.
    final insetDeg = m >= 200 ? 24.0 : (m >= 130 ? 18.0 : 14.0);
    final angMin = insetDeg;
    final angMax = 90.0 - insetDeg;
    for (int i = 0; i < n; i++) {
      final t = n == 1 ? 0.5 : (i / (n - 1));
      // ang: 0° = arriba, 90° = izquierda (arco hacia arriba-izquierda).
      final ang = angMin + (angMax - angMin) * t;
      final rad = ang * 3.14159265 / 180.0;
      out.add(_ArcoIcono(
        x: radio * sin(rad), // hacia la izquierda (ignora, ver posición)
        y: radio * cos(rad), // hacia arriba
        icon: widget.sections[i].icon,
        index: widget.sections[i].index,
        label: widget.sections[i].label,
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final radio = 170.0; // radio del arco (más grande para separar los íconos)
    final m = 130.0; // margen reservado para el FAB (esquina) + holgura
    final iconos = _arcos(radio, m);

    return Stack(children: [
      // FAB principal (esquina inferior derecha), toggle.
      Positioned(
        right: 16,
        bottom: 16,
        child: FloatingActionButton(
          onPressed: () => setState(() => _abierto = !_abierto),
          mini: false,
          shape: const CircleBorder(),
          child: Icon(_abierto ? Icons.close : Icons.add, color: Colors.white),
        ),
      ),
      // Íconos del arco (visibles al abrir), cada uno en su posición insetada.
      for (final ic in iconos)
        if (_abierto)
          Positioned(
            right: 16 + ic.x,
            bottom: 16 + ic.y,
            child: FloatingActionButton(
              mini: true,
              shape: const CircleBorder(),
              onPressed: () {
                setState(() => _abierto = false);
                widget.onSelect(ic.index);
              },
              child: Icon(ic.icon, color: Theme.of(context).colorScheme.primary),
            ),
          ),
    ]);
  }
}

class _ArcoIcono {
  final double x;
  final double y;
  final IconData icon;
  final int index;
  final String label;
  _ArcoIcono({required this.x, required this.y, required this.icon, required this.index, required this.label});
}