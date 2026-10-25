import 'package:flutter/material.dart';

import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Vista "Ítems de facturas": tabla con todos los ítems adquiridos en las
/// facturas de compra ingresadas (agrupados por producto con cantidad y total).
/// Accesible desde la pantalla de inicio del POS.
class FacturasItemsView extends StatefulWidget {
  const FacturasItemsView({super.key});

  @override
  State<FacturasItemsView> createState() => _FacturasItemsViewState();
}

class _FacturasItemsViewState extends State<FacturasItemsView> {
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final amarillo = cs.onSurface;
    final turquesa = Color(0xFF2FB9A6);

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
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: amarillo)),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Todos los ítems adquiridos en las facturas de compra ingresadas.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>?>(
              future: ApiClient.getJson('/facturas/items'),
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
                final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
                final total = items.fold(0.0, (s, f) => s + _num(f['total']));
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No hay ítems de facturas registrados.'),
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
                      child: SingleChildScrollView(
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
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}