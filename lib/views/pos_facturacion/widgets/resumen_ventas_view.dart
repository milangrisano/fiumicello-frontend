import 'package:flutter/material.dart';
import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Module 3 — Accounting summaries.
///
/// Filters by periodo (año/mes/semana/día) with an optional reference date,
/// showing totals, items breakdown and KPIs (most-sold, best week, best day).
class ResumenVentasView extends StatefulWidget {
  /// Callback para volver a la pantalla anterior (las cards del POS). Si es null,
  /// se usa Navigator.pop como respaldo.
  final VoidCallback? onVolver;
  const ResumenVentasView({super.key, this.onVolver});
  @override
  State<ResumenVentasView> createState() => _ResumenVentasViewState();
}

class _ResumenVentasViewState extends State<ResumenVentasView> {
  String _periodo = 'día';
  // Fecha de referencia local (YYYY-MM-DD del dispositivo, no UTC del servidor).
  String _referencia = _fechaLocalHoy();
  DateTime _fecha = DateTime.now(); // fecha local elegida (para el picker)
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;

  /// Fecha actual en la zona horaria local del dispositivo (YYYY-MM-DD).
  static String _fechaLocalHoy() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Abre el selector de fecha y recarga el resumen con la fecha elegida.
  Future<void> _elegirFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _fecha = picked;
      _referencia =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
    await _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiClient.obtenerResumen(_periodo, _referencia);
    if (!mounted) return;
    final (ok, data, msg) = r;
    setState(() {
      _loading = false;
      if (ok) {
        _data = data;
        _error = null;
      } else {
        _data = null;
        _error = msg;
      }
    });
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  /// Convierte un valor (Map<Object,Object> de jsonDecode o Map) a Map<String,dyn>.
  Map<String, dynamic> _map(dynamic v) {
    if (v is Map<String, dynamic>) return v as Map<String, dynamic>;
    if (v is Map) return Map<String, dynamic>.from(v as Map);
    return <String, dynamic>{};
  }

  List<dynamic> _list(dynamic v) {
    if (v is List) return v as List;
    return [];
  }

  /// true si un mapa de KPI (dia/semana/mes mayor) tiene datos reales.
  bool kpisExtrasValido(Map<String, dynamic> m) =>
      m.isNotEmpty && (_num(m['monto']) > 0 || (m['dia'] ?? m['semana'] ?? m['mes']) != null);

  @override
  Widget build(BuildContext context) {
    final borde = 20.0;
    final gap = 16.0;

    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final p in ['día', 'semana', 'mes', 'año'])
          ChoiceChip(
            label: Text(p),
            selected: _periodo == p,
            shape: const StadiumBorder(),
            onSelected: (_) => setState(() { _periodo = p; _cargar(); }),
          ),
        // Botón para elegir una fecha específica (buscar facturación por día).
        IconButton(
          icon: const Icon(Icons.calendar_month),
          tooltip: 'Elegir fecha',
          onPressed: _elegirFecha,
        ),
      ],
    );

    final contenido = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: EdgeInsets.only(bottom: gap), child: chips),
      if (_loading)
        const Center(child: CircularProgressIndicator())
      else if (_error != null)
        Text('Error: $_error', style: const TextStyle(color: Colors.red))
      else if (_data == null)
        const Text('Sin datos aún.', style: TextStyle(color: Colors.grey))
      else
        _renderResumen(context, borde, gap),
    ]);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(borde, 8, borde, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (widget.onVolver != null) {
                  widget.onVolver!();
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
            const SizedBox(width: 8),
            const Text('Resumen de ventas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          ]),
          SizedBox(height: 2),
          Text('Periodo: ${(_data == null ? '' : (_data!['etiqueta'] ?? ''))}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          SizedBox(height: gap),
          contenido,
        ],
      ),
    );
  }

  Widget _renderResumen(BuildContext context, double borde, double gap) {
    final totales = _map(_data?['totales']);
    final kpis = _map(_data?['kpis']);
    final items = _list(_data?['items']);
    final serieDia = _list(_data?['serie_dia']);
    final monto = _num(totales['monto']);
    final ventas = _num(totales['ventas']).toInt();
    final promedio = _num(totales['promedio']);
    final ventaDiaria = _num(totales['venta_promedio_diaria']);

    // Tarjetas de totales
    Widget kpiCard(String etiqueta, String valor, IconData icon) {
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 6),
            Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center),
            Text(etiqueta, style: const TextStyle(color: Colors.grey, fontSize: 11), textAlign: TextAlign.center),
          ]),
        ),
      );
    }

    // KPIs
    final masCant = _map(kpis['mas_vendido_cantidad']);
    final masMonto = _map(kpis['mas_vendido_monto']);
    final semM = _map(kpis['semana_mayor']);
    final diaM = _map(kpis['dia_mayor']);
    final mesM = _map(kpis['mes_mayor']);

    Widget seccion(String titulo, List<Widget> hijos) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 6),
        ...hijos,
      ]);
    }

    // Top 3 por cantidad (descendente)
    final porCantidad = [...items]..sort((a, b) => (_num(b['cantidad']) - _num(a['cantidad'])).toInt());
    final topCant = porCantidad.take(3).toList();
    // Top 3 por monto (descendente) — items ya viene ordenado por subtotal, pero re-ordenamos por claridad
    final porMonto = [...items]..sort((a, b) => (_num(b['subtotal']) - _num(a['subtotal'])).toInt());
    final topMonto = porMonto.take(3).toList();

    // KPI extra según período
    final kpisExtraTitulo = _periodo == 'mes'
        ? 'Semana de mayor venta'
        : (_periodo == 'año' ? 'Mes de mayor venta' : 'Día de mayor venta');
    final kpisExtraValor = _periodo == 'mes'
        ? '${semM['semana']}'
        : (_periodo == 'año' ? '${mesM['mes']}' : '${diaM['dia']}');
    final kpisExtraMonto = _periodo == 'mes'
        ? semM
        : (_periodo == 'año' ? mesM : diaM);
    final tieneKpisExtra = kpisExtrasValido(kpisExtraMonto);

    final topPorCantidad = seccion('Top 3 por cantidad', [
      if (topCant.isEmpty)
        const Text('Sin datos.', style: TextStyle(color: Colors.grey))
      else
        for (final it in topCant)
          ListTile(dense: true, contentPadding: EdgeInsets.zero,
            title: Text('${it['nombre']}${it['tamanio'] != null ? ' (${it['tamanio']})' : ''}'),
            subtitle: Text('×${_num(it['cantidad']).toInt()} · ${money(_num(it['subtotal']))}')),
    ]);

    final topPorMonto = seccion('Top 3 por monto', [
      if (topMonto.isEmpty)
        const Text('Sin datos.', style: TextStyle(color: Colors.grey))
      else
        for (final it in topMonto)
          ListTile(dense: true, contentPadding: EdgeInsets.zero,
            title: Text('${it['nombre']}${it['tamanio'] != null ? ' (${it['tamanio']})' : ''}'),
            subtitle: Text('${money(_num(it['subtotal']))} · ×${_num(it['cantidad']).toInt()}')),
    ]);

    // Tarjetas KPI inferiores, con icono, igual que los 4 superiores.
    final kpiInferiores = [
      if (masCant.isNotEmpty)
        kpiCard('Más vendido (cant.)', '${masCant['nombre']} ×${_num(masCant['cantidad']).toInt()}',
            Icons.trending_up),
      if (masMonto.isNotEmpty)
        kpiCard('Más vendido (monto)', '${masMonto['nombre']} — ${money(_num(masMonto['subtotal']))}',
            Icons.attach_money),
      if (tieneKpisExtra)
        kpiCard(kpisExtraTitulo, '${kpisExtraValor} — ${money(_num(kpisExtraMonto['monto']))}',
            Icons.calendar_today),
    ];

    final kpiWidgets = [
      kpiCard('Monto', money(monto), Icons.attach_money),
      kpiCard('Ventas', '$ventas', Icons.receipt_long),
      kpiCard('Ticket promedio', money(promedio), Icons.calculate),
      kpiCard('Venta prom. diaria', money(ventaDiaria), Icons.calendar_today),
    ];

    // Layout responsivo: se adapta al ancho real sin dejar espacio desperdiciado.
    return LayoutBuilder(builder: (context, c) {
      final ancho = c.maxWidth;

      // KPIs: PC/tablet ancho -> 4 en una sola fila; móvil -> grid 2x2.
      final Widget kpisGrid;
      if (ancho >= 720) {
        kpisGrid = Row(
          children: [
            for (final k in kpiWidgets) ...[
              Expanded(child: k),
              if (k != kpiWidgets.last) SizedBox(width: gap),
            ],
          ],
        );
      } else {
        kpisGrid = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fila 1
            Row(children: [
              Expanded(child: kpiWidgets[0]),
              SizedBox(width: gap),
              Expanded(child: kpiWidgets[1]),
            ]),
            SizedBox(height: gap),
            // Fila 2
            Row(children: [
              Expanded(child: kpiWidgets[2]),
              SizedBox(width: gap),
              Expanded(child: kpiWidgets[3]),
            ]),
          ],
        );
      }

      // KPIs extras (inferiores) con icono: misma distribución que las 4 superiores.
      final Widget kpisInferioresGrid;
      if (kpiInferiores.isEmpty) {
        kpisInferioresGrid = const SizedBox.shrink();
      } else if (ancho >= 720) {
        kpisInferioresGrid = Row(
          children: [
            for (final k in kpiInferiores) ...[
              Expanded(child: k),
              if (k != kpiInferiores.last) SizedBox(width: gap),
            ],
          ],
        );
      } else {
        // Móvil: filas de 2 (y si hubiera 3º, en fila aparte).
        kpisInferioresGrid = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: kpiInferiores[0]),
              if (kpiInferiores.length > 1) ...[
                SizedBox(width: gap),
                Expanded(child: kpiInferiores[1]),
              ],
            ]),
            if (kpiInferiores.length > 2) ...[
              SizedBox(height: gap),
              Row(children: [
                Expanded(child: kpiInferiores[2]),
                if (kpiInferiores.length > 3) ...[
                  SizedBox(width: gap),
                  Expanded(child: kpiInferiores[3]),
                ],
              ]),
            ],
          ],
        );
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        kpisGrid,
        SizedBox(height: gap),
        // KPIs inferiores justo debajo de la línea de los 4 superiores.
        kpisInferioresGrid,
        const SizedBox(height: 8),
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        SizedBox(height: gap),
        // Top 3 por cantidad y por monto: SIEMPRE en 2 columnas (móvil y PC).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: topPorCantidad),
            SizedBox(width: gap),
            Expanded(child: topPorMonto),
          ],
        ),
        const SizedBox(height: 8),
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        SizedBox(height: gap),
        // Gráfico de barras de ventas por día, al final.
        _buildGraficoBarras(context, serieDia),
      ]);
    });
  }

  /// Gráfico de barras con las ventas por día del período (serie diaria).
  Widget _buildGraficoBarras(BuildContext context, List<dynamic> serie) {
    if (serie.isEmpty) {
      return const Text('Sin datos de ventas por día.', style: TextStyle(color: Colors.grey));
    }
    // Título
    final titulo = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('Ventas por día',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
    );

    final cs = Theme.of(context).colorScheme;
    final maxMonto = serie
        .map((d) => _num(d['monto']))
        .fold<double>(0, (a, b) => b > a ? b : a);
    final maxH = maxMonto > 0 ? maxMonto : 1;

    // Barras en una fila (scrollable horizontal si hay muchos días).
    final n = serie.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      titulo,
      SizedBox(
        height: 180,
        child: LayoutBuilder(builder: (context, c) {
          final anchoBarra = 14.0;
          final separacion = 6.0;
          final usable = anchoBarra + separacion;
          // Si cabe todo, distribuye; si no, deja scroll horizontal.
          final necesidad = n * usable;
          final contenido = Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final d in serie)
                Tooltip(
                  message: '${d['etiqueta']} — ${money(_num(d['monto']))}',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: anchoBarra,
                        height: (180 - 34) * (_num(d['monto']) / maxH),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Transform.rotate(
                        angle: -0.5,
                        child: Text(
                          '${(d['etiqueta'] as String).split('/').first}',
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
          return necesidad <= c.maxWidth
              ? contenido
              : SingleChildScrollView(scrollDirection: Axis.horizontal, child: contenido);
        }),
      ),
    ]);
  }
}