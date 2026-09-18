import 'package:flutter/material.dart';
import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Lista las comandas (ventas cobradas) de un turno de caja concreto.
/// Se llega desde las cards del POS; el turno se elige en el selector del POS.
///
/// Diseño: TABLA con columnas (Factura, Fecha, Hora, Mesa, Pago, Ítems, Total)
/// + fila de total acumulado. La última comanda queda ABAJO.
class ComandasTurnoView extends StatefulWidget {
  final int idTurno;
  final Map<String, dynamic>? turno;
  const ComandasTurnoView({super.key, required this.idTurno, this.turno});

  @override
  State<ComandasTurnoView> createState() => _ComandasTurnoViewState();
}

class _ComandasTurnoViewState extends State<ComandasTurnoView> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _ventas = [];
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
    setState(() {
      _loading = false;
      if (r.ok) {
        // El backend las trae id DESC (última arriba); invertimos para que la
        // última comanda quede ABAJO.
        final lista = r.list.cast<Map<String, dynamic>>().reversed.toList();
        _ventas = lista;
        _totalMonto = lista.fold(0.0, (s, v) => s + _num(v['total']));
        _error = null;
      } else {
        _error = r.message;
      }
    });
  }

  String _fecha(dynamic fecha) {
    if (fecha == null) return '';
    try {
      final d = DateTime.parse(fecha.toString());
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _hora(dynamic fecha) {
    if (fecha == null) return '';
    try {
      final d = DateTime.parse(fecha.toString());
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _fechaTurno(dynamic fecha) {
    if (fecha == null) return '';
    try {
      final d = DateTime.parse(fecha.toString());
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return fecha.toString();
    }
  }

  String _resumenItems(List<dynamic> items) {
    return items.map((it) {
      final cant = _num(it['cantidad']).toInt();
      final nombre = it['nombre'] ?? '';
      final tam = it['tamanio'] != null ? ' (${it['tamanio']})' : '';
      return '$cant×$nombre$tam';
    }).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final turnoFecha = _fechaTurno(widget.turno?['fecha']);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Comandas del turno'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _cargar),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error', style: TextStyle(color: cs.error)))
              : _ventas.isEmpty
                  ? const Center(child: Text('No hay comandas en este turno.', style: TextStyle(color: Colors.grey)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (turnoFecha.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                            child: Row(
                              children: [
                                Icon(Icons.history, size: 16, color: cs.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Text('Turno #${widget.idTurno} · $turnoFecha',
                                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                                const Spacer(),
                                Text('${_ventas.length} comandas',
                                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                              ],
                            ),
                          ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: Table(
                              border: TableBorder.all(color: cs.outlineVariant, width: 1),
                              columnWidths: const {
                                0: FlexColumnWidth(2.0), // Factura
                                1: FlexColumnWidth(1.2), // Fecha
                                2: FlexColumnWidth(1.0), // Hora
                                3: FlexColumnWidth(1.4), // Mesa / Escenario
                                4: FlexColumnWidth(1.3), // Forma de pago
                                5: FlexColumnWidth(4.2), // Ítems
                                6: FlexColumnWidth(1.3), // Total
                              },
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              children: [
                                // Encabezado
                                TableRow(
                                  decoration: BoxDecoration(color: cs.surfaceContainerHighest),
                                  children: [
                                    _th(cs, 'Factura'),
                                    _th(cs, 'Fecha'),
                                    _th(cs, 'Hora'),
                                    _th(cs, 'Mesa'),
                                    _th(cs, 'Pago'),
                                    _th(cs, 'Ítems'),
                                    _th(cs, 'Total'),
                                  ],
                                ),
                                // Filas
                                for (final v in _ventas)
                                  TableRow(
                                    children: [
                                      _celda(cs, '${v['numero_factura'] ?? v['id']}', negrita: true),
                                      _celda(cs, _fecha(v['fecha'])),
                                      _celda(cs, _hora(v['fecha'])),
                                      _celda(
                                        cs,
                                        [
                                          if (v['numero_mesa'] != null) 'Mesa ${v['numero_mesa']}',
                                          if (v['escenario'] != null && v['escenario'] != 'mesa') '${v['escenario']}',
                                        ].where((e) => e.isNotEmpty).join('\n'),
                                      ),
                                      _celda(cs, '${v['forma_pago_nombre'] ?? '—'}'),
                                      _celda(cs, _resumenItems((v['items'] as List? ?? []).cast<Map<String, dynamic>>())),
                                      _celda(cs, money(_num(v['total'])), alinear: true, negrita: true),
                                    ],
                                  ),
                                // Fila de total acumulado
                                TableRow(
                                  decoration: BoxDecoration(color: cs.primaryContainer),
                                  children: [
                                    _celda(cs, 'TOTAL', negrita: true),
                                    _celda(cs, '', negrita: true),
                                    _celda(cs, '', negrita: true),
                                    _celda(cs, '', negrita: true),
                                    _celda(cs, '', negrita: true),
                                    _celda(cs, '${_ventas.length} comandas', negrita: true),
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