import 'package:flutter/material.dart';
import '../core/data/api_client.dart';
import '../core/utils/formatters.dart';
import '../core/theme/maratea_colors.dart';

/// Public Fiumicello menu (carta). Shown at the app's root `/` and as a section
/// for authenticated users. Structured: categories with items and prices.
/// Maratea palette: pure-white background, deep-blue text.
///
/// Responsive layout:
///  - <1200px (mobile/tablet): single column, logo 70px.
///  - >=1200px (desktop): two columns arranged in rows
///    (Pizzas | Pizzas de la Casa) and (Lasagnas + Paninis | Bebidas),
///    logo double size (140px).
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
              style: const TextStyle(color: MarateaColors.deepBlue)));
    }

    return Container(
      color: MarateaColors.cream,
      child: LayoutBuilder(builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1200;
        final logoH = isDesktop ? 140.0 : 70.0;
        return ListView(
          padding: EdgeInsets.all(isDesktop ? 40 : 20),
          children: [
            // Header: the brand logo only.
            Center(
              child: Image.asset(
                'assets/logo_fiumicello.png',
                height: logoH,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: isDesktop ? 32 : 24),
            if (isDesktop)
              ..._buildDesktopLayout()
            else
              for (final c in _categorias) ..._categoriaWidgets(c),
            const SizedBox(height: 12),
            const Center(
              child: Text('¡BUON APPETITO!',
                  style: TextStyle(
                      color: MarateaColors.deepBlue,
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        );

    return [
      // Row 1: Pizzas | Pizzas de la Casa
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          col(renderLeftCat(pizzas, null)),
          col(renderLeftCat(rootCasa, null)),
        ],
      ),
      const SizedBox(height: 20),
      // Row 2: Lasagnas + Paninis | Bebidas
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          col(renderLeftCat(lasagnas, paninis)),
          col(renderLeftCat(bebidas, null)),
        ],
      ),
    ];
  }

  /// Widgets for a whole category: title + grouped items.
  List<Widget> _categoriaWidgets(Map<String, dynamic> c) {
    return [
      Text(
        c['nombre'] ?? '',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: MarateaColors.deepBlue,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 6),
      // Group current category's items by their "tipo" (description) when
      // it's a short family label (e.g. beverages: charca, té, gaseosa).
      ..._renderItems(c['items'] as List? ?? const []),
      const SizedBox(height: 20),
    ];
  }

  /// Renders a category's items. When items carry a short "tipo" label in their
  /// description (e.g. beverages: Cerveza / Té / Gaseosa / Agua), they are grouped
  /// under a subheading; otherwise items render in a flat list.
  List<Widget> _renderItems(List<dynamic> items) {
    final itemsMap = items.cast<Map<String, dynamic>>();
    // Detect if descriptions are short tipo-labels (one word-ish) vs recipes.
    final tipos = <String>{};
    for (final it in itemsMap) {
      final d = (it['descripcion'] ?? '').toString().trim();
      if (d.isNotEmpty && d == d.split(' ').first || d.length <= 12) {
        tipos.add(d);
      }
    }
    if (tipos.length > 1) {
      // Group by tipo, preserving order of first appearance.
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
    // Flat list (no tipo grouping).
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
                        color: MarateaColors.terracotta, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              if (conTamanos) const SizedBox.shrink()
              else
                _precio(money(it['precio'])),
            ],
          ),
          if (desc != null && desc.isNotEmpty && desc.length > 12)
            Text(desc,
                style: const TextStyle(color: MarateaColors.goldenSand, fontSize: 13)),
          if (conTamanos)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Personal ${money(it['precio_personal'])} · '
                'Mediana ${money(it['precio_mediana'])} · '
                'Grande ${money(it['precio_grande'])}',
                style: const TextStyle(color: MarateaColors.turquoise, fontSize: 12),
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