import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_sections.dart';

/// Floating radial navigation (replaces the bottom NavigationBar on mobile).
///
/// A FloatingActionButton sits in the bottom-right corner. Tapping it toggles a
/// set of icon buttons that fan out in an arc of ~90° towards up-left. The arc
/// is INSET (angled so no icon touches the screen edges). Tapping an icon
/// navigates to its section. Each icon is a mini circular FAB.
///
/// The main FAB is DRAGGABLE (can be moved with a drag gesture) so it never
/// covers interactive elements (e.g. the "Borrar comanda" button at the bottom
/// when scrolled to the end). Its position is persisted across sessions.
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

  // Posición del FAB como offset desde la esquina inferior derecha de la
  // pantalla (right: _dx, bottom: _dy). Persistida en SharedPreferences.
  double _dx = 16;
  double _dy = 16;

  static const _fabSize = 56.0; // tamaño estándar de FloatingActionButton

  @override
  void initState() {
    super.initState();
    _cargarPosicion();
  }

  Future<void> _cargarPosicion() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dx = prefs.getDouble('radial_fab_dx') ?? 16;
      _dy = prefs.getDouble('radial_fab_dy') ?? 16;
    });
  }

  Future<void> _guardarPosicion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('radial_fab_dx', _dx);
    await prefs.setDouble('radial_fab_dy', _dy);
  }

  void _mover(double px, double py, double ancho, double alto) {
    // Clamp para que el FAB nunca quede parcialmente fuera de la pantalla.
    final maxRight = max(0.0, ancho - _fabSize - 4); // margen mínimo de 4
    final maxBottom = max(0.0, alto - _fabSize - 4);
    setState(() {
      _dx = px.clamp(0.0, maxRight);
      _dy = py.clamp(0.0, maxBottom);
    });
  }

  /// Íconos del arco distribuidos en un cuarto de círculo (0..90°) insertado.
  List<_ArcoIcono> _arcos(double radio, double m) {
    final n = widget.sections.length;
    final out = <_ArcoIcono>[];
    if (n == 0) return out;
    // Con botones mini de ~32px, para no montarse necesitamos separación angular.
    // Abrimos el arco en ~70° útiles (inset 10°) y usado radio moderado.
    final insetDeg = 10.0;
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
    final ancho = MediaQuery.of(context).size.width;
    final alto = MediaQuery.of(context).size.height;
    final radio = 130.0;
    final m = 130.0;
    final iconos = _arcos(radio, m);

    return Stack(children: [
      // FAB principal (offset desde abajo-derecha), toggle + GESTIÓN DE ARRASTRE.
      Positioned(
        right: _dx,
        bottom: _dy,
        child: GestureDetector(
          // Arrastrar mueve el FAB (offset se computa en coordenadas desde
          // abajo-derecha, por eso restamos el delta invertido).
          onPanUpdate: (detalles) {
            final px = _dx - detalles.delta.dx;
            final py = _dy - detalles.delta.dy;
            _mover(px, py, ancho, alto);
          },
          onPanEnd: (_) => _guardarPosicion(),
          child: FloatingActionButton(
            onPressed: () => setState(() => _abierto = !_abierto),
            mini: false,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: const CircleBorder(),
            child: Icon(_abierto ? Icons.close : Icons.add),
          ),
        ),
      ),
      // Íconos del arco (visibles al abrir), cada uno en su posición insetada.
      // Siguen al FAB: mismo offset de base.
      for (final ic in iconos)
        if (_abierto)
          Positioned(
            right: _dx + ic.x,
            bottom: _dy + ic.y,
            child: SizedBox(
              width: 36,
              height: 36,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.primary,
                shape: const CircleBorder(),
                onPressed: () {
                  setState(() => _abierto = false);
                  widget.onSelect(ic.index);
                },
                child: Icon(ic.icon, size: 18),
              ),
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
