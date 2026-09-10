import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../pos_models.dart';

typedef void CbAgregar(Map<String, dynamic> item, String? tamanio);
typedef void CbBuscar(String v);
typedef void CbCategoria(int? id);
typedef void CbLinea(Linea l);

/// Stage 1 — Comanda: catalog with product grid + the order being built.
/// Receives data (read-only) + callbacks from the POS state; owns no logic,
/// no setState. The POS state passes values and reacts to callbacks.
class ComandaView extends StatelessWidget {
  const ComandaView({
    super.key,
    required this.items,
    required this.total,
    required this.categorias,
    required this.busqueda,
    required this.categoriaSel,
    required this.error,
    required this.onAgregar,
    required this.onBuscar,
    required this.onCategoria,
    required this.onQuitar,
    required this.onNota,
    required this.onSumar,
    required this.onContinuar,
    required this.onVolver,
  });

  final List<Linea> items;
  final double total;
  final List<Map<String, dynamic>> categorias;
  final String busqueda;
  final int? categoriaSel;
  final String? error;
  final CbAgregar onAgregar;
  final CbBuscar onBuscar;
  final CbCategoria onCategoria;
  final CbLinea onQuitar;
  final CbLinea onNota;
  final CbLinea onSumar;
  final VoidCallback onContinuar;
  final VoidCallback onVolver;

  List<Map<String, dynamic>> _itemsDeCategoriaSel() {
    final b = busqueda.toLowerCase();
    if (categoriaSel == null) {
      return categorias
          .expand((c) => (c['items'] as List? ?? []).cast<Map<String, dynamic>>())
          .cast<Map<String, dynamic>>()
          .where((i) => b.isEmpty || (i['nombre'] ?? '').toString().toLowerCase().contains(b))
          .toList();
    }
    for (final c in categorias) {
      if (c['id'] == categoriaSel) return _filtrados(c);
    }
    return [];
  }

  List<Map<String, dynamic>> _filtrados(Map<String, dynamic> cat) {
    final its = (cat['items'] as List? ?? []).cast<Map<String, dynamic>>();
    if (busqueda.isEmpty) return its;
    final b = busqueda.toLowerCase();
    return its.where((i) => (i['nombre'] ?? '').toString().toLowerCase().contains(b)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final gap = 16.0;
    // El LayoutBuilder mide el ancho real y decide paneles (PC/tablet/móvil).
    return LayoutBuilder(
      builder: (context, c) {
        final borde = c.maxWidth >= 900 ? 24.0 : 16.0;
        final alto = c.maxHeight;
        final header = Padding(
          padding: EdgeInsets.fromLTRB(borde, 8, borde, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: onVolver),
              const Text('Nueva comanda', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );

        final listaComanda = SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (items.isEmpty)
                const Text('Sin productos aún.', style: TextStyle(color: Colors.grey))
              else
                for (final l in items)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${l.nombre}${l.tamanio != null ? ' (${l.tamanio})' : ''}'),
                    subtitle: Text('${money(l.precio)} ×${l.cantidad}${l.nota.isEmpty ? '' : ' · nota: ${l.nota}'}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => onQuitar(l), visualDensity: VisualDensity.compact),
                      IconButton(icon: const Icon(Icons.create), tooltip: 'Nota', onPressed: () => onNota(l), visualDensity: VisualDensity.compact),
                      IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => onSumar(l), visualDensity: VisualDensity.compact),
                    ]),
                  ),
            ],
          ),
        );

        final pie = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(money(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 8),
            FilledButton.icon(
              onPressed: items.isEmpty ? null : onContinuar,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continuar'),
            ),
          ],
        );

        final cuerpo = SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(borde, 0, borde, 16),
          child: _catalogoPanel(context, gap, borde),
        );

        // PC: dos paneles (productos | comanda). Móvil/tablet: comanda abajo fija.
        if (c.maxWidth >= 900) {
          final panelComanda = Padding(
            padding: EdgeInsets.fromLTRB(borde, 0, borde, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Comanda', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                SizedBox(height: alto - 220, child: listaComanda),
                pie,
              ],
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              SizedBox(height: gap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(flex: 3, child: cuerpo),
                  SizedBox(width: 8),
                  SizedBox(width: 380, child: panelComanda),
                ],
              ),
            ],
          );
        }
        // Móvil/tablet: cabecera fija (flecha + buscador reducido) + chips fijos en
        // doble línea, fuera del scroll. Abajo: scroll con productos (3 cols) +
        // comanda + total + botón. Sin "Nueva comanda".
        final cabeceraMovil = Padding(
          padding: EdgeInsets.fromLTRB(borde, 8, borde, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: onVolver),
              SizedBox(width: 6),
              // El buscador ocupa TODO el espacio sobrante (Flexible).
              Flexible(
                child: TextField(
                  onChanged: onBuscar,
                  decoration: const InputDecoration(hintText: 'Buscar…', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
        );
        // Chips en doble línea (Wrap), fijos fuera del scroll. Letra menor y bordes
        // más ovalados (radio grande) para que ocupen menos espacio.
        final chipsFijos = Padding(
          padding: EdgeInsets.fromLTRB(borde, 0, borde, 0),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Todos', style: TextStyle(fontSize: 12)),
                selected: categoriaSel == null,
                shape: const StadiumBorder(),
                onSelected: (_) => onCategoria(null),
              ),
              for (final c in categorias)
                ChoiceChip(
                  label: Text(c['nombre'] ?? '', style: const TextStyle(fontSize: 12)),
                  selected: categoriaSel == (c['id'] as int?),
                  shape: const StadiumBorder(),
                  onSelected: (_) => onCategoria(c['id'] as int?),
                ),
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cabeceraMovil,
            chipsFijos,
            SizedBox(height: gap / 2),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(borde, 0, borde, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _catalogoPanel(context, gap, borde, movil: true),
                    SizedBox(height: gap),
                    const Divider(),
                    SizedBox(height: 4),
                    if (items.isEmpty)
                      const Text('Sin productos aún.', style: TextStyle(color: Colors.grey))
                    else
                      for (final l in items)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${l.nombre}${l.tamanio != null ? ' (${l.tamanio})' : ''}'),
                          subtitle: Text('${money(l.precio)} ×${l.cantidad}${l.nota.isEmpty ? '' : ' · nota: ${l.nota}'}'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => onQuitar(l), visualDensity: VisualDensity.compact),
                            IconButton(icon: const Icon(Icons.create), tooltip: 'Nota', onPressed: () => onNota(l), visualDensity: VisualDensity.compact),
                            IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => onSumar(l), visualDensity: VisualDensity.compact),
                          ]),
                        ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        Text(money(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: items.isEmpty ? null : onContinuar,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Continuar'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _catalogoPanel(BuildContext context, double gap, double borde, {bool movil = false}) {
    final itemsSel = _itemsDeCategoriaSel();
    // En móvil: 3 columnas (lado ~98); en PC: mantenemos lado 120 (Wrap natural).
    final lado = movil ? 98.0 : 120.0;
    Widget content;
    if (error != null) {
      content = Text('Error: $error', style: const TextStyle(color: Colors.red));
    } else {
      content = Center(
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final it in itemsSel)
              _productoBoton(context, it, lado: lado),
          ],
        ),
      );
    }
    // En móvil el buscador y los chips ya van en la cabecera fija; aquí solo productos.
    if (movil) return content;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, gap),
        child: TextField(
          onChanged: onBuscar,
          decoration: const InputDecoration(hintText: 'Buscar producto…', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
        ),
      ),
      SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          children: [
            for (final c in categorias)
              Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                label: Text(c['nombre'] ?? ''),
                selected: categoriaSel == (c['id'] as int?),
                onSelected: (_) => onCategoria(c['id'] as int?),
              )),
          ],
        ),
      ),
      SizedBox(height: 8),
      content,
    ]);
  }

  Widget _productoBoton(BuildContext context, Map<String, dynamic> it, {double lado = 120}) {
    final conTamanos = it['precio_personal'] != null;
    final nombre = it['nombre'] ?? '';
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (conTamanos) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(nombre),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  FilledButton(onPressed: () { Navigator.pop(context); onAgregar(it, 'personal'); }, child: Text('Personal · ${money(it['precio_personal'])}')),
                  const SizedBox(height: 6),
                  FilledButton(onPressed: () { Navigator.pop(context); onAgregar(it, 'mediana'); }, child: Text('Mediana · ${money(it['precio_mediana'])}')),
                  const SizedBox(height: 6),
                  FilledButton(onPressed: () { Navigator.pop(context); onAgregar(it, 'grande'); }, child: Text('Grande · ${money(it['precio_grande'])}')),
                ]),
              ),
            );
          } else {
            onAgregar(it, null);
          }
        },
        child: SizedBox(
          width: lado,
          height: lado,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(child: Text(nombre, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                if (!conTamanos) ...[
                  const SizedBox(height: 2),
                  Text(money(it['precio']), style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}