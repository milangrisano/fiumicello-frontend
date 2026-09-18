import 'package:flutter/material.dart';
import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Ítems vendidos del turno, AGRUPADOS por producto + tamaño: cada producto
/// aparece una sola vez con la cantidad total y el subtotal total facturados
/// en el turno. Sin repetir líneas ni mostrar número de factura (eso está en la
/// tabla de comandas). Ordenable por Cantidad y Subtotal (asc/desc). Incluye
/// selector interno de turno (flechas ‹ ›).
class ItemsTurnoView extends StatefulWidget {
  final List<Map<String, dynamic>> turnos;
  final int indiceInicial;
  const ItemsTurnoView({super.key, required this.turnos, this.indiceInicial = 0});

  @override
  State<ItemsTurnoView> createState() => _ItemsTurnoViewState();
}

class _ItemsTurnoViewState extends State<ItemsTurnoView> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _filas = [];
  int _totalCantidad = 0;
  double _totalMonto = 0.0;

  // Orden: campo ('cantidad' | 'subtotal') y dirección.
  String _ordenCampo = 'cantidad';
  bool _ordenAsc = false;

  late int _idx;

  @override
  void initState() {
    super.initState();
    _idx = widget.indiceInicial.clamp(0, widget.turnos.length - 1);
    _cargar();
  }

  Map<String, dynamic> get _turnoAct => widget.turnos[_idx];

  Future<void> _cargar() async {
    setState(() => _loading = true);
    final idTurno = _turnoAct['id'] as int;
    final r = await ApiClient.obtenerVentasTurno(idTurno);
    if (!mounted) return;
    final Map<String, Map<String, dynamic>> mapa = {};
    int cant = 0;
    double monto = 0.0;
    if (r.ok) {
      for (final v in r.list) {
        if (v['anulada'] == true) continue; // excluye anuladas
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
            mapa[key] = {'nombre': nombre, 'tamanio': tam, 'cantidad': c, 'subtotal': sub};
          }
          cant += c;
          monto += sub;
        }
      }
    }
    setState(() {
      _loading = false;
      if (r.ok) {
        _filas = mapa.values.toList();
        _totalCantidad = cant;
        _totalMonto = monto;
        _error = null;
      } else {
        _error = r.message;
      }
    });
  }

  void _cambiarTurno(int delta) {
    final nuevo = _idx + delta;
    if (nuevo < 0 || nuevo >= widget.turnos.length) return;
    setState(() => _idx = nuevo);
    _cargar();
  }

  void _ordenarPor(String campo) {
    setState(() {
      if (_ordenCampo == campo) {
        _ordenAsc = !_ordenAsc;
      } else {
        _ordenCampo = campo;
        _ordenAsc = false;
      }
      _filas.sort((a, b) {
        final av = (a[campo] as num).toDouble();
        final bv = (b[campo] as num).toDouble();
        return _ordenAsc ? av.compareTo(bv) : bv.compareTo(av);
      });
    });
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

  Widget _thOrdenable(ColorScheme cs, String titulo, String campo) {
    final activo = _ordenCampo == campo;
    return InkWell(
      onTap: () => _ordenarPor(campo),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titulo,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    fontSize: 13,
                    decoration: activo ? TextDecoration.underline : null)),
            const SizedBox(width: 2),
            Icon(
              activo ? (_ordenAsc ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more,
              size: 14,
              color: activo ? cs.primary : cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final turnoFecha = _fechaTurno(_turnoAct['fecha']);
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selector de turno interno.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            tooltip: 'Turno anterior',
                            visualDensity: VisualDensity.compact,
                            onPressed: _idx < widget.turnos.length - 1
                                ? () => _cambiarTurno(1)
                                : null,
                          ),
                          Expanded(
                            child: Center(
                              child: Chip(
                                avatar: Icon(
                                  _turnoAct['estado'] == 'abierto' ? Icons.lock_open : Icons.history,
                                  size: 16,
                                ),
                                label: Text(
                                  'Turno #${_turnoAct['id']} · $turnoFecha'
                                  '${_turnoAct['estado'] == 'abierto' ? ' (abierto)' : ''}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            tooltip: 'Turno más reciente',
                            visualDensity: VisualDensity.compact,
                            onPressed: _idx > 0 ? () => _cambiarTurno(-1) : null,
                          ),
                        ],
                      ),
                    ),
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
                      child: _filas.isEmpty
                          ? const Center(child: Text('No hay ítems en este turno.', style: TextStyle(color: Colors.grey)))
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Table(
                                border: TableBorder.all(color: cs.outlineVariant, width: 1),
                                columnWidths: const {
                                  0: FlexColumnWidth(3.6),
                                  1: FlexColumnWidth(1.6),
                                  2: FlexColumnWidth(1.0),
                                  3: FlexColumnWidth(1.3),
                                },
                                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                children: [
                                  TableRow(
                                    decoration: BoxDecoration(color: cs.surfaceContainerHighest),
                                    children: [
                                      _th(cs, 'Producto'),
                                      _th(cs, 'Tamaño'),
                                      _thOrdenable(cs, 'Cantidad', 'cantidad'),
                                      _thOrdenable(cs, 'Subtotal', 'subtotal'),
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