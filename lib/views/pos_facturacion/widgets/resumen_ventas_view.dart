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
  String? _referencia; // fecha ISO (pasado al backend según el periodo)
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _cargar();
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

  @override
  Widget build(BuildContext context) {
    final borde = 20.0;
    final gap = 16.0;

    final chips = Wrap(spacing: 8, runSpacing: 8, children: [
      for (final p in ['día', 'semana', 'mes', 'año'])
        ChoiceChip(
          label: Text(p),
          selected: _periodo == p,
          shape: const StadiumBorder(),
          onSelected: (_) => setState(() { _periodo = p; _cargar(); }),
        ),
    ]);

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
    final masV = _map(kpis['mas_vendido']);
    final semM = _map(kpis['semana_mayor']);
    final diaM = _map(kpis['dia_mayor']);

    Widget seccion(String titulo, List<Widget> hijos) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 6),
        ...hijos,
      ]);
    }

    final loMasVendido = seccion('Lo más vendido', [
      if (items.isEmpty)
        const Text('Sin datos.', style: TextStyle(color: Colors.grey))
      else
        for (final it in items.take(8))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${it['nombre']}${it['tamanio'] != null ? ' (${it['tamanio']})' : ''}'),
            subtitle: Text('×${it['cantidad']} · ${money(_num(it['subtotal']))}'),
          ),
    ]);

    final kpisLista = seccion('KPIs', [
      if (masV.isNotEmpty)
        ListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: const Text('Producto más vendido'),
          subtitle: Text('${masV['nombre']} ×${_num(masV['cantidad']).toInt()} — ${money(_num(masV['subtotal']))}')),
      if (semM.isNotEmpty)
        ListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: const Text('Semana de mayor venta'),
          subtitle: Text('${semM['semana']} — ${money(_num(semM['monto']))}')),
      if (diaM.isNotEmpty)
        ListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: const Text('Día de mayor venta'),
          subtitle: Text('${diaM['dia']} — ${money(_num(diaM['monto']))}')),
    ]);

    // Layout responsivo: se adapta al ancho real sin dejar espacio desperdiciado.
    return LayoutBuilder(builder: (context, c) {
      final ancho = c.maxWidth;
      // Nº de columnas de los KPI según el ancho disponible (llena el ancho).
      final kpiCols = ancho >= 720 ? 4 : (ancho >= 400 ? 2 : 1);
      // Dos paneles lado a lado en pantallas anchas, apilados en las angostas.
      final dosPaneles = ancho >= 720;

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GridView.count(
          crossAxisCount: kpiCols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          childAspectRatio: 1.8,
          children: [
            kpiCard('Monto', money(monto), Icons.attach_money),
            kpiCard('Ventas', '$ventas', Icons.receipt_long),
            kpiCard('Ticket promedio', money(promedio), Icons.calculate),
            kpiCard('Venta prom. diaria', money(ventaDiaria), Icons.calendar_today),
          ],
        ),
        SizedBox(height: gap),
        if (dosPaneles)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: loMasVendido),
              SizedBox(width: gap),
              Expanded(child: kpisLista),
            ],
          )
        else ...[
          loMasVendido,
          SizedBox(height: gap),
          kpisLista,
        ],
      ]);
    });
  }
}