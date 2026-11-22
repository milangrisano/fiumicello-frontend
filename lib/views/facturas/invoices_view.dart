import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../core/data/api_client.dart';
import '../../core/services/realtime_service.dart';
import '../../core/utils/formatters.dart';
import '../pos_facturacion/widgets/facturas_items_view.dart';

/// Module 1 — Invoices and payment vouchers.
///
/// Contains two tabs: purchase invoices ("Facturas de compra") and payment
/// vouchers ("Comprobantes de pago"). Loading/error states are handled.
class InvoicesView extends StatelessWidget {
  const InvoicesView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(tabs: [
            Tab(text: 'Facturas de compra'),
            Tab(text: 'Comprobantes de pago'),
            Tab(text: 'Ítems de facturas'),
          ]),
          const Expanded(
            child: TabBarView(children: [
              FacturasList(),
              ComprobantesList(),
              FacturasItemsView(embebido: true),
            ]),
          ),
        ],
      ),
    );
  }
}

class FacturasList extends StatefulWidget {
  const FacturasList({super.key});

  @override
  State<FacturasList> createState() => _FacturasListState();
}

class _FacturasListState extends State<FacturasList> {
  late Future<Map<String, dynamic>> _future;

  // Filtro de período: 'año' | 'mes' | 'semana' (chips) o rango libre del
  // calendario. Es un ATAJO de fecha; el buscador server-side combina todo.
  String _periodo = 'mes';
  DateTimeRange? _rango;

  // Panel de filtros avanzados (Desde/Hasta + montos): se despliega bajo los
  // atajos de período cuando el usuario lo abre, para no abarrotar la barra.
  bool _filtrosAvanzados = false;

  // Buscador SERVER-SIDE combinable: cada campo lleno se suma a la consulta
  // (vacío = no filtra). Se puede combinar texto + fechas + montos a la vez.
  final TextEditingController _qCtrl = TextEditingController();
  // Fechas del formulario (además del atajo de los chips).
  final TextEditingController _diaDesdeCtrl = TextEditingController();
  final TextEditingController _mesDesdeCtrl = TextEditingController();
  final TextEditingController _anioDesdeCtrl = TextEditingController();
  final TextEditingController _diaHastaCtrl = TextEditingController();
  final TextEditingController _mesHastaCtrl = TextEditingController();
  final TextEditingController _anioHastaCtrl = TextEditingController();
  final TextEditingController _montoMinCtrl = TextEditingController();
  final TextEditingController _montoMaxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _buildFuture();
    // Asegura el socket conectado (para el evento factura:nueva).
    RealtimeService.instance.conectar();
    // Actualiza la lista al instante cuando el workflow/backend crea una
    // factura nueva (evento factura:nueva del Socket.IO).
    RealtimeService.instance.on('factura:nueva', (_) {
      if (!mounted) return;
      setState(() {
        _future = _buildFuture();
      });
    });
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    _diaDesdeCtrl.dispose();
    _mesDesdeCtrl.dispose();
    _anioDesdeCtrl.dispose();
    _diaHastaCtrl.dispose();
    _mesHastaCtrl.dispose();
    _anioHastaCtrl.dispose();
    _montoMinCtrl.dispose();
    _montoMaxCtrl.dispose();
    super.dispose();
  }

  /// Construye la petición al backend con TODOS los filtros activos.
  /// Los campos vacíos se omiten; los que tengan valor se combinan en la query.
  Future<Map<String, dynamic>> _buildFuture() {
    final params = <String>[];

    // Chips/atajo de período (si no hay fechas manuales del formulario).
    final tieneDesdeManual =
        _diaDesdeCtrl.text.isNotEmpty ||
            _mesDesdeCtrl.text.isNotEmpty ||
            _anioDesdeCtrl.text.isNotEmpty;
    final tieneHastaManual =
        _diaHastaCtrl.text.isNotEmpty ||
            _mesHastaCtrl.text.isNotEmpty ||
            _anioHastaCtrl.text.isNotEmpty;

    String? desde;
    String? hasta;
    if (tieneDesdeManual || tieneHastaManual) {
      // Fechas manuales del formulario (YYYY-MM-DD, campos incompletos→01).
      desde = _fechaDesdeManual();
      hasta = _fechaHastaManual();
    } else if (_rango != null) {
      desde = _fmt(_rango!.start);
      hasta = _fmt(_rango!.end);
    } else {
      final hoy = DateTime.now();
      if (_periodo == 'año') {
        desde = '${hoy.year}-01-01';
        hasta = '${hoy.year}-12-31';
      } else if (_periodo == 'mes') {
        desde = _fmt(DateTime(hoy.year, hoy.month, 1));
        hasta = _fmt(DateTime(hoy.year, hoy.month + 1, 0));
      } else {
        final lunes = hoy.subtract(Duration(days: hoy.weekday - 1));
        desde = _fmt(lunes);
        hasta = _fmt(lunes.add(const Duration(days: 6)));
      }
    }
    if (desde != null && desde.isNotEmpty) params.add('desde=$desde');
    if (hasta != null && hasta.isNotEmpty) params.add('hasta=$hasta');

    // Texto libre global (# factura / proveedor / concepto).
    final q = _qCtrl.text.trim();
    if (q.isNotEmpty) params.add('q=${Uri.encodeQueryComponent(q)}');

    // Montos.
    final mMin = _montoMinCtrl.text.trim();
    final mMax = _montoMaxCtrl.text.trim();
    if (mMin.isNotEmpty) params.add('montoMin=${Uri.encodeQueryComponent(mMin)}');
    if (mMax.isNotEmpty) params.add('montoMax=${Uri.encodeQueryComponent(mMax)}');

    final url = '/facturas?limit=500&${params.join('&')}';
    return ApiClient.getList(url);
  }

  /// YYYY-MM-DD a partir de los tres campos Desde (incompletos→01).
  String _fechaDesdeManual() {
    final d = _diaDesdeCtrl.text.trim().padLeft(2, '0');
    final m = _mesDesdeCtrl.text.trim().padLeft(2, '0');
    final a = _anioDesdeCtrl.text.trim();
    return '${a.isNotEmpty ? a : '2024'}-${m.isNotEmpty ? m : '01'}-${d.isNotEmpty ? d : '01'}';
  }

  /// YYYY-MM-DD a partir de los tres campos Hasta (incompletos→31).
  String _fechaHastaManual() {
    final d = _diaHastaCtrl.text.trim().padLeft(2, '0');
    final m = _mesHastaCtrl.text.trim().padLeft(2, '0');
    final a = _anioHastaCtrl.text.trim();
    return '${a.isNotEmpty ? a : '2099'}-${m.isNotEmpty ? m : '12'}-${d.isNotEmpty ? d : '31'}';
  }

  void _buscar() => setState(() => _future = _buildFuture());

  /// Formatea una fecha como YYYY-MM-DD (cero-padding) para la query.
  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Mismo calendario de rango que en Resumen contable: se eligen dos días
  /// (inicio y fin) y se pulsa Aplicar.
  Future<void> _elegirRango() async {
    final hoy = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: hoy,
      initialDateRange: _rango ??
          DateTimeRange(start: DateTime(hoy.year, hoy.month - 1, 1), end: hoy),
      helpText: 'Elegir período',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      saveText: 'Aplicar',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _rango = picked;
      _future = _buildFuture();
    });
  }

  /// Descripción de la factura: concepto si existe; si no, el proveedor.
  String _descripcion(Map<String, dynamic> f) {
    final c = (f['concepto'] ?? '').toString().trim();
    if (c.isNotEmpty) return c;
    final p = (f['proveedor'] ?? '').toString().trim();
    return p.isNotEmpty ? p : '—';
  }

  /// Filtros de la vista de facturas (server-side combinables).
  ///
  /// Barra ordenada: los atajos de PERÍODO (año/mes/semana + calendario) y el
  /// buscador de TEXTO siempre visibles; el resto (fechas manuales Desde/Hasta
  /// y montos mín/máx) vive en un panel desplegable bajo un botón CIRCULAR de
  /// filtros avanzados. En PC toda la fila va CENTRADA; en móvil se divide en
  /// 2 líneas (chips arriba, recuadro + botón abajo). Todo campo lleno se suma
  /// a la query (vacío = no filtra).
  Widget _filtros(ColorScheme cs) {
    final inputDeco = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: cs.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );

    // Chips de período + calendario (atajos de fecha).
    Widget chipsPeriodo() => Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final p in ['año', 'mes', 'semana'])
          ChoiceChip(
            label: Text(p),
            selected: _rango == null && _periodo == p,
            shape: const StadiumBorder(),
            onSelected: (_) {
              setState(() {
                _periodo = p;
                _rango = null;
                _future = _buildFuture();
              });
            },
          ),
        IconButton(
          icon: const Icon(Icons.calendar_month),
          tooltip: 'Elegir período (rango)',
          onPressed: _elegirRango,
        ),
      ],
    );

    // Campo de texto global (# factura / proveedor / concepto).
    // width null => toma el ancho disponible (móvil) via Flexible.
    Widget campoTexto({double? width}) => SizedBox(
      width: width,
      child: TextField(
        controller: _qCtrl,
        decoration: inputDeco.copyWith(
          hintText: 'Proveedor, # factura o descripción…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _qCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _qCtrl.clear();
                    setState(() {});
                  },
                ),
        ),
        onSubmitted: (_) => _buscar(),
      ),
    );

    // Botón circular que despliega/pliega los filtros avanzados.
    Widget botonFiltros() => FilledButton.tonalIcon(
      onPressed: () => setState(() => _filtrosAvanzados = !_filtrosAvanzados),
      style: FilledButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(10),
      ),
      icon: Icon(
        _filtrosAvanzados ? Icons.expand_less : Icons.tune,
        size: 22,
      ),
      label: const Text(''),
    );

    // Panel avanzado (expandible): fechas + montos + botones.
    Widget panelAvanzado() => AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: _filtrosAvanzados
          ? Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, size: 18),
                        const SizedBox(width: 6),
                        Text('Rango de fechas',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.clear_all, size: 18),
                          tooltip: 'Vaciar fechas',
                          onPressed: () {
                            for (final c in [
                              _diaDesdeCtrl, _mesDesdeCtrl,
                              _anioDesdeCtrl, _diaHastaCtrl,
                              _mesHastaCtrl, _anioHastaCtrl,
                            ]) {
                              c.clear();
                            }
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _campoFecha1(inputDeco, cs, 'Desde',
                            _diaDesdeCtrl, _mesDesdeCtrl, _anioDesdeCtrl),
                        _campoFecha1(inputDeco, cs, 'Hasta',
                            _diaHastaCtrl, _mesHastaCtrl, _anioHastaCtrl),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _montoMinCtrl,
                            decoration:
                                inputDeco.copyWith(hintText: 'Monto mín'),
                            keyboardType: const TextInputType
                                .numberWithOptions(decimal: true),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _montoMaxCtrl,
                            decoration:
                                inputDeco.copyWith(hintText: 'Monto máx'),
                            keyboardType: const TextInputType
                                .numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_hayBusqueda)
                            TextButton.icon(
                              onPressed: _limpiarBusqueda,
                              icon: const Icon(Icons.filter_alt_off, size: 18),
                              label: const Text('Limpiar'),
                            ),
                          FilledButton.icon(
                            onPressed: _buscar,
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('Buscar'),
                          ),
                        ]),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );

    // Barra superior según el ancho: centrada en PC, 2 líneas en móvil.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (ctx, c) {
            final esMovil = c.maxWidth < 700;
            if (esMovil) {
              // Móvil: 2 líneas — chips arriba, recuadro + botón abajo.
              return Column(
                children: [
                  Center(child: chipsPeriodo()),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(child: campoTexto()),
                      const SizedBox(width: 4),
                      botonFiltros(),
                    ],
                  ),
                ],
              );
            }
            // PC: todo centrado en una fila.
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                chipsPeriodo(),
                const SizedBox(width: 10),
                campoTexto(width: 300),
                const SizedBox(width: 4),
                botonFiltros(),
              ],
            );
          }),
          panelAvanzado(),
        ],
      ),
    );
  }
  /// Tres recuadros DD / MM / AAAA con una etiqueta (Desde/Hasta).
  Widget _campoFecha1(InputDecoration inputDeco, ColorScheme cs, String label,
      TextEditingController dia, TextEditingController mes,
      TextEditingController anio) {
    final deco = (String hint) => inputDeco.copyWith(hintText: hint);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        const SizedBox(width: 6),
        _inputCorto(deco('DD'), dia, 2, mes),
        const SizedBox(width: 5),
        Text('/', style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(width: 5),
        _inputCorto(deco('MM'), mes, 2, anio),
        const SizedBox(width: 5),
        Text('/', style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(width: 5),
        _inputCorto(deco('AAAA'), anio, 4, null),
      ],
    );
  }

  /// Input numérico corto (DD/MM/AAAA) con salto automático al siguiente.
  Widget _inputCorto(InputDecoration deco, TextEditingController ctrl, int maxLen,
      TextEditingController? next) {
    return SizedBox(
      width: maxLen == 2 ? 44 : 60,
      child: TextField(
        controller: ctrl,
        decoration: deco,
        keyboardType: TextInputType.number,
        maxLength: maxLen,
        textAlign: TextAlign.center,
        buildCounter: (BuildContext context,
                {required int currentLength,
                required bool isFocused,
                required int? maxLength}) =>
            null,
        style: const TextStyle(fontSize: 13.5),
        onChanged: (_) {
          setState(() {});
          // Al completar el campo, salta el foco al siguiente (DD→MM→AAAA).
          if (next != null && ctrl.text.length == maxLen) {
            FocusScope.of(context).nextFocus();
          }
        },
        onSubmitted: (_) => _buscar(),
      ),
    );
  }

  bool get _hayBusqueda =>
      _qCtrl.text.trim().isNotEmpty ||
      _diaDesdeCtrl.text.trim().isNotEmpty ||
      _mesDesdeCtrl.text.trim().isNotEmpty ||
      _anioDesdeCtrl.text.trim().isNotEmpty ||
      _diaHastaCtrl.text.trim().isNotEmpty ||
      _mesHastaCtrl.text.trim().isNotEmpty ||
      _anioHastaCtrl.text.trim().isNotEmpty ||
      _montoMinCtrl.text.trim().isNotEmpty ||
      _montoMaxCtrl.text.trim().isNotEmpty;

  void _limpiarBusqueda() {
    _qCtrl.clear();
    _diaDesdeCtrl.clear();
    _mesDesdeCtrl.clear();
    _anioDesdeCtrl.clear();
    _diaHastaCtrl.clear();
    _mesHastaCtrl.clear();
    _anioHastaCtrl.clear();
    _montoMinCtrl.clear();
    _montoMaxCtrl.clear();
    setState(() => _future = _buildFuture());
  }

  // Celda de la tabla (PC): ancho flexible y alineación opcional a la derecha.
  Widget _celda(String t,
      {int flex = 1, bool right = false, bool bold = false, Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(
        t,
        textAlign: right ? TextAlign.right : TextAlign.left,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  /// Tabla ordenada para PC: Fecha · # Factura · Descripción · Monto.
  Widget _tabla(BuildContext context, ColorScheme cs, List<Map<String, dynamic>> items) {
    return Column(
      children: [
        Container(
          color: cs.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            _celda('Fecha', flex: 12, bold: true),
            _celda('# Factura', flex: 14, bold: true),
            _celda('Descripción', flex: 34, bold: true),
            _celda('Monto', flex: 14, right: true, bold: true),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant),
            itemBuilder: (context, i) {
              final f = items[i];
              return InkWell(
                onTap: () => _openDetail(context, f['id']),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(children: [
                    _celda('${f['fecha'] ?? '—'}', flex: 12),
                    _celda('${f['numero_factura'] ?? '—'}', flex: 14),
                    _celda(_descripcion(f), flex: 34),
                    _celda(money(f['total_con_impuestos']), flex: 14, right: true, bold: true),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error de conexión con el backend.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        final data = snapshot.data!;
        final total = data['total'] ?? 0;
        final raw = data['data'] as List? ?? [];
        final items =
            raw.map((e) => Map<String, dynamic>.from(e)).toList();
        double suma = 0;
        for (final f in items) {
          final v = f['total_con_impuestos'];
          if (v is num) suma += v.toDouble();
          else if (v is String) suma += double.tryParse(v) ?? 0;
        }
        return Column(
          children: [
            _filtros(cs),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(children: [
                const Icon(Icons.store, size: 18),
                const SizedBox(width: 8),
                Text(
                  _hayBusqueda
                      ? '${items.length} resultados de $total facturas de compra'
                      : '$total facturas de compra',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(money(suma),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ),
            Expanded(
              child: LayoutBuilder(builder: (ctx, c) {
                // PC/tablet: tabla ordenada. Móvil: lista de tarjetas.
                if (c.maxWidth >= 700) return _tabla(context, cs, items);
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final f = items[i];
                    return ListTile(
                      title: Text(_descripcion(f)),
                      subtitle: Text('${f['fecha'] ?? '-'} · ${f['numero_factura'] ?? '-'}'),
                      trailing: Text(money(f['total_con_impuestos']),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () => _openDetail(context, f['id']),
                    );
                  },
                );
              }),
            ),
          ],
        );
      },
    );
  }

  void _openDetail(BuildContext context, dynamic id) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(child: FacturaDetail(id: id)),
        actions: [
          if (ApiClient.isSuperadmin || ApiClient.isAdmin)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _borrar(context, id, null);
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Borrar factura'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Muestra el documento: imagen a pantalla completa (con zoom), o vista
  /// previa en ventana si es PDF.
  void _verImagen(BuildContext context, String archivo) {
    final url = _archivoUrl(archivo);
    final esImagen = RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false)
        .hasMatch(archivo);
    if (!esImagen) {
      // PDF u otro documento: abrir DIRECTO en el visor del navegador (igual que
      // el botón "Abrir" nativo, sin pantalla intermedia ni iframe). Con
      // Content-Disposition: inline el navegador renderiza el PDF en su visor.
      web.window.open(url, '_blank');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No se pudo cargar la imagen.',
                    style: TextStyle(color: Colors.white)),
              )),
        ),
      ),
    );
  }

  Future<void> _borrar(BuildContext context, dynamic id, String? nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar factura'),
        content: Text('¿Seguro que quieres borrar la factura ${nombre ?? ''}?\nEsta acción es permanente y definitiva.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirm != true || id == null) return;
    final r = await ApiClient.borrarFactura(id as int);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r.ok ? 'Factura borrada.' : 'Error: ${r.message}')),
    );
    if (r.ok) setState(() => _future = _buildFuture());
  }
}

class FacturaDetail extends StatefulWidget {
  final dynamic id;
  const FacturaDetail({super.key, required this.id});

  @override
  State<FacturaDetail> createState() => _FacturaDetailState();
}

class _FacturaDetailState extends State<FacturaDetail> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.getJson('/facturas/${widget.id}/items');
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
                height: 200, child: Center(child: CircularProgressIndicator()));
          }
          final data = snapshot.data ?? {};
          final factura = Map<String, dynamic>.from(data['factura'] ?? {});
          final items2 = data['items'] as List? ?? [];
          final items = items2.map((e) => Map<String, dynamic>.from(e)).toList();
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Factura #${factura['numero_factura']}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (factura['archivo'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: _ImagenDoc(archivo: factura['archivo'] as String),
                      ),
                    Text('Proveedor: ${factura['proveedor'] ?? '-'}'),
                    Text('Fecha: ${factura['fecha'] ?? '-'}'),
                    Text('Estado: ${factura['estado'] ?? '-'}'),
                    const Divider(height: 24),
                    Text('Ítems (${items.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              ...items.map((it) => ListTile(
                    dense: true,
                    title: Text(it['descripcion'] ?? '-'),
                    subtitle: Text('Cant: ${it['cantidad'] ?? '-'} · Cat: ${it['categoria'] ?? '-'}'),
                    trailing: Text(money(it['total'])),
                  )),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(money(factura['total_con_impuestos']),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ComprobantesList extends StatefulWidget {
  const ComprobantesList({super.key});

  @override
  State<ComprobantesList> createState() => _ComprobantesListState();
}

class _ComprobantesListState extends State<ComprobantesList> {
  late Future<Map<String, dynamic>> _future;
  String _periodo = 'mes';
  DateTimeRange? _rango;
  bool _filtrosAvanzados = false;

  final TextEditingController _qCtrl = TextEditingController();
  final TextEditingController _diaDesdeCtrl = TextEditingController();
  final TextEditingController _mesDesdeCtrl = TextEditingController();
  final TextEditingController _anioDesdeCtrl = TextEditingController();
  final TextEditingController _diaHastaCtrl = TextEditingController();
  final TextEditingController _mesHastaCtrl = TextEditingController();
  final TextEditingController _anioHastaCtrl = TextEditingController();
  final TextEditingController _montoMinCtrl = TextEditingController();
  final TextEditingController _montoMaxCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _buildFuture();
  }

  @override
  void dispose() {
    for (final c in [_qCtrl, _diaDesdeCtrl, _mesDesdeCtrl, _anioDesdeCtrl,
      _diaHastaCtrl, _mesHastaCtrl, _anioHastaCtrl, _montoMinCtrl, _montoMaxCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Map<String, dynamic>> _buildFuture() {
    final params = <String>[];
    final tieneDesdeManual = _diaDesdeCtrl.text.isNotEmpty ||
        _mesDesdeCtrl.text.isNotEmpty || _anioDesdeCtrl.text.isNotEmpty;
    final tieneHastaManual = _diaHastaCtrl.text.isNotEmpty ||
        _mesHastaCtrl.text.isNotEmpty || _anioHastaCtrl.text.isNotEmpty;
    String? desde, hasta;
    if (tieneDesdeManual || tieneHastaManual) {
      desde = _fechaDesdeManual();
      hasta = _fechaHastaManual();
    } else if (_rango != null) {
      desde = _fmt(_rango!.start);
      hasta = _fmt(_rango!.end);
    } else {
      final hoy = DateTime.now();
      if (_periodo == 'año') {
        desde = '${hoy.year}-01-01';
        hasta = '${hoy.year}-12-31';
      } else if (_periodo == 'mes') {
        desde = _fmt(DateTime(hoy.year, hoy.month, 1));
        hasta = _fmt(DateTime(hoy.year, hoy.month + 1, 0));
      } else {
        final lunes = hoy.subtract(Duration(days: hoy.weekday - 1));
        desde = _fmt(lunes);
        hasta = _fmt(lunes.add(const Duration(days: 6)));
      }
    }
    if (desde != null && desde.isNotEmpty) params.add('desde=$desde');
    if (hasta != null && hasta.isNotEmpty) params.add('hasta=$hasta');
    final q = _qCtrl.text.trim();
    if (q.isNotEmpty) params.add('q=${Uri.encodeQueryComponent(q)}');
    final mMin = _montoMinCtrl.text.trim();
    final mMax = _montoMaxCtrl.text.trim();
    if (mMin.isNotEmpty) params.add('montoMin=${Uri.encodeQueryComponent(mMin)}');
    if (mMax.isNotEmpty) params.add('montoMax=${Uri.encodeQueryComponent(mMax)}');
    final url = '/comprobantes?limit=500&${params.join('&')}';
    return ApiClient.getList(url);
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fechaDesdeManual() {
    final d = _diaDesdeCtrl.text.trim().padLeft(2, '0');
    final m = _mesDesdeCtrl.text.trim().padLeft(2, '0');
    final a = _anioDesdeCtrl.text.trim();
    return '${a.isNotEmpty ? a : '2024'}-${m.isNotEmpty ? m : '01'}-${d.isNotEmpty ? d : '01'}';
  }

  String _fechaHastaManual() {
    final d = _diaHastaCtrl.text.trim().padLeft(2, '0');
    final m = _mesHastaCtrl.text.trim().padLeft(2, '0');
    final a = _anioHastaCtrl.text.trim();
    return '${a.isNotEmpty ? a : '2099'}-${m.isNotEmpty ? m : '12'}-${d.isNotEmpty ? d : '31'}';
  }

  void _buscar() => setState(() => _future = _buildFuture());

  Future<void> _elegirRango() async {
    final hoy = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: hoy,
      initialDateRange: _rango ??
          DateTimeRange(start: DateTime(hoy.year, hoy.month - 1, 1), end: hoy),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _rango = picked;
      _future = _buildFuture();
    });
  }

  bool get _hayBusqueda =>
      _qCtrl.text.trim().isNotEmpty ||
      _diaDesdeCtrl.text.trim().isNotEmpty ||
      _mesDesdeCtrl.text.trim().isNotEmpty ||
      _anioDesdeCtrl.text.trim().isNotEmpty ||
      _diaHastaCtrl.text.trim().isNotEmpty ||
      _mesHastaCtrl.text.trim().isNotEmpty ||
      _anioHastaCtrl.text.trim().isNotEmpty ||
      _montoMinCtrl.text.trim().isNotEmpty ||
      _montoMaxCtrl.text.trim().isNotEmpty;

  void _limpiarBusqueda() {
    for (final c in [_qCtrl, _diaDesdeCtrl, _mesDesdeCtrl, _anioDesdeCtrl,
      _diaHastaCtrl, _mesHastaCtrl, _anioHastaCtrl, _montoMinCtrl, _montoMaxCtrl]) {
      c.clear();
    }
    setState(() => _future = _buildFuture());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error de conexión con el backend.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        final data = snapshot.data ?? {};
        final total = data['total'] ?? 0;
        final raw = data['data'] as List? ?? [];
        final items = raw.map((e) => Map<String, dynamic>.from(e)).toList();
        final suma = items.fold<double>(0, (s, c) =>
            s + ((c['total_con_impuestos'] is num)
                ? (c['total_con_impuestos'] as num).toDouble()
                : double.tryParse('${c['total_con_impuestos']}') ?? 0));
        return Column(
          children: [
            _barraFiltros(cs),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(children: [
                const Icon(Icons.receipt_long, size: 18),
                const SizedBox(width: 8),
                Text(
                  _hayBusqueda
                      ? '${items.length} resultados de $total comprobantes'
                      : '$total comprobantes de pago',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(money(suma),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('No hay comprobantes en este periodo.'))
                  : Scrollbar(
                      child: LayoutBuilder(builder: (ctx, c) {
                        if (c.maxWidth >= 700) {
                          return _tablaComprobantes(cs, items);
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(4),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final co = items[i];
                            return ListTile(
                              title: Text(co['beneficiario_emisor'] ?? co['concepto'] ?? '-'),
                              subtitle: Text('${co['fecha'] ?? '-'} · ${co['metodo_pago'] ?? '-'}'),
                              trailing: Text(money(co['total_con_impuestos']),
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              onTap: () => _openCompDetail(context, co),
                            );
                          },
                        );
                      }),
                    ),
            ),
          ],
        );
      },
    );
  }

  /// Tabla de comprobantes para PC: Fecha · Beneficiario · Referencia · Método · Monto.
  Widget _tablaComprobantes(ColorScheme cs, List<Map<String, dynamic>> items) {
    Widget celda(String t, {int flex = 1, bool right = false, bool bold = false}) =>
        Expanded(
          flex: flex,
          child: Text(t,
              textAlign: right ? TextAlign.right : TextAlign.left,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
        );
    return Column(children: [
      Container(
        color: cs.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          celda('Fecha', flex: 10, bold: true),
          celda('Beneficiario', flex: 22, bold: true),
          celda('Referencia', flex: 14, bold: true),
          celda('Método', flex: 12, bold: true),
          celda('Monto', flex: 12, right: true, bold: true),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant),
          itemBuilder: (context, i) {
            final co = items[i];
            return InkWell(
              onTap: () => _openCompDetail(context, co),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(children: [
                  celda('${co['fecha'] ?? '—'}', flex: 10),
                  celda('${co['beneficiario_emisor'] ?? co['concepto'] ?? '—'}', flex: 22),
                  celda('${co['referencia'] ?? '—'}', flex: 14),
                  celda('${co['metodo_pago'] ?? '—'}', flex: 12),
                  celda(money(co['total_con_impuestos']), flex: 12, right: true, bold: true),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ── Barra de filtros (igual a la de Facturas para consistencia) ──
  Widget _barraFiltros(ColorScheme cs) {
    final inputDeco = InputDecoration(
      isDense: true, filled: true, fillColor: cs.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
    Widget chipsPeriodo() => Wrap(
      spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final p in ['año', 'mes', 'semana'])
          ChoiceChip(
            label: Text(p),
            selected: _rango == null && _periodo == p,
            shape: const StadiumBorder(),
            onSelected: (_) {
              setState(() { _periodo = p; _rango = null; _future = _buildFuture(); });
            },
          ),
        IconButton(icon: const Icon(Icons.calendar_month),
            tooltip: 'Elegir período (rango)', onPressed: _elegirRango),
      ],
    );
    Widget campoTexto({double? width}) => SizedBox(
      width: width,
      child: TextField(
        controller: _qCtrl,
        decoration: inputDeco.copyWith(
          hintText: 'Beneficiario, referencia o concepto…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _qCtrl.text.isEmpty
              ? null
              : IconButton(icon: const Icon(Icons.clear, size: 18),
                  onPressed: () { _qCtrl.clear(); setState(() {}); }),
        ),
        onSubmitted: (_) => _buscar(),
      ),
    );
    Widget botonFiltros() => FilledButton.tonalIcon(
      onPressed: () => setState(() => _filtrosAvanzados = !_filtrosAvanzados),
      style: FilledButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(10)),
      icon: Icon(_filtrosAvanzados ? Icons.expand_less : Icons.tune, size: 22),
      label: const Text(''),
    );
    Widget panelAvanzado() => AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: _filtrosAvanzados
          ? Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.calendar_month, size: 18),
                      const SizedBox(width: 6),
                      Text('Rango de fechas',
                          style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.clear_all, size: 18),
                        tooltip: 'Vaciar fechas',
                        onPressed: () {
                          for (final c in [_diaDesdeCtrl, _mesDesdeCtrl,
                            _anioDesdeCtrl, _diaHastaCtrl, _mesHastaCtrl, _anioHastaCtrl]) {
                            c.clear();
                          }
                          setState(() {});
                        },
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _campoFecha1(inputDeco, cs, 'Desde',
                            _diaDesdeCtrl, _mesDesdeCtrl, _anioDesdeCtrl),
                        _campoFecha1(inputDeco, cs, 'Hasta',
                            _diaHastaCtrl, _mesHastaCtrl, _anioHastaCtrl),
                        SizedBox(width: 110, child: TextField(
                          controller: _montoMinCtrl,
                          decoration: inputDeco.copyWith(hintText: 'Monto mín'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        )),
                        SizedBox(width: 110, child: TextField(
                          controller: _montoMaxCtrl,
                          decoration: inputDeco.copyWith(hintText: 'Monto máx'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        )),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (_hayBusqueda)
                        TextButton.icon(
                          onPressed: _limpiarBusqueda,
                          icon: const Icon(Icons.filter_alt_off, size: 18),
                          label: const Text('Limpiar')),
                      FilledButton.icon(
                        onPressed: _buscar,
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Buscar')),
                    ]),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (ctx, c) {
            final esMovil = c.maxWidth < 700;
            if (esMovil) {
              return Column(children: [
                Center(child: chipsPeriodo()),
                const SizedBox(height: 8),
                Row(children: [
                  Flexible(child: campoTexto()),
                  const SizedBox(width: 4),
                  botonFiltros(),
                ]),
              ]);
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                chipsPeriodo(),
                const SizedBox(width: 10),
                campoTexto(width: 300),
                const SizedBox(width: 4),
                botonFiltros(),
              ],
            );
          }),
          panelAvanzado(),
        ],
      ),
    );
  }

  /// Tres recuadros DD / MM / AAAA con una etiqueta (Desde/Hasta).
  Widget _campoFecha1(InputDecoration inputDeco, ColorScheme cs, String label,
      TextEditingController dia, TextEditingController mes,
      TextEditingController anio) {
    final deco = (String hint) => inputDeco.copyWith(hintText: hint);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        const SizedBox(width: 6),
        _inputCorto(deco('DD'), dia, 2, mes),
        const SizedBox(width: 5),
        Text('/', style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(width: 5),
        _inputCorto(deco('MM'), mes, 2, anio),
        const SizedBox(width: 5),
        Text('/', style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(width: 5),
        _inputCorto(deco('AAAA'), anio, 4, null),
      ],
    );
  }

  /// Input numérico corto (DD/MM/AAAA) con salto automático al siguiente.
  Widget _inputCorto(InputDecoration deco, TextEditingController ctrl, int maxLen,
      TextEditingController? next) {
    return SizedBox(
      width: maxLen == 2 ? 44 : 60,
      child: TextField(
        controller: ctrl,
        decoration: deco,
        keyboardType: TextInputType.number,
        maxLength: maxLen,
        textAlign: TextAlign.center,
        buildCounter: (BuildContext context,
                {required int currentLength,
                required bool isFocused,
                required int? maxLength}) => null,
        style: const TextStyle(fontSize: 13.5),
        onChanged: (_) {
          setState(() {});
          if (next != null && ctrl.text.length == maxLen) {
            FocusScope.of(context).nextFocus();
          }
        },
        onSubmitted: (_) => _buscar(),
      ),
    );
  }
}
/// Widget reutilizable para mostrar la foto/escaneo del documento. Al tocarla
/// se abre ampliada (con zoom) si es imagen; si es PDF/otro, abre en pestaña
/// nueva. La URL es relativa (/archivos/...) y el nginx del frontend la sirve
/// desde el volumen compartido con el backend.
class _ImagenDoc extends StatelessWidget {
  final String archivo;
  const _ImagenDoc({required this.archivo});

  @override
  Widget build(BuildContext context) {
    // Ruta relativa al host actual (nginx sirve /archivos/). Se resuelve contra
    // el origen de la página, correcto también accediendo por tailscale.
    final url = _archivoUrl(archivo);
    final esImagen = RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false)
        .hasMatch(archivo);
    // Documento que no es imagen (PDF u otro): abrir DIRECTO en el visor del
    // navegador (como el botón "Abrir" nativo, sin pantalla intermedia ni iframe).
    if (!esImagen) {
      return OutlinedButton.icon(
        onPressed: () => web.window.open(url, '_blank'),
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Ver documento (PDF)'),
      );
    }
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No se pudo cargar la imagen.',
                      style: TextStyle(color: Colors.white)),
                )),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 400),
          child: Image.network(url, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
      ),
    );
  }
}

/// Detalle de comprobante con su foto y datos.
class _CompDetalle extends StatelessWidget {
  final Map<String, dynamic> c;
  const _CompDetalle({required this.c});

  @override
  Widget build(BuildContext context) {
    final rows = <String, String>{
      'Fecha': (c['fecha'] ?? '-') as String,
      'Beneficiario': (c['beneficiario_emisor'] ?? '-') as String,
      'Referencia': (c['referencia'] ?? '-') as String,
      'Concepto': (c['concepto'] ?? '-') as String,
      'Método de pago': (c['metodo_pago'] ?? '-') as String,
      'Estado': (c['estado'] ?? '-') as String,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Text('Comprobante #${c['id']}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (c['archivo'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ImagenDoc(archivo: c['archivo'] as String),
            ),
          for (final e in rows.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RichText(
                text: TextSpan(children: [
                  TextSpan(text: '${e.key}:  ',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: e.value),
                ]),
              ),
            ),
          const Divider(height: 24),
          Row(children: [
            const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(money(c['total_con_impuestos']),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }
}

/// Vista previa de un PDF en un iframe embebido (Opción A: visor nativo del
/// navegador). La URL es relativa al host actual (mismo origen), así que nginx
/// la sirve y el navegador renderiza el PDF dentro del iframe.
class PdfViewer extends StatelessWidget {
  final String url;
  const PdfViewer({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (Object element) {
        final iframe = element as web.HTMLIFrameElement;
        iframe.src = url;
        iframe.style.border = 'none';
        iframe.style.width = '100%';
        iframe.style.height = '100%';
      },
    );
  }
}

/// Convierte una ruta de archivo (factura/comprobante) en URL absoluta que
/// nginx sirve desde /archivos/. Incluye el token JWT actual en la query para
/// que auth_request lo valide: sin ?token= nginx responde 401/403.
String _archivoUrl(String archivo) {
  final base = Uri.base.resolve('/archivos/$archivo').toString();
  final token = ApiClient.token;
  if (token == null || token.isEmpty) return base;
  return '$base?token=${Uri.encodeComponent(token)}';
}