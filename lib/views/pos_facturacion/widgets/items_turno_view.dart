import 'package:flutter/material.dart';
import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Ítems vendidos del turno, AGRUPADOS por producto + tamaño: cada producto
/// aparece una sola vez con la cantidad total y el subtotal total facturados
/// en el turno. Sin repetir líneas ni mostrar número de factura (eso está en la
/// tabla de comandas).
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
  // Filas agrupadas: clave = nombre|tamanio.
  List<Map<String, dynamic>> _filas = [];
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
    final Map<String, Map<String, dynamic>> mapa = {};
    int cant = 0;
    double monto = 0.0;
    if (r.ok) {
      for (final v in r.list) {
        final items = (v['items'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final it in items) {
          final nombre = it['nombre'] ?? '';
          final tam = it['tamanio'] ?? '';
          final key = '$nombre|$tam';
          final c = _num(it['cantidad']).toInt();
          final sub = _num(it['subtotal']);
          if (mapa.containsKey(key)) {
            mapa[key]!['cantidad'] += c;
            mapa[key]!['subtotal'] += sub;
          } else {
            mapa[key] = {
              'nombre': nombre,
              'tamanio': tam,
              'cantidad': c,
              'subtotal': sub,
            };
          }
          cant += c;
          monto += sub;
        }
      }
    }
    setState(() {
      _loading = false;
      if (r.ok) {
        // Orden de aparición (la última agrupada queda abajo).
        _filas = mapa.values.toList();
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
              : _filas.isEmpty
                  ? const Center(child: Text('No hay ítems en este turno.', style: TextStyle(color: Colors.grey)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          color: cs.surfaceContainerHighest,
                          child: Row(
                            children: [
                              Text('Total ítems (únicos): ${_filas.length}',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text('Cantidad: $_totalCantidad', style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 16),
                              Text('Suma: ${money(_totalMonto)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: Table(
                              border: TableBorder.all(color: cs.outlineVariant, width: 1),
                              columnWidths: const {
                                0: FlexColumnWidth(3.6), // Producto
                                1: FlexColumnWidth(1.6), // Tamaño
                                2: FlexColumnWidth(1.0), // Cantidad
                                3: FlexColumnWidth(1.3), // Subtotal
                              },
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(color: cs.surfaceContainerHighest),
                                  children: [
                                    _th(cs, 'Producto'),
                                    _th(cs, 'Tamaño'),
                                    _th(cs, 'Cantidad'),
                                    _th(cs, 'Subtotal'),
                                  ],
                                ),
                                for (final f in _filas)
                                  TableRow(
                                    children: [
                                      _celda(cs, '${f['nombre'] ?? ''}', negrita: true),
                                      _celda(cs, '${(f['tamanio'] ?? '').isEmpty ? '—' : f['tamanio']}'),
                                      _celda(cs, '${f['cantidad']}', alinear: true),
                                      _celda(cs, money(_num(f['subtotal'])), alinear: true, negrita: true),
                                    ],
                                  ),
                                // Fila totales
                                TableRow(
                                  decoration: BoxDecoration(color: cs.primaryContainer),
                                  children: [
                                    _celda(cs, 'TOTAL', negrita: true),
                                    _celda(cs, '', negrita: true),
                                    _celda(cs, '$_totalCantidad', alinear: true, negrita: true),
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