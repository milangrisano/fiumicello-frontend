import 'package:flutter/material.dart';

import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Vista "Ítems de facturas": tabla con todos los ítems adquiridos en las
/// facturas de compra ingresadas (agrupados por producto con cantidad y total).
/// Selector de periodo por chips (Semana / Mes / Año) + botón calendario de
/// rango + buscador server-side combinable (producto/proveedor/nº factura).
/// En móvil (ancho <700) se muestran tarjetas (ListTile); en PC, tabla.
class FacturasItemsView extends StatefulWidget {
  /// Modo embebido: omite la fila de flecha-atrás + título (para renderizarse
  /// dentro de un layout que ya aporta la barra de navegación por pestañas).
  final bool embebido;
  const FacturasItemsView({super.key, this.embebido = false});

  @override
  State<FacturasItemsView> createState() => _FacturasItemsViewState();
}

class _FacturasItemsViewState extends State<FacturasItemsView> {
  String _modo = 'mes'; // semana | mes | anio | rango
  DateTimeRange? _rango;
  bool _filtrosAvanzados = false;
  // Buscador server-side: texto (producto/categoría/proveedor/nº factura) +
  // fechas manuales (Desde/Hasta). Vacío = no filtra.
  final TextEditingController _qCtrl = TextEditingController();
  final TextEditingController _diaDesdeCtrl = TextEditingController();
  final TextEditingController _mesDesdeCtrl = TextEditingController();
  final TextEditingController _anioDesdeCtrl = TextEditingController();
  final TextEditingController _diaHastaCtrl = TextEditingController();
  final TextEditingController _mesHastaCtrl = TextEditingController();
  final TextEditingController _anioHastaCtrl = TextEditingController();

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    for (final c in [_qCtrl, _diaDesdeCtrl, _mesDesdeCtrl, _anioDesdeCtrl,
      _diaHastaCtrl, _mesHastaCtrl, _anioHastaCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Rango (desde, hasta) según el modo / fechas manuales seleccionadas.
  (String, String)? _rangoActual() {
    final tieneDesdeManual = _diaDesdeCtrl.text.isNotEmpty ||
        _mesDesdeCtrl.text.isNotEmpty || _anioDesdeCtrl.text.isNotEmpty;
    final tieneHastaManual = _diaHastaCtrl.text.isNotEmpty ||
        _mesHastaCtrl.text.isNotEmpty || _anioHastaCtrl.text.isNotEmpty;
    if (tieneDesdeManual || tieneHastaManual) {
      return (_fechaDesdeManual(), _fechaHastaManual());
    }
    if (_modo == 'rango' && _rango != null) {
      return (_fmt(_rango!.start), _fmt(_rango!.end));
    }
    final hoy = DateTime.now();
    if (_modo == 'semana') {
      final lunes = hoy.subtract(Duration(days: hoy.weekday - 1));
      final domingo = lunes.add(const Duration(days: 6));
      return (_fmt(lunes), _fmt(domingo));
    }
    if (_modo == 'mes') {
      final primero = DateTime(hoy.year, hoy.month, 1);
      final ultimo = DateTime(hoy.year, hoy.month + 1, 0);
      return (_fmt(primero), _fmt(ultimo));
    }
    if (_modo == 'anio') {
      return ('${hoy.year}-01-01', '${hoy.year}-12-31');
    }
    return null;
  }

  String _fechaDesdeManual() {
    final d = _diaDesdeCtrl.text.trim().padLeft(2, '0');
    final m = _mesDesdeCtrl.text.trim().padLeft(2, '0');
    final a = _anioDesdeCtrl.text.trim();
    return '${a.isNotEmpty ? a : '2024'}-${m.isNotEmpty ? m : '01'}-${d.isNotEmpty ? d : '01'}';
  }

  String _fechaHastaManual() {
    final d = _diaHastaCtrl.text.trim().padLeft(2, '0');
    final m = _mesHastaCtrl.text.trim().padLeft(2, '0');
    final a = _anioHastaCtrl.text.trim();
    return '${a.isNotEmpty ? a : '2099'}-${m.isNotEmpty ? m : '12'}-${d.isNotEmpty ? d : '31'}';
  }

  /// Construye la URL con rango + texto libre (server-side).
  String _buildUrl() {
    final params = <String>[];
    final rango = _rangoActual();
    if (rango != null) {
      params.add('desde=${Uri.encodeQueryComponent(rango.$1)}');
      params.add('hasta=${Uri.encodeQueryComponent(rango.$2)}');
    }
    final q = _qCtrl.text.trim();
    if (q.isNotEmpty) params.add('q=${Uri.encodeQueryComponent(q)}');
    final url = params.isEmpty ? '/facturas/items' : '/facturas/items?${params.join('&')}';
    return url;
  }

  void _buscar() => setState(() {});

  bool get _hayBusqueda =>
      _qCtrl.text.trim().isNotEmpty ||
      _diaDesdeCtrl.text.trim().isNotEmpty ||
      _mesDesdeCtrl.text.trim().isNotEmpty ||
      _anioDesdeCtrl.text.trim().isNotEmpty ||
      _diaHastaCtrl.text.trim().isNotEmpty ||
      _mesHastaCtrl.text.trim().isNotEmpty ||
      _anioHastaCtrl.text.trim().isNotEmpty;

  void _limpiarBusqueda() {
    for (final c in [_qCtrl, _diaDesdeCtrl, _mesDesdeCtrl, _anioDesdeCtrl,
      _diaHastaCtrl, _mesHastaCtrl, _anioHastaCtrl]) {
      c.clear();
    }
    setState(() {});
  }

  Widget _cargarVista() {
    return FutureBuilder<Map<String, dynamic>?>(
      key: ValueKey(_buildUrl()),
      future: ApiClient.getJson(_buildUrl()),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error al cargar los ítems de facturas.\n${snapshot.error ?? ''}',
                  style: const TextStyle(color: Colors.red)),
            ),
          );
        }
        final data = snapshot.data!['data'] as Map? ?? snapshot.data!;
        final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ??
            <Map<String, dynamic>>[];
        final total = items.fold(0.0, (s, f) => s + _num(f['total']));
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay ítems de facturas que coincidan con el filtro.'),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Text(_hayBusqueda
                      ? '${items.length} resultados · TOTAL ÍTEMS'
                      : 'TOTAL ITEMS',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  Text(money(total),
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: turquesa)),
                ]),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  if (c.maxWidth < 700) {
                    // Móvil: tarjetas (ListTile).
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final f = items[i];
                        final prod = '${f['producto'] ?? f['descripcion'] ?? ''}';
                        final unidad = _unidadDe(prod);
                        return Container(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            border: Border.all(color: cs.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            title: Text(prod,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((f['proveedor'] ?? '') != '')
                                  Text('${f['proveedor']}', style: const TextStyle(fontSize: 12)),
                                if ((f['numero_factura'] ?? '') != '')
                                  Text('Factura ${f['numero_factura']} · ${f['fecha'] ?? ''}',
                                      style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(unidad.isEmpty ? '×${_num(f['cantidad'])}' : '×${_num(f['cantidad'])} $unidad',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text(money(_num(f['total'])),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: turquesa)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                  // PC: tabla.
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Table(
                      border: TableBorder.all(color: cs.outlineVariant, width: 1),
                      columnWidths: const {
                        0: FlexColumnWidth(3.2),
                        1: FlexColumnWidth(2.0),
                        2: FlexColumnWidth(1.0),
                        3: FlexColumnWidth(1.3),
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: cs.surfaceContainerHighest),
                          children: [
                            _th(cs, 'Producto'),
                            _th(cs, 'Proveedor'),
                            _th(cs, 'Cant.', alinear: true),
                            _th(cs, 'Total', alinear: true),
                          ],
                        ),
                        for (final f in items)
                          TableRow(
                            children: [
                              _celda(cs, '${f['producto'] ?? f['descripcion'] ?? '—'}', negrita: true),
                              _celda(cs, '${f['proveedor'] ?? '—'}'),
                              _celda(cs, _cantidadConUnidad(f), alinear: true),
                              _celda(cs, money(_num(f['total'])), alinear: true, negrita: true),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Barra de filtros (igual a la de Facturas/Comprobantes) ──
  Widget _barraFiltros(ColorScheme cs) {
    final inputDeco = InputDecoration(
      isDense: true, filled: true, fillColor: cs.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
    Widget chipsPeriodo() => Wrap(
      spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final m in ['semana', 'mes', 'anio'])
          ChoiceChip(
            label: Text(m == 'semana' ? 'Semana' : (m == 'mes' ? 'Mes' : 'Año')),
            selected: _rango == null && _modo == m,
            shape: const StadiumBorder(),
            onSelected: (_) {
              setState(() { _modo = m; _rango = null; });
            },
          ),
        IconButton(icon: const Icon(Icons.calendar_month),
            tooltip: 'Elegir período (rango)', onPressed: _elegirRango),
      ],
    );
    Widget campoTexto({double? width}) => SizedBox(
      width: width,
      child: TextField(
        controller: _qCtrl,
        decoration: inputDeco.copyWith(
          hintText: 'Producto, proveedor o nº factura…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _qCtrl.text.isEmpty
              ? null
              : IconButton(icon: const Icon(Icons.clear, size: 18),
                  onPressed: () { _qCtrl.clear(); setState(() {}); }),
        ),
        onSubmitted: (_) => setState(() {}),
      ),
    );
    Widget botonFiltros() => FilledButton.tonalIcon(
      onPressed: () => setState(() => _filtrosAvanzados = !_filtrosAvanzados),
      style: FilledButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(10)),
      icon: Icon(_filtrosAvanzados ? Icons.expand_less : Icons.tune, size: 22),
      label: const Text(''),
    );
    Widget panelAvanzado() => AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: _filtrosAvanzados
          ? Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.calendar_month, size: 18),
                      const SizedBox(width: 6),
                      Text('Rango de fechas',
                          style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.clear_all, size: 18),
                        tooltip: 'Vaciar fechas',
                        onPressed: () {
                          for (final c in [_diaDesdeCtrl, _mesDesdeCtrl,
                            _anioDesdeCtrl, _diaHastaCtrl, _mesHastaCtrl, _anioHastaCtrl]) {
                            c.clear();
                          }
                          setState(() {});
                        },
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _campoFecha1(inputDeco, cs, 'Desde',
                            _diaDesdeCtrl, _mesDesdeCtrl, _anioDesdeCtrl),
                        _campoFecha1(inputDeco, cs, 'Hasta',
                            _diaHastaCtrl, _mesHastaCtrl, _anioHastaCtrl),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (_hayBusqueda)
                        TextButton.icon(
                          onPressed: _limpiarBusqueda,
                          icon: const Icon(Icons.filter_alt_off, size: 18),
                          label: const Text('Limpiar')),
                      FilledButton.icon(
                        onPressed: _buscar,
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Buscar')),
                    ]),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (ctx, c) {
            final esMovil = c.maxWidth < 700;
            if (esMovil) {
              return Column(children: [
                Center(child: chipsPeriodo()),
                const SizedBox(height: 8),
                Row(children: [
                  Flexible(child: campoTexto()),
                  const SizedBox(width: 4),
                  botonFiltros(),
                ]),
              ]);
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                chipsPeriodo(),
                const SizedBox(width: 10),
                campoTexto(width: 300),
                const SizedBox(width: 4),
                botonFiltros(),
              ],
            );
          }),
          panelAvanzado(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (!widget.embebido) const SizedBox(height: 8),
          if (!widget.embebido)
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text('Ítems de facturas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
              ),
            ]),
          _barraFiltros(cs),
          Expanded(child: _cargarVista()),
        ],
      ),
    );
  }

  ColorScheme get cs => Theme.of(context).colorScheme;
  Color get turquesa => const Color(0xFF2FB9A6);

  Future<void> _elegirRango() async {
    final ahora = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: ahora,
      initialDateRange: _rango,
      helpText: 'Elegir período',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      saveText: 'Aplicar',
    );
    if (picked != null) {
      setState(() {
        _rango = picked;
        _modo = 'rango';
      });
    } else if (_rango == null && _modo == 'rango') {
      setState(() => _modo = 'mes');
    }
  }

  /// Tres recuadros DD / MM / AAAA con una etiqueta (Desde/Hasta).
  Widget _campoFecha1(InputDecoration inputDeco, ColorScheme cs, String label,
      TextEditingController dia, TextEditingController mes,
      TextEditingController anio) {
    final deco = (String hint) => inputDeco.copyWith(hintText: hint);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        const SizedBox(width: 6),
        _inputCorto(deco('DD'), dia, 2, mes),
        const SizedBox(width: 5),
        Text('/', style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(width: 5),
        _inputCorto(deco('MM'), mes, 2, anio),
        const SizedBox(width: 5),
        Text('/', style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(width: 5),
        _inputCorto(deco('AAAA'), anio, 4, null),
      ],
    );
  }

  /// Input numérico corto (DD/MM/AAAA) con salto automático al siguiente.
  Widget _inputCorto(InputDecoration deco, TextEditingController ctrl, int maxLen,
      TextEditingController? next) {
    return SizedBox(
      width: maxLen == 2 ? 44 : 60,
      child: TextField(
        controller: ctrl,
        decoration: deco,
        keyboardType: TextInputType.number,
        maxLength: maxLen,
        textAlign: TextAlign.center,
        buildCounter: (BuildContext context,
                {required int currentLength,
                required bool isFocused,
                required int? maxLength}) => null,
        style: const TextStyle(fontSize: 13.5),
        onChanged: (_) {
          setState(() {});
          if (next != null && ctrl.text.length == maxLen) {
            FocusScope.of(context).nextFocus();
          }
        },
        onSubmitted: (_) => setState(() {}),
      ),
    );
  }

  /// Detecta la unidad de medida dentro de la descripción del producto.
  String _unidadDe(String desc) {
    final texto = desc.toLowerCase();
    final pares = <(String, String)>[
      (r'(?:^|[^a-z])kwh(?:[^a-z]|$)', 'kWh'),
      (r'kilogramos|kilos', 'kg'),
      (r'(?:^|\D)kg(?:$|[^a-z])', 'kg'),
      (r'(?:^|\D)gr(?:$|[^a-z])|gramos', 'g'),
      (r'(?:^|\D)litros|(?:^|\D)lts?[.,\s]', 'L'),
      (r'(?:^|\D)ml(?:$|[^a-z])|mililitros', 'ml'),
      (r'(?:^|\D)und(?:$|[^a-z])|unidades?', 'und'),
      (r'(?:^|\D)doc(?:$|[^a-z])|docenas?', 'doc'),
      (r'(?:^|\D)caja(?:$|[^a-z])|cajas?', 'caja'),
      (r'(?:^|\D)bot(?:$|[^a-z])|botellas?', 'bot'),
      (r'(?:^|\D)paq(?:$|[^a-z])|paquetes?', 'paq'),
      (r'bolsas?', 'bolsa'),
    ];
    for (final (pat, uni) in pares) {
      if (RegExp(pat).hasMatch(texto)) return uni;
    }
    return '';
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return (v as num).toDouble();
    final n = double.tryParse('$v'.replaceAll(',', '').replaceAll(r'\s', ''));
    return n ?? 0;
  }

  String _cantidadConUnidad(Map<String, dynamic> f) {
    final u = _unidadDe('${f['producto'] ?? f['descripcion'] ?? ''}');
    return u.isEmpty ? '${_num(f['cantidad'])}' : '${_num(f['cantidad'])} $u';
  }

  Widget _th(ColorScheme cs, String t, {bool alinear = false}) => Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          t,
          textAlign: alinear ? TextAlign.right : TextAlign.left,
          style:
              TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface, fontSize: 12),
        ),
      );

  Widget _celda(ColorScheme cs, String t,
          {bool alinear = false, bool negrita = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          t,
          textAlign: alinear ? TextAlign.right : TextAlign.left,
          style: TextStyle(
              fontSize: 12,
              fontWeight: negrita ? FontWeight.w600 : null,
              color: color ?? cs.onSurface),
        ),
      );
}