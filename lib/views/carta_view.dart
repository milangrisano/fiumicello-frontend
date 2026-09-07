import 'package:flutter/material.dart';
import '../core/data/api_client.dart';
import '../core/utils/formatters.dart';
import '../core/theme/maratea_colors.dart';

/// Public Fiumicello menu (carta). Shown at the app's root `/` and as a section
/// for authenticated users. Structured: categories with items and prices.
/// Style: "Notte del Tirreno" (Alt. B) — dark deep-sea background, turquoise/gold
/// accents, pale-yellow size prices. ALL data (names, ingredients, prices) is
/// preserved exactly.
///
/// Responsive:
///  - <1200px (mobile/tablet): single column, logo 70px.
///  - >=1200px (desktop): two columns in rows
///    (Pizzas | Pizzas de la Casa) and (Lasagnas + Paninis | Bebidas), logo 140px.
class CartaView extends StatefulWidget {
  const CartaView({super.key});

  @override
  State<CartaView> createState() => _CartaViewState();
}

class _CartaViewState extends State<CartaView> {
  Map<String, dynamic>? _carta;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiClient.obtenerCarta();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _carta = r.data;
      } else {
        _error = r.message;
      }
    });
  }

  List<Map<String, dynamic>> get _categorias =>
      (_carta?['categorias'] as List? ?? []).cast<Map<String, dynamic>>();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Text('Error: $_error',
              style: const TextStyle(color: MarateaColors.pureWhite)));
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [MarateaColors.deepBlue, MarateaColors.volcanoBlack],
        ),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1200;
        final logoH = isDesktop ? 140.0 : 70.0;
        return ListView(
          padding: EdgeInsets.all(isDesktop ? 40 : 20),
          children: [
            // Header: the transparent brand logo floats directly on the dark sea.
            Center(
              child: Image.asset(
                'assets/logo_fiumicello.png',
                height: logoH == 140 ? 120 : 60,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            // Brand tagline line
            const Center(
              child: Text('MENÚ  ·  TRATTORIA',
                  style: TextStyle(
                      color: MarateaColors.goldenSand,
                      letterSpacing: 3,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 16),
            if (isDesktop)
              ..._buildDesktopLayout()
            else
              for (final c in _categorias) ..._categoriaWidgets(c),
            const SizedBox(height: 20),
            const Center(
              child: Text('¡BUON APPETITO!',
                  style: TextStyle(
                      color: MarateaColors.turquoise,
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 2)),
            ),
          ],
        );
      }),
    );
  }

  /// Desktop: arrange categories in the requested two-column rows.
  List<Widget> _buildDesktopLayout() {
    Map<String, dynamic>? byName(String n) {
      for (final c in _categorias) {
        if ((c['nombre'] ?? '') == n) return c;
      }
      return null;
    }

    final pizzas = byName('Pizzas');
    final rootCasa = byName('Pizzas de la Casa');
    final lasagnas = byName('Lasagnas');
    final paninis = byName('Paninis');
    final bebidas = byName('Bebidas');

    List<Widget> renderLeftCat(Map<String, dynamic>? a, Map<String, dynamic>? b) {
      final w = <Widget>[];
      if (a != null) w.addAll(_categoriaWidgets(a));
      if (b != null) w.addAll(_categoriaWidgets(b));
      return w;
    }

    Widget col(List<Widget> children) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: MarateaColors.volcanoBlack,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MarateaColors.turquoise.withOpacity(0.35), width: 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        );

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          col(renderLeftCat(pizzas, null)),
          col(renderLeftCat(rootCasa, null)),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          col(renderLeftCat(lasagnas, paninis)),
          col(renderLeftCat(bebidas, null)),
        ],
      ),
    ];
  }

  /// Widgets for a whole category: title (with turquoise filete) + grouped items.
  List<Widget> _categoriaWidgets(Map<String, dynamic> c) {
    return [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 22, height: 3, color: MarateaColors.turquoise),
          const SizedBox(width: 8),
          Text(
            c['nombre'] ?? '',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: MarateaColors.pureWhite,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      ..._renderItems(c['items'] as List? ?? const []),
      const SizedBox(height: 20),
    ];
  }

  /// Renders a category's items. When items carry a short "tipo" label in their
  /// description (e.g. beverages), they are grouped under a subheading.
  List<Widget> _renderItems(List<dynamic> items) {
    final itemsMap = items.cast<Map<String, dynamic>>();
    final tipos = <String>{};
    for (final it in itemsMap) {
      final d = (it['descripcion'] ?? '').toString().trim();
      if (d.isNotEmpty && d == d.split(' ').first || d.length <= 12) {
        tipos.add(d);
      }
    }
    if (tipos.length > 1) {
      final grupos = <String, List<Map<String, dynamic>>>{};
      for (final it in itemsMap) {
        final t = ((it['descripcion'] ?? '').toString().trim());
        (grupos[t] ??= []).add(it);
      }
      final curaciones = <Widget>[];
      grupos.forEach((tipo, its) {
        curaciones.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            tipo.isEmpty ? 'Otros' : _pluralize(tipo),
            style: const TextStyle(
              color: MarateaColors.goldenSand,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ));
        curaciones.addAll(its.map(_item));
      });
      return curaciones;
    }
    return itemsMap.map(_item).toList();
  }

  String _pluralize(String s) {
    const map = {
      'Cerveza': 'Cervezas',
      'Té': 'Tés',
      'Gaseosa': 'Gaseosas',
      'Agua': 'Aguas',
    };
    return map[s] ?? s;
  }

  Widget _item(Map<String, dynamic> it) {
    final nombre = it['nombre'] ?? '';
    final desc = it['descripcion'] as String?;
    final conTamanos = it['precio_personal'] != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(nombre,
                    style: const TextStyle(
                        color: MarateaColors.pureWhite, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              if (conTamanos) const SizedBox.shrink()
              else
                _precio(money(it['precio'])),
            ],
          ),
          if (desc != null && desc.isNotEmpty && desc.length > 12)
            Text(desc,
                style: const TextStyle(color: MarateaColors.stoneGray, fontSize: 13)),
          if (conTamanos)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Personal ${money(it['precio_personal'])} · '
                'Mediana ${money(it['precio_mediana'])} · '
                'Grande ${money(it['precio_grande'])}',
                style: const TextStyle(color: MarateaColors.paleYellow, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _precio(String s) => Text(s,
      style: const TextStyle(
          color: MarateaColors.turquoise, fontWeight: FontWeight.bold));
}