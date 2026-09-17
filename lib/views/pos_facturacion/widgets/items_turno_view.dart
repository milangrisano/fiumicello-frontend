import 'package:flutter/material.dart';
import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Lista los ítems vendidos (línea por línea) de todas las comandas del turno.
/// Se muestran en una TABLA (Factura, Producto, Tamaño, Cantidad, Subtotal)
/// sin tiles que desperdicien espacio. Totales al pie.
class ItemsTurnoView extends StatefulWidget {
  final int idTurno;
  final Map<String, dynamic>? turno;
  const ItemsTurnoView({super.key, required this.idTurno, this.turno});

  @override
  State<ItemsTurnoView> createState() => _ItemsTurnoViewState();
}

class _ItemsTurnoViewState extends State<ItemsTurnoView> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  int _totalCantidad = 0;
  double _totalMonto = 0.0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    final r = await ApiClient.obtenerVentasTurno(widget.idTurno);
    if (!mounted) return;
    final filas = <Map<String, dynamic>>[];
    int cant = 0;
    double monto = 0.0;
    if (r.ok) {
      for (final v in r.list) {
        final items = (v['items'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final it in items) {
          filas.add({...it, 'factura': v['numero_factura'] ?? v['id']});
          cant += (_num(it['cantidad'])).toInt();
          monto += _num(it['subtotal']);
        }
      }
    }
    setState(() {
      _loading = false;
      if (r.ok) {
        _items = filas;
        _totalCantidad = cant;
        _totalMonto = monto;
        _error = null;
      } else {
        _error = r.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Ítems vendidos del turno'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _cargar),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error', style: TextStyle(color: cs.error)))
              : _items.isEmpty
                  ? const Center(child: Text('No hay ítems en este turno.', style: TextStyle(color: Colors.grey)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          color: cs.surfaceContainerHighest,
                          child: Row(
                            children: [
                              Text('Total ítems: $_totalCantidad',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text('Suma: ${money(_totalMonto)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: Table(
                              border: TableBorder.all(color: cs.outlineVariant, width: 1),
                              columnWidths: const {
                                0: FlexColumnWidth(1.6), // Factura
                                1: FlexColumnWidth(3.6), // Producto
                                2: FlexColumnWidth(1.6), // Tamaño
                                3: FlexColumnWidth(1.0), // Cantidad
                                4: FlexColumnWidth(1.3), // Subtotal
                              },
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(color: cs.surfaceContainerHighest),
                                  children: [
                                    _th(cs, 'Factura'),
                                    _th(cs, 'Producto'),
                                    _th(cs, 'Tamaño'),
                                    _th(cs, 'Cant'),
                                    _th(cs, 'Subtotal'),
                                  ],
                                ),
                                for (final it in _items)
                                  TableRow(
                                    children: [
                                      _celda(cs, '${it['factura']}'),
                                      _celda(cs, '${it['nombre'] ?? ''}', negrita: true),
                                      _celda(cs, '${it['tamanio'] ?? '—'}'),
                                      _celda(cs, _num(it['cantidad']).toInt().toString(), alinear: true),
                                      _celda(cs, money(_num(it['subtotal'])), alinear: true, negrita: true),
                                    ],
                                  ),
                                // Fila totales
                                TableRow(
                                  decoration: BoxDecoration(color: cs.primaryContainer),
                                  children: [
                                    _celda(cs, 'TOTAL', negrita: true),
                                    _celda(cs, '', negrita: true),
                                    _celda(cs, '', negrita: true),
                                    _celda(cs, _totalCantidad.toString(), alinear: true, negrita: true),
                                    _celda(cs, money(_totalMonto), alinear: true, negrita: true),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _th(ColorScheme cs, String t) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface, fontSize: 13)),
      );

  Widget _celda(ColorScheme cs, String t, {bool negrita = false, bool alinear = false}) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          t,
          textAlign: alinear ? TextAlign.right : TextAlign.left,
          style: TextStyle(fontSize: 13, color: cs.onSurface, fontWeight: negrita ? FontWeight.w600 : FontWeight.normal),
        ),
      );

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }
}