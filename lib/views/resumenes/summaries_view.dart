import 'package:flutter/material.dart';
import '../../core/data/api_client.dart';
import '../../core/utils/formatters.dart';

/// Module 3 — Resumen contable (haber/deber).
///
/// Muestra el cruce ventas (ingresos) vs gastos (facturas) y los movimientos
/// de dinero (comprobantes de pago) para un período seleccionable (chips
/// semana/mes/año + rango libre por calendario). Calcula la utilidad
/// = ventas − facturas.
///
/// Concilación factura↔comprobante: facturas con comprobante vinculado se
/// marcan como conciliadas; las demás quedan con un botón para asignar
/// manualmente el comprobante (trasabilidad del pago de cada factura).
class SummariesView extends StatefulWidget {
  const SummariesView({super.key});

  @override
  State<SummariesView> createState() => _SummariesViewState();
}

class _SummariesViewState extends State<SummariesView> {
  String _periodo = 'mes';
  String? _referencia;
  DateTimeRange? _rango;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  // Selectores colapsables
  final Set<String> _abiertos = {};

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _elegirRango() async {
    final hoy = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: hoy,
      initialDateRange:
          _rango ?? DateTimeRange(start: DateTime(hoy.year, hoy.month - 1, 1), end: hoy),
      helpText: 'Elegir período',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      saveText: 'Aplicar',
    );
    if (picked == null || !mounted) return;
    setState(() => _rango = picked);
    await _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    final r = _rango != null
        ? await ApiClient.obtenerContable(
            periodo: 'rango', desde: _fmt(_rango!.start), hasta: _fmt(_rango!.end))
        : await ApiClient.obtenerContable(periodo: _periodo, referencia: _referencia);
    if (!mounted) return;
    final (ok, data, msg) = r;
    setState(() {
      _loading = false;
      if (ok) { _data = data; _error = null; } else { _data = null; _error = msg; }
    });
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  List<dynamic> _list(dynamic v) => v is List ? v as List : [];

  Future<void> _asignarComprobante(Map<String, dynamic> factura) async {
    final comprobantes = _list(_data?['comprobantes_detalle']);
    final pendientes =
        comprobantes.where((c) => !((c as Map?)?['conciliado'] == true)).toList();
    if (pendientes.isEmpty) {
      _aviso('No hay comprobantes sin asignar en este período.');
      return;
    }
    final elegido = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Vincular comprobante a la factura',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            for (final c in pendientes)
              ListTile(
                title: Text('${(c as Map)['referencia'] ?? 'Comp. ${c['id']}'}'),
                subtitle: Text('${c['fecha'] ?? ''} · ${money(_num(c['monto']))}'),
                trailing: const Icon(Icons.link),
                onTap: () => Navigator.of(ctx).pop(c['id'] as int),
              ),
          ],
        ),
      ),
    );
    if (elegido == null || !mounted) return;
    final (ok, msg) = await ApiClient.asignarComprobante(factura['id'] as int, elegido);
    if (!mounted) return;
    _aviso(ok ? '✓ $msg' : 'Error: $msg');
    if (ok) await _cargar();
  }

  void _aviso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _toggle(String key) => setState(() {
        if (_abiertos.contains(key)) {
          _abiertos.remove(key);
        } else {
          _abiertos.add(key);
        }
      });

  // Tarjeta KPI genérica (método de clase)
  Widget _kpiCard(String etiqueta, double valor, IconData icon, {Color? color}) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 28, color: color ?? cs.primary),
          const SizedBox(height: 6),
          Text(money(valor),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(etiqueta,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // Panel colapsable: total + detalle (método de clase)
  Widget _panel(String titulo, String resumen, IconData icon, List<Widget> filas) {
    final cs = Theme.of(context).colorScheme;
    final abierto = _abiertos.contains(titulo);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        leading: Icon(icon, color: cs.primary),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(resumen, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        initiallyExpanded: abierto,
        onExpansionChanged: (_) => _toggle(titulo),
        children: filas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borde = 20.0;
    final gap = 16.0;

    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final p in ['semana', 'mes', 'año'])
          ChoiceChip(
            label: Text(p),
            selected: _rango == null && _periodo == p,
            shape: const StadiumBorder(),
            onSelected: (_) => setState(() {
              _periodo = p;
              _rango = null;
              _referencia = null;
              _cargar();
            }),
          ),
        IconButton(
          icon: const Icon(Icons.calendar_month),
          tooltip: 'Elegir período (rango)',
          onPressed: _elegirRango,
        ),
      ],
    );

    final contenido = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Padding(
                padding: EdgeInsets.all(borde),
                child: Text('Error: $_error',
                    style: const TextStyle(color: Colors.red)))
            : _data == null
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Sin datos aún.',
                        style: TextStyle(color: Colors.grey)))
                : _buildResumen(context, gap);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(borde, 8, borde, 16),
      // En pantallas grandes (PC/tablet) limitamos el ancho del contenido para
      // que la tarjeta de utilidad no se estire y se vea vacía; se centra.
      child: LayoutBuilder(builder: (ctx, c) {
        final maxContenido = c.maxWidth >= 720 ? 900.0 : double.infinity;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContenido),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Resumen contable',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Periodo: ${(_data?['etiqueta'] ?? '')}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                SizedBox(height: gap),
                chips,
                SizedBox(height: gap),
                contenido,
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildResumen(BuildContext context, double gap) {
    final cs = Theme.of(context).colorScheme;
    final ventas = _num(_data?['ventas']?['monto']);
    final facturas = _num(_data?['facturas']?['monto']);
    final comprobantes = _num(_data?['comprobantes']?['monto']);
    final utilidad = _num(_data?['utilidad']);
    final nVentas = _num(_data?['ventas']?['count']).toInt();
    final nFacturas = _num(_data?['facturas']?['count']).toInt();
    final nComprobantes = _num(_data?['comprobantes']?['count']).toInt();

    final facturasDetalle = _list(_data?['facturas_detalle']);
    final comprobantesDetalle = _list(_data?['comprobantes_detalle']);

    final filasFacturas = facturasDetalle.isEmpty
        ? [const ListTile(title: Text('Sin facturas en el período.'))]
        : [
            for (final f in facturasDetalle)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text('${f['proveedor'] ?? '—'} · ${f['numero_factura'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('${f['fecha'] ?? ''} — ${money(_num(f['monto']))}'),
                trailing: (f['conciliada'] == true)
                    ? const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 4),
                        Text('Conc.', style: TextStyle(color: Colors.green, fontSize: 11)),
                      ])
                    : TextButton.icon(
                        onPressed: () => _asignarComprobante(f),
                        icon: const Icon(Icons.link, size: 16),
                        label: const Text('Asignar', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8)),
                      ),
              ),
          ];

    final filasComprobantes = comprobantesDetalle.isEmpty
        ? [const ListTile(title: Text('Sin comprobantes en el período.'))]
        : [
            for (final c in comprobantesDetalle)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text('${c['referencia'] ?? 'Comp. ${c['id']}'} — ${c['beneficiario'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('${c['fecha'] ?? ''} — ${money(_num(c['monto']))}'),
                trailing: (c['conciliado'] == true)
                    ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                    : const Icon(Icons.circle_outlined, color: Colors.grey, size: 20),
              ),
          ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Utilidad destacada con degradado del acento.
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            utilidad >= 0 ? cs.primary : Colors.redAccent,
            utilidad >= 0
                ? cs.primary.withValues(alpha: 0.7)
                : Colors.redAccent.withValues(alpha: 0.7),
          ]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Utilidad',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
          Text(money(utilidad),
              style: const TextStyle(
                  color: Colors.black, fontSize: 26, fontWeight: FontWeight.bold)),
          Text(utilidad >= 0 ? 'Ingresos superan los gastos' : 'Los gastos superan los ingresos',
              style: const TextStyle(color: Colors.black87, fontSize: 12)),
        ]),
      ),
      SizedBox(height: gap),
      // Tarjetas resumen: SIEMPRE en una sola línea (móvil y PC).
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: _kpiCard('Ventas ($nVentas)', ventas, Icons.receipt_long,
                  color: cs.primary)),
          const SizedBox(width: 8),
          Expanded(
              child: _kpiCard('Gastos ($nFacturas)', facturas, Icons.receipt,
                  color: Colors.orange)),
          const SizedBox(width: 8),
          Expanded(
              child: _kpiCard('Comprobantes ($nComprobantes)', comprobantes,
                  Icons.account_balance_wallet, color: Colors.blueGrey)),
        ],
      ),
      SizedBox(height: gap),
      Divider(color: cs.outlineVariant),
      const SizedBox(height: 4),
      _panel('Gastos (facturas de compra)',
          '${facturasDetalle.length} en el período · ${money(facturas)}',
          Icons.receipt_long, filasFacturas),
      SizedBox(height: gap),
      _panel('Movimientos de dinero (comprobantes)',
          '${comprobantesDetalle.length} en el período · ${money(comprobantes)}',
          Icons.account_balance_wallet, filasComprobantes),
    ]);
  }
}