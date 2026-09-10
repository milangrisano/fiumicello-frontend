import 'package:flutter/material.dart';
import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Module 3 — Accounting summaries.
///
/// Filters by periodo (año/mes/semana/día) with an optional reference date,
/// showing totals, items breakdown and KPIs (most-sold, best week, best day).
class ResumenVentasView extends StatefulWidget {
  const ResumenVentasView({super.key});
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
          const Text('Resúmenes contables', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          SizedBox(height: 2),
          Text('Periodo: ${(_data == null ? '' : (_data!['etiqueta'] ?? ''))}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          SizedBox(height: gap),
          contenido,
        ],
      ),
    );
  }

  Widget _renderResumen(BuildContext context, double borde, double gap) {
    final totales = (_data?['totales'] ?? {}) as Map<String, dynamic>;
    final kpis = (_data?['kpis'] ?? {}) as Map<String, dynamic>;
    final items = (_data?['items'] ?? []) as List;
    final monto = _num(totales['monto']);
    final ventas = _num(totales['ventas']).toInt();
    final promedio = _num(totales['promedio']);

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
            Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(etiqueta, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ]),
        ),
      );
    }

    // KPIs
    final masV = (kpis['mas_vendido'] ?? {}) as Map<String, dynamic>;
    final semM = (kpis['semana_mayor'] ?? {}) as Map<String, dynamic>;
    final diaM = (kpis['dia_mayor'] ?? {}) as Map<String, dynamic>;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Totales
      Center(child: Wrap(spacing: gap, runSpacing: gap, children: [
        SizedBox(width: 140, child: kpiCard('Monto', money(monto), Icons.attach_money)),
        SizedBox(width: 140, child: kpiCard('Ventas', '$ventas', Icons.receipt_long)),
        SizedBox(width: 140, child: kpiCard('Promedio', money(promedio), Icons.calculate)),
      ])),
      SizedBox(height: gap),
      const Text('Lo más vendido', style: TextStyle(fontWeight: FontWeight.w600)),
      SizedBox(height: 6),
      if (items.isNotEmpty)
        for (final it in items.take(8))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${it['nombre']}${it['tamanio'] != null ? ' (${it['tamanio']})' : ''}'),
            subtitle: Text('×${it['cantidad']} · ${money(_num(it['subtotal']))}'),
          ),
      SizedBox(height: gap),
      const Text('KPIs', style: TextStyle(fontWeight: FontWeight.w600)),
      SizedBox(height: 6),
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
  }
}