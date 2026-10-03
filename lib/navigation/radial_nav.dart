import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_sections.dart';

/// Floating radial navigation (replaces the bottom NavigationBar on mobile).
///
/// A FloatingActionButton sits in the bottom-right corner. Tapping it toggles a
/// set of icon buttons that fan out in an arc. Each icon is a mini circular FAB
/// that navigates to its section.
///
/// The main FAB is DRAGGABLE (can be moved with a drag gesture) so it never
/// covers interactive elements. Its position is persisted across sessions.
///
/// The arc OPENS TOWARD THE FREE SPACE on the screen: the spread direction is
/// computed from the FAB's current position so it always fans into the area
/// with the most room, instead of a fixed up-left quadrant.
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
  static const _miniSize = 36.0; // tamaño de los mini-botones del arco
  static const _radio = 130.0; // radio del arco
  static const _spreadDeg = 68.0; // ángulo total del arco (≈70° útiles)

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
    final maxRight = max(0.0, ancho - _fabSize - 4);
    final maxBottom = max(0.0, alto - _fabSize - 4);
    setState(() {
      _dx = px.clamp(0.0, maxRight);
      _dy = py.clamp(0.0, maxBottom);
    });
  }

  /// Centro del FAB en coordenadas de pantalla (x crece a la derecha, y abajo).
  (double, double) _centroFab(double ancho, double alto) {
    final cx = ancho - _dx - _fabSize / 2;
    final cy = alto - _dy - _fabSize / 2;
    return (cx, cy);
  }

  /// Posición (left, top) de cada mini-botón del arco. Los iconos se reparten en
  /// un ángulo centrado en la dirección que va del FAB hacia el CENTRO de la
  /// pantalla, así el menú abre hacia el espacio libre (sin salirse de la vista).
  List<({double left, double top, int index, IconData icon})> _iconos(
      double ancho, double alto) {
    final n = widget.sections.length;
    final out = <({double left, double top, int index, IconData icon})>[];
    if (n == 0) return out;

    final (cx, cy) = _centroFab(ancho, alto);
    final centroX = ancho / 2;
    final centroY = alto / 2;

    // Dirección base (grados) del FAB hacia el centro de la pantalla.
    // 0° = derecha, 90° = abajo (coordenadas de pantalla, y hacia abajo).
    var baseAng = atan2(centroY - cy, centroX - cx) * 180 / pi;

    // Distribuir los iconos a lo largo del rango centrado en baseAng.
    for (int i = 0; i < n; i++) {
      final t = n == 1 ? 0.5 : (i / (n - 1));
      final ang = baseAng - _spreadDeg / 2 + _spreadDeg * t;
      final rad = ang * pi / 180;
      final ix = cx + _radio * cos(rad);
      final iy = cy + _radio * sin(rad);
      out.add((
        left: (ix - _miniSize / 2).clamp(0.0, max(0.0, ancho - _miniSize)),
        top: (iy - _miniSize / 2).clamp(0.0, max(0.0, alto - _miniSize)),
        index: widget.sections[i].index,
        icon: widget.sections[i].icon,
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final alto = MediaQuery.of(context).size.height;
    final iconos = _iconos(ancho, alto);

    return Stack(children: [
      // FAB principal (offset desde abajo-derecha), toggle + GESTIÓN DE ARRASTRE.
      Positioned(
        right: _dx,
        bottom: _dy,
        child: GestureDetector(
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
      // Íconos del arco (visibles al abrir), en su posición según el espacio libre.
      for (final ic in iconos)
        if (_abierto)
          Positioned(
            left: ic.left,
            top: ic.top,
            child: SizedBox(
              width: _miniSize,
              height: _miniSize,
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
