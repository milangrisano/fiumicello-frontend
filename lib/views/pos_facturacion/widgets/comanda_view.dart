import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../pos_models.dart';

typedef void CbAgregar(Map<String, dynamic> item, String? tamanio);
typedef void CbBuscar(String v);
typedef void CbCategoria(int? id);
typedef void CbLinea(Linea l);
typedef void CbEscenario(String escenario);
typedef void CbFormaPago(int? id);

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
    required this.escenario,
    required this.formas,
    required this.formaPago,
    required this.onAgregar,
    required this.onBuscar,
    required this.onCategoria,
    required this.onElegirEscenario,
    required this.onCambiarForma,
    required this.onQuitar,
    required this.onRestar,
    required this.onEditarPrecio,
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
  final String escenario;
  final List<Map<String, dynamic>> formas;
  final int? formaPago;
  final CbAgregar onAgregar;
  final CbBuscar onBuscar;
  final CbCategoria onCategoria;
  final CbEscenario onElegirEscenario;
  final CbFormaPago onCambiarForma;
  final CbLinea onQuitar;
  final CbLinea onRestar;
  final CbLinea onEditarPrecio;
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

        final listaComanda = SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (items.isEmpty)
                const Text('Sin productos aún.', style: TextStyle(color: Colors.grey))
              else
                for (final l in items) _filaComanda(l),
            ],
          ),
        );

        final pie = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            // Forma de pago: justo debajo del separador de productos y encima
            // del total (sustituye la 3ª etapa de Cobro separada).
            if (formas.isNotEmpty) ...[
              DropdownButtonFormField<int?>(
                initialValue: formaPago,
                decoration: const InputDecoration(labelText: 'Forma de pago', border: OutlineInputBorder(), isDense: true),
                items: [for (final f in formas) DropdownMenuItem(value: f['id'] as int, child: Text(f['nombre'] ?? ''))],
                onChanged: onCambiarForma,
              ),
              const SizedBox(height: 8),
            ],
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
                const Text('Comanda', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 6),
                Center(child: _chipsEscenario()),
                SizedBox(height: 10),
                SizedBox(height: alto - 290, child: listaComanda),
                pie,
              ],
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 8),
              // Flexible vertical: acota el alto del área a lo disponible en el
              // viewport. El cuerpo (SingleChildScrollView) scrollea SOLO cuando
              // el grid de productos excede ese alto; si cabe, no hay scroll.
              // Automático: depende del alto real (y del ancho -> nº de columnas).
              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(flex: 3, child: cuerpo),
                    SizedBox(width: 8),
                    SizedBox(width: 380, child: panelComanda),
                  ],
                ),
              ),
            ],
          );
        }
        // Móvil/tablet: cabecera fija (flecha + buscador reducido) + chips fijos en
        // doble línea, fuera del scroll. Abajo: scroll con productos (3 cols) +
        // comanda + total + botón. Sin "Nueva comanda".
        final cabeceraMovil = Padding(
          padding: EdgeInsets.fromLTRB(borde, 4, borde, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: onVolver),
              SizedBox(width: 4),
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
        // Chips: espacio HORIZONTAL entre ellos (6), sin espacio VERTICAL (runSpacing 0).
        final chipsFijos = Padding(
          padding: EdgeInsets.fromLTRB(borde, 0, borde, 0),
          child: Wrap(
            spacing: 6,
            runSpacing: 0,
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
                    const Text('Comanda', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    Center(child: _chipsEscenario()),
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      const Text('Sin productos aún.', style: TextStyle(color: Colors.grey))
                    else
                      for (final l in items) _filaComanda(l),
                    const Divider(),
                    if (formas.isNotEmpty) ...[
                      DropdownButtonFormField<int?>(
                        initialValue: formaPago,
                        decoration: const InputDecoration(labelText: 'Forma de pago', border: OutlineInputBorder(), isDense: true),
                        items: [for (final f in formas) DropdownMenuItem(value: f['id'] as int, child: Text(f['nombre'] ?? ''))],
                        onChanged: onCambiarForma,
                      ),
                      const SizedBox(height: 8),
                    ],
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
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Volver',
              onPressed: onVolver,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                onChanged: onBuscar,
                decoration: const InputDecoration(hintText: 'Buscar producto…', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
      ),
      SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('Todos'),
                selected: categoriaSel == null,
                onSelected: (_) => onCategoria(null),
              ),
            ),
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

  Widget _chipsEscenario() {
    Widget chip(String label, String valor, IconData icono) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: ChoiceChip(
            label: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono, size: 15),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
            selected: escenario == valor,
            onSelected: (_) => onElegirEscenario(valor),
          ),
        ),
      );
    }

    // Row con Expanded: los 3 chips SIEMPRE quedan en una sola línea,
    // repartiéndose el ancho disponible (se encogen en pantallas angostas).
    return Row(
      children: [
        chip('Mesa', 'mesa', Icons.restaurant),
        chip('Para llevar', 'para_llevar', Icons.takeout_dining),
        chip('Domicilio', 'domicilio', Icons.local_shipping),
      ],
    );
  }

  Widget _filaComanda(Linea l) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('${l.nombre}${l.tamanio != null ? ' (${l.tamanio})' : ''}'),
      subtitle: Text(money(l.precio)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        // Editar precio
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: 'Editar precio',
          visualDensity: VisualDensity.compact,
          onPressed: () => onEditarPrecio(l),
        ),
        // Disminuir
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 18),
          tooltip: 'Quitar uno',
          visualDensity: VisualDensity.compact,
          onPressed: () => onRestar(l),
        ),
        // Cantidad
        Text('×${l.cantidad}', style: const TextStyle(fontWeight: FontWeight.w600)),
        // Aumentar
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 18),
          tooltip: 'Agregar uno',
          visualDensity: VisualDensity.compact,
          onPressed: () => onSumar(l),
        ),
        // Borrar
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          tooltip: 'Quitar producto',
          visualDensity: VisualDensity.compact,
          onPressed: () => onQuitar(l),
        ),
      ]),
    );
  }

  Widget _productoBoton(BuildContext context, Map<String, dynamic> it, {double lado = 120}) {
    final conTamanos = it['precio_personal'] != null;
    final nombre = it['nombre'] ?? '';
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Sin ventana flotante: se agrega directo. Con tamaños, solo se elige
          // tamaño; sin tamaños, se agrega de una.
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