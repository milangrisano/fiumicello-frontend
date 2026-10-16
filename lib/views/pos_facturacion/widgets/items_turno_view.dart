import 'package:flutter/material.dart';
import 'package:web/web.dart' show HTMLAnchorElement, document;
import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Ítems vendidos AGRUPADOS por producto + tamaño: cada producto aparece una
/// sola vez con la cantidad total y el subtotal facturado en el periodo.
/// Selector de periodo: Turno / Semana / Mes / Rango (calendario), con botón
/// de exportar a Excel, contador junto al cajón de periodo y total fijo bajo
/// el selector (misma estructura que "Por Comandas"). Ordenable por Cantidad
/// y Subtotal.
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

  // Selector de periodo: 'turno' (como antes), 'semana', 'mes' o 'rango' (calendario).
  String _modo = 'turno';
  DateTimeRange? _rango;

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

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Rango (desde, hasta) según el modo seleccionado (sin modo turno).
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
    return null;
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    final ListResult r;
    if (_modo == 'turno') {
      r = await ApiClient.obtenerVentasTurno(_turnoAct['id'] as int);
    } else {
      final rango = _rangoActual();
      if (rango == null) {
        setState(() => _loading = false);
        return;
      }
      r = await ApiClient.obtenerVentasPeriodo(rango.$1, rango.$2);
    }
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

  Future<void> _elegirRango() async {
    final hoy = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: hoy,
      initialDateRange: _rango,
      helpText: 'Elegir período',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      saveText: 'Aplicar',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _rango = picked;
      _modo = 'rango';
    });
    await _cargar();
  }

  void _cambiarModo(String m) {
    setState(() => _modo = m);
    if (m == 'rango') {
      _elegirRango();
    } else {
      _cargar();
    }
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

  String _fechaTurno(dynamic fecha) => fechaCompletaBogota(fecha);

  /// Etiqueta del período actual (para el nombre del archivo a exportar).
  String _etiquetaPeriodo() {
    if (_modo == 'turno') return 'turno-${_turnoAct['id']}';
    if (_modo == 'rango' && _rango != null) {
      return '${_fmt(_rango!.start)}_${_fmt(_rango!.end)}';
    }
    if (_modo == 'semana') {
      final hoy = DateTime.now();
      final lunes = hoy.subtract(Duration(days: hoy.weekday - 1));
      return 'semana-${_fmt(lunes)}';
    }
    final hoy = DateTime.now();
    return 'mes-${hoy.year}-${hoy.month.toString().padLeft(2, '0')}';
  }

  /// CSV de los ítems mostrados (Excel-friendly: BOM UTF-8, ';' como separador).
  String _csv() {
    final b = StringBuffer();
    b.write('\uFEFF'); // BOM para que Excel lea bien las tildes.
    b.write('Producto;Tamanio;Cantidad;Subtotal\n');
    for (final f in _filas) {
      final celda = (String s) => '${s.replaceAll(';', ' - ')}';
      b.write(
          '${celda('${f['nombre'] ?? ''}')};'
          '${celda('${(f['tamanio'] ?? '').isEmpty ? '—' : f['tamanio']}')};'
          '${f['cantidad']};'
          '${_num(f['subtotal']).toStringAsFixed(2).replaceAll('.', ',')}\n');
    }
    b.write(
        ';TOTAL;$_totalCantidad;'
        '${_totalMonto.toStringAsFixed(2).replaceAll('.', ',')}\n');
    return b.toString();
  }

  /// Descarga un archivo (CSV/Excel) vía un data-URI + anchor del navegador.
  void _descargar(String contenido, String nombre) {
    final dataUri = 'data:text/csv;charset=utf-8,${Uri.encodeComponent(contenido)}';
    final a = document.createElement('a') as HTMLAnchorElement;
    a.href = dataUri;
    a.download = nombre;
    document.body!.appendChild(a);
    a.click();
    a.remove();
  }

  /// Exporta los ítems visibles a un archivo CSV (abre en Excel).
  void _exportarCsv() {
    if (_filas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('No hay ítems para exportar.')));
      return;
    }
    _descargar(_csv(), 'items_${_etiquetaPeriodo()}.csv');
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
        title: const Text('Por ítem'),
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
                    // Selector de periodo: chips Turno/Semana/Mes + calendario y, a la
                    // derecha, el botón de exportar a Excel. El contador de ítems
                    // vive junto al cajón de periodo (abajo), y el total queda fijo
                    // bajo esa línea.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final m in ['turno', 'semana', 'mes'])
                            ChoiceChip(
                              label: Text(m == 'turno'
                                  ? 'Turno'
                                  : (m == 'semana' ? 'Semana' : 'Mes')),
                              selected: _modo == m,
                              shape: const StadiumBorder(),
                              onSelected: (_) => _cambiarModo(m),
                            ),
                          if (_modo == 'rango')
                            ChoiceChip(
                              label: Text(_rango == null
                                  ? 'Rango'
                                  : '${_fmt(_rango!.start)} → ${_fmt(_rango!.end)}'),
                              // Texto oscuro para que no se pierda sobre el turquesa.
                              labelStyle:
                                  const TextStyle(color: Colors.black, fontSize: 13),
                              selected: true,
                              shape: const StadiumBorder(),
                            ),
                          IconButton(
                            icon: const Icon(Icons.calendar_month),
                            tooltip: 'Elegir período (rango)',
                            onPressed: _elegirRango,
                          ),
                          // Exportar a Excel (CSV) al lado derecho de los chips.
                          IconButton(
                            icon: const Icon(Icons.download),
                            tooltip: 'Exportar a Excel',
                            onPressed: _exportarCsv,
                          ),
                        ],
                      ),
                    ),
                    // Selector de turno interno (solo en modo Turno) con el
                    // contador de ítems junto al cajón.
                    if (_modo == 'turno')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
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
                            Text('${_filas.length} ítems',
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text('${_filas.length} ítems',
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                        ),
                      ),
                    // Total fijo bajo la línea del cuadro de periodo.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('TOTAL · $_totalCantidad uds',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(money(_totalMonto),
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _filas.isEmpty
                          ? const Center(child: Text('No hay ítems en este periodo.', style: TextStyle(color: Colors.grey)))
                          : LayoutBuilder(
                              builder: (context, c) {
                                if (c.maxWidth < 640) {
                                  // Móvil: lista de tarjetas por producto.
                                  return ListView.separated(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _filas.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, i) {
                                      final f = _filas[i];
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: cs.surfaceContainerHighest,
                                          border: Border.all(color: cs.outlineVariant),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('${f['nombre'] ?? ''}',
                                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                                  Text('Tamaño: ${(f['tamanio'] ?? '').isEmpty ? '—' : f['tamanio']}',
                                                      style: const TextStyle(fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text('×${f['cantidad']}',
                                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                                Text(money(_num(f['subtotal'])),
                                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                }
                                // PC: tabla original.
                                return SingleChildScrollView(
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
                                  // El total va FIJO bajo el selector de periodo.
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