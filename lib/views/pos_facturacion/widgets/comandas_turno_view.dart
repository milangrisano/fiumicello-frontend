import 'package:flutter/material.dart';
import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Lista las comandas (ventas cobradas) de un turno de caja, con selector
/// interno de turno (flchas ‹ ›) para navegar entre turnos.
///
/// Diseño: TABLA con columnas (Factura, Fecha, Hora, Mesa, Pago, Ítems, Total,
/// Acciones) + fila de total acumulado. La última comanda queda ABAJO.
class ComandasTurnoView extends StatefulWidget {
  final List<Map<String, dynamic>> turnos;
  final int indiceInicial;
  const ComandasTurnoView({super.key, required this.turnos, this.indiceInicial = 0});

  @override
  State<ComandasTurnoView> createState() => _ComandasTurnoViewState();
}

class _ComandasTurnoViewState extends State<ComandasTurnoView> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _ventas = [];
  double _totalMonto = 0.0;
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
    setState(() {
      _loading = false;
      if (r.ok) {
        // El backend las trae id DESC (última arriba); invertimos para que la
        // última comanda quede ABAJO.
        final lista = r.list.cast<Map<String, dynamic>>().reversed.toList();
        _ventas = lista;
        _totalMonto = lista
            .where((v) => v['anulada'] != true)
            .fold(0.0, (s, v) => s + _num(v['total']));
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

  String _fecha(dynamic fecha) => fechaCortaBogota(fecha);
  String _hora(dynamic fecha) => horaBogota(fecha);
  String _fechaTurno(dynamic fecha) => fechaCompletaBogota(fecha);

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
    final turnoFecha = _fechaTurno(_turnoAct['fecha']);
    final tieneAcciones =
        ApiClient.hasPermiso('ventas:eliminar') || ApiClient.isSuperadmin;
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selector de turno interno.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    tooltip: 'Turno anterior',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _idx < widget.turnos.length - 1
                                        ? () => _cambiarTurno(1)
                                        : null,
                                  ),
                                  Chip(
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
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    tooltip: 'Turno más reciente',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _idx > 0 ? () => _cambiarTurno(-1) : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Text('${_ventas.length} comandas',
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _ventas.isEmpty
                          ? const Center(child: Text('No hay comandas en este turno.', style: TextStyle(color: Colors.grey)))
                          : LayoutBuilder(
                              builder: (context, c) {
                                // Móvil / tablet angosta: tarjetas apiladas (legible).
                                // PC: tabla.
                                if (c.maxWidth < 640) {
                                  return ListView.separated(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _ventas.length + 1, // + fila total
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, i) {
                                      if (i == _ventas.length) {
                                        return Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: cs.primaryContainer,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('TOTAL · ${_ventas.length} comandas',
                                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                                              Text(money(_totalMonto),
                                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                                            ],
                                          ),
                                        );
                                      }
                                      return _cardComanda(cs, _ventas[i], tieneAcciones);
                                    },
                                  );
                                }
                                // PC: tabla original.
                                return SingleChildScrollView(
                                  padding: const EdgeInsets.all(12),
                                  child: Table(
                                  border: TableBorder.all(color: cs.outlineVariant, width: 1),
                                  columnWidths: {
                                    0: const FlexColumnWidth(2.0),
                                    1: const FlexColumnWidth(1.2),
                                    2: const FlexColumnWidth(1.0),
                                    3: const FlexColumnWidth(1.4),
                                    4: const FlexColumnWidth(1.3),
                                    5: const FlexColumnWidth(3.8),
                                    6: const FlexColumnWidth(1.2),
                                    if (tieneAcciones) 7: const FlexColumnWidth(1.6),
                                  },
                                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                  children: [
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
                                        if (tieneAcciones) _th(cs, 'Acciones'),
                                      ],
                                    ),
                                    for (final v in _ventas)
                                      TableRow(
                                        decoration: v['anulada'] == true
                                            ? BoxDecoration(color: cs.errorContainer.withValues(alpha: 0.35))
                                            : null,
                                        children: [
                                          _celda(cs, '${v['numero_factura'] ?? v['id']}',
                                              negrita: true,
                                              tachado: v['anulada'] == true,
                                              extra: v['anulada'] == true ? ' (ANULADA)' : ''),
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
                                          if (tieneAcciones) _celdaAcciones(cs, v),
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
                                        if (tieneAcciones) _celda(cs, '', negrita: true),
                                      ],
                                    ),
                                  ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  /// Card de comanda para pantallas angostas (móvil). Campos apilados y
  /// legibles en lugar de la tabla de 8 columnas.
  Widget _cardComanda(ColorScheme cs, Map<String, dynamic> v, bool tieneAcciones) {
    final anulada = v['anulada'] == true;
    final mesa = [
      if (v['numero_mesa'] != null) 'Mesa ${v['numero_mesa']}',
      if (v['escenario'] != null && v['escenario'] != 'mesa') '${v['escenario']}',
    ].where((e) => e.isNotEmpty).join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: anulada ? cs.errorContainer.withValues(alpha: 0.3) : cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${v['numero_factura'] ?? v['id']}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    decoration: anulada ? TextDecoration.lineThrough : null,
                    decorationColor: cs.error,
                  ),
                ),
              ),
              Text(_fecha(v['fecha']),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              const SizedBox(width: 8),
              Text(_hora(v['fecha']),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('Mesa: ${mesa.isEmpty ? '—' : mesa}', style: const TextStyle(fontSize: 13)),
              Text('Pago: ${v['forma_pago_nombre'] ?? '—'}', style: const TextStyle(fontSize: 13)),
              Text('Total: ${money(_num(v['total']))}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(_resumenItems((v['items'] as List? ?? []).cast<Map<String, dynamic>>()),
              style: const TextStyle(fontSize: 13)),
          if (anulada)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('ANULADA', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
            ),
          if (tieneAcciones) ...[
            const Divider(height: 12),
            _celdaAcciones(cs, v),
          ],
        ],
      ),
    );
  }

  Widget _th(ColorScheme cs, String t) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface, fontSize: 13)),
      );

  Widget _celda(ColorScheme cs, String t, {bool negrita = false, bool alinear = false, bool tachado = false, String extra = ''}) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          '$t$extra',
          textAlign: alinear ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 13,
            color: cs.onSurface,
            fontWeight: negrita ? FontWeight.w600 : FontWeight.normal,
            decoration: tachado ? TextDecoration.lineThrough : null,
            decorationColor: cs.error,
          ),
        ),
      );

  Widget _celdaAcciones(ColorScheme cs, Map<String, dynamic> v) {
    final anulada = v['anulada'] == true;
    final puedeAnular = ApiClient.hasPermiso('ventas:eliminar');
    final puedeBorrar = ApiClient.isSuperadmin;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (puedeAnular && !anulada)
            IconButton(
              icon: const Icon(Icons.cancel_outlined, size: 18),
              tooltip: 'Anular (excluir de totales)',
              visualDensity: VisualDensity.compact,
              onPressed: () => _anular(v),
            ),
          if (puedeBorrar)
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
              tooltip: 'Borrar definitivamente (solo superadmin)',
              visualDensity: VisualDensity.compact,
              onPressed: () => _borrar(v),
            ),
          if (!puedeAnular && !puedeBorrar) const Text('—'),
        ],
      ),
    );
  }

  Future<void> _anular(Map<String, dynamic> v) async {
    final id = v['id'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Anular factura'),
        content: Text('¿Anular ${v['numero_factura']} por ${money(_num(v['total']))}? '
            'El registro se conserva pero se excluye de totales, caja y resúmenes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Anular')),
        ],
      ),
    );
    if (confirm != true) return;
    final r = await ApiClient.anularVenta(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.ok ? 'Venta anulada.' : r.message)));
    if (r.ok) _cargar();
  }

  Future<void> _borrar(Map<String, dynamic> v) async {
    final id = v['id'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar factura — SUPERADMIN'),
        content: Text('¿BORRAR DEFINITIVAMENTE ${v['numero_factura']} por ${money(_num(v['total']))}? '
            'Se elimina el registro por completo y de los totales. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Borrar definitivamente'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final r = await ApiClient.eliminarVenta(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.ok ? 'Venta eliminada.' : r.message)));
    if (r.ok) _cargar();
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }
}