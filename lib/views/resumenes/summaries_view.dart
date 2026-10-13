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

  /// Muestra una ventana emergente con los datos completos de una fila
  /// (factura o comprobante) cuando la tabla no alcanza a mostrarlos todos.
  void _verDetalle(Map<String, dynamic> item, String titulo) {
    final amarillo = Theme.of(context).colorScheme.onSurface;
    final labels = <String, String>{
      'fecha': 'Fecha',
      'numero_factura': 'N° Factura',
      'proveedor': 'Proveedor',
      'beneficiario': 'Beneficiario',
      'referencia': 'Referencia',
      'concepto': 'Concepto',
      'metodo_pago': 'Método de pago',
      'moneda': 'Moneda',
      'estado': 'Estado',
    };
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _grisRoca, width: 1.5),
        ),
        title: Text(titulo,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in labels.entries)
                if (item[e.key] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: '${e.value}:  ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        TextSpan(
                          text: '${item[e.key]}' == 'null'
                              ? '—'
                              : '${item[e.key]}',
                          style: TextStyle(color: amarillo, fontSize: 13),
                        ),
                      ]),
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: RichText(
                  text: TextSpan(children: [
                    const TextSpan(
                      text: 'Monto:  ',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    TextSpan(
                      text: money(_num(item['monto'])),
                      style: TextStyle(color: amarillo, fontSize: 14),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _toggle(String key) => setState(() {
        if (_abiertos.contains(key)) {
          _abiertos.remove(key);
        } else {
          _abiertos.add(key);
        }
      });

  // Gris roca para bordes de las cards.
  static const Color _grisRoca = Color(0xFF7D7D7D);

  // Tarjeta KPI genérica: fondo de color, textos/iconos en amarillo pálido y
  // borde gris roca.
  Widget _kpiCard(String etiqueta, double valor, IconData icon,
      {required Color fondo}) {
    final amarillo = Theme.of(context).colorScheme.onSurface; // amarillo pálido
    return Material(
      color: fondo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _grisRoca, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: amarillo),
              const SizedBox(height: 6),
              Text(money(valor),
                  style: TextStyle(
                      color: amarillo, fontWeight: FontWeight.bold, fontSize: 15),
                  textAlign: TextAlign.center),
              const SizedBox(height: 2),
              Text(etiqueta,
                  style: TextStyle(color: amarillo, fontSize: 11),
                  textAlign: TextAlign.center),
            ]),
      ),
    );
  }

  // Panel colapsable: total + detalle (método de clase). Borde gris roca.
  Widget _panel(String titulo, String resumen, IconData icon, List<Widget> filas) {
    final cs = Theme.of(context).colorScheme;
    final amarillo = cs.onSurface; // amarillo pálido
    final abierto = _abiertos.contains(titulo);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _grisRoca, width: 1.5),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: cs.primary),
        title: Text(titulo,
            style: TextStyle(color: amarillo, fontWeight: FontWeight.w600)),
        subtitle: Text(resumen, style: TextStyle(color: amarillo, fontSize: 12)),
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

    final amarilloTxt = cs.onSurface; // amarillo pálido para celdas
    const turquesa = Color(0xFF2FB9A6);

    // Facturas — tabla con columnas completas (Proveedor, N°, Fecha, Monto,
    // Estado). Scroll horizontal para no salir del ancho. Click en fila => detalle.
    final tablaFacturas = facturasDetalle.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Sin facturas en el período.',
                style: TextStyle(color: Colors.grey)))
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              horizontalMargin: 10,
              headingTextStyle: TextStyle(
                  color: amarilloTxt, fontWeight: FontWeight.bold, fontSize: 12),
              dataTextStyle: TextStyle(color: amarilloTxt, fontSize: 12),
              columns: const [
                DataColumn(label: Text('Proveedor')),
                DataColumn(label: Text('N° Factura')),
                DataColumn(label: Text('Fecha')),
                DataColumn(label: Text('Monto'), numeric: true),
                DataColumn(label: Text('Estado')),
              ],
              rows: [
                for (final f in facturasDetalle)
                  DataRow(
                    onSelectChanged: (_) => _verDetalle(f, 'Detalle factura'),
                    cells: [
                      DataCell(SizedBox(
                        width: 130,
                        child: Text('${f['proveedor'] ?? '—'}',
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                      )),
                      DataCell(Text('${f['numero_factura'] ?? ''}')),
                      DataCell(Text('${f['fecha'] ?? ''}')),
                      DataCell(Text(money(_num(f['monto'])))),
                      DataCell((f['conciliada'] == true)
                          ? const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 18),
                              SizedBox(width: 4),
                              Text('Conciliada',
                                  style: TextStyle(color: Colors.green, fontSize: 11)),
                            ])
                          : TextButton.icon(
                              onPressed: () => _asignarComprobante(f),
                              icon: const Icon(Icons.link, size: 16),
                              label: const Text('Asignar',
                                  style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6)),
                            )),
                    ],
                  ),
              ],
            ),
          );

    // Comprobantes — tabla con Tipo (Transferencia/Proveedor), Referencia,
    // Fecha, Monto, Estado. Scroll horizontal. Click en fila => detalle.
    final tablaComprobantes = comprobantesDetalle.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Sin comprobantes en el período.',
                style: TextStyle(color: Colors.grey)))
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              horizontalMargin: 10,
              headingTextStyle: TextStyle(
                  color: amarilloTxt, fontWeight: FontWeight.bold, fontSize: 12),
              dataTextStyle: TextStyle(color: amarilloTxt, fontSize: 12),
              columns: const [
                DataColumn(label: Text('Tipo')),
                DataColumn(label: Text('Referencia')),
                DataColumn(label: Text('Fecha')),
                DataColumn(label: Text('Monto'), numeric: true),
                DataColumn(label: Text('Estado')),
              ],
              rows: [
                for (final c in comprobantesDetalle)
                  DataRow(
                    onSelectChanged: (_) => _verDetalle(c, 'Detalle comprobante'),
                    cells: [
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          c['tipo'] == 'transferencia'
                              ? Icons.swap_horiz
                              : Icons.paid,
                          size: 16,
                          color: c['tipo'] == 'transferencia'
                              ? turquesa
                              : Colors.orangeAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(c['tipo'] == 'transferencia'
                            ? 'Transferencia'
                            : 'Proveedor'),
                      ])),
                      DataCell(SizedBox(
                        width: 120,
                        child: Text('${c['referencia'] ?? 'Comp. ${c['id']}'}',
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                      )),
                      DataCell(Text('${c['fecha'] ?? ''}')),
                      DataCell(Text(money(_num(c['monto'])))),
                      DataCell((c['conciliado'] == true)
                          ? const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 18),
                              SizedBox(width: 4),
                              Text('Conciliado',
                                  style: TextStyle(color: Colors.green, fontSize: 11)),
                            ])
                          : const Text('Pendiente',
                              style: TextStyle(color: Colors.grey, fontSize: 11))),
                    ],
                  ),
              ],
            ),
          );

    // 4 tarjetas: Utilidad, Ventas, Gastos, Comprobantes.
    // Grid: móvil (ancho < 700) => 2x2; PC/tablet => 4x1.
    final amarillo = cs.onSurface; // amarillo pálido
    final cardUtilidad = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            utilidad >= 0 ? turquesa : Colors.redAccent,
            utilidad >= 0
                ? turquesa.withValues(alpha: 0.75)
                : Colors.redAccent.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _grisRoca, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.savings, size: 28, color: amarillo),
          const SizedBox(height: 6),
          Text(money(utilidad),
              style: TextStyle(
                  color: amarillo, fontWeight: FontWeight.bold, fontSize: 15),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('Utilidad',
              style: TextStyle(color: amarillo, fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );

    final cards = [
      cardUtilidad,
      _kpiCard('Ventas ($nVentas)', ventas, Icons.receipt_long,
          fondo: const Color(0xFF2FB9A6)), // turquesa
      _kpiCard('Gastos ($nFacturas)', facturas, Icons.receipt,
          fondo: const Color(0xFFC65D3B)), // terracota
      _kpiCard('Comprobantes ($nComprobantes)', comprobantes,
          Icons.account_balance_wallet,
          fondo: const Color(0xFFC65D3B)), // terracota
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (ctx, c) {
        if (c.maxWidth >= 700) {
          // PC/tablet: 4 en una sola fila, misma altura (stretch + IntrinsicHeight).
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  Expanded(child: cards[i]),
                  if (i < cards.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          );
        }
        // Móvil: grid 2x2, cada fila con altura uniforme.
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
            ]),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 10),
              Expanded(child: cards[3]),
            ]),
          ),
        ]);
      }),
      SizedBox(height: gap),
      Divider(color: cs.outlineVariant),
      const SizedBox(height: 4),
      _panel('Gastos (facturas de compra)',
          '${facturasDetalle.length} en el período · ${money(facturas)}',
          Icons.receipt_long, [tablaFacturas]),
      SizedBox(height: gap),
      _panel('Movimientos de dinero (comprobantes)',
          'Transferencias ${money(_num(_data?['comprobantes_transferencias']?['monto']))}'
          ' (${_num(_data?['comprobantes_transferencias']?['count']).toInt()}) · '
          'Proveedores ${money(_num(_data?['comprobantes_proveedores']?['monto']))}'
          ' (${_num(_data?['comprobantes_proveedores']?['count']).toInt()}) · '
          'Total ${money(comprobantes)}',
          Icons.account_balance_wallet, [tablaComprobantes]),
    ]);
  }
}