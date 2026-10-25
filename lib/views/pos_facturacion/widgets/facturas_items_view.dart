import 'package:flutter/material.dart';

import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Vista "Ítems de facturas": tabla con todos los ítems adquiridos en las
/// facturas de compra ingresadas (agrupados por producto con cantidad y total).
/// Selector de periodo por chips (Semana / Mes / Año) + botón calendario de
/// rango. En móvil (ancho <640) se muestran tarjetas (ListTile); en PC, tabla.
/// Accesible desde la pantalla de inicio del POS.
class FacturasItemsView extends StatefulWidget {
  const FacturasItemsView({super.key});

  @override
  State<FacturasItemsView> createState() => _FacturasItemsViewState();
}

class _FacturasItemsViewState extends State<FacturasItemsView> {
  String _modo = 'mes'; // semana | mes | anio | rango
  DateTimeRange? _rango;

  /// Formatea una fecha como YYYY-MM-DD (para el filtro del backend).
  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Rango (desde, hasta) según el modo seleccionado.
  (String, String)? _rangoActual() {
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

  /// Construye la URL con el rango según el modo seleccionado.
  String _buildUrl() {
    final rango = _rangoActual();
    if (rango == null) return '/facturas/items';
    final q = Uri(queryParameters: {'desde': rango.$1, 'hasta': rango.$2}).query;
    return '/facturas/items?$q';
  }

  Widget _cargarVista() {
    return FutureBuilder<Map<String, dynamic>?>(
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
              child: Text('No hay ítems de facturas en este periodo.'),
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
                  const Text('TOTAL ITEMS',
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
                  if (c.maxWidth < 640) {
                    // Móvil: tarjetas (ListTile) — cómodo de tocar.
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final f = items[i];
                        return Container(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            border: Border.all(color: cs.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            title: Text('${f['producto'] ?? f['descripcion'] ?? '—'}',
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
                                Text('×${_num(f['cantidad'])}',
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
                              _celda(cs, '${_num(f['cantidad'])}', alinear: true),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 8),
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
          // Selector de periodo: chips Semana/Mes/Año + calendario de rango.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final m in ['semana', 'mes', 'anio'])
                  ChoiceChip(
                    label: Text(m == 'semana' ? 'Semana' : (m == 'mes' ? 'Mes' : 'Año')),
                    selected: _modo == m,
                    shape: const StadiumBorder(),
                    onSelected: (_) => setState(() => _modo = m),
                  ),
                if (_modo == 'rango')
                  ChoiceChip(
                    label: Text(_rango == null
                        ? 'Rango'
                        : '${_fmt(_rango!.start)} → ${_fmt(_rango!.end)}'),
                    // Texto oscuro para que no se pierda sobre el turquesa.
                    labelStyle: const TextStyle(color: Colors.black, fontSize: 13),
                    selected: true,
                    shape: const StadiumBorder(),
                  ),
                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  tooltip: 'Elegir período (rango)',
                  onPressed: _elegirRango,
                ),
              ],
            ),
          ),
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

  /// Intenta convertir el valor a número (acepta int/double/String).
  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return (v as num).toDouble();
    final n = double.tryParse('$v'.replaceAll(',', '').replaceAll(r'\s', ''));
    return n ?? 0;
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