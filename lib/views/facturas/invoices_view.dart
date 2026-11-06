import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../core/data/api_client.dart';
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

  // Filtro de período: 'año' | 'mes' | 'semana' (chips) o rango libre
  // (calendario). Si _rango != null, manda el rango y los chips se desmarcan.
  String _periodo = 'mes';
  DateTimeRange? _rango;

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _future = _buildFuture();
  }

  /// Construye la petición con el rango de fechas del período elegido.
  Future<Map<String, dynamic>> _buildFuture() {
    String? desde;
    String? hasta;
    if (_rango != null) {
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
        // semana: lunes a domingo de la semana actual.
        final lunes = hoy.subtract(Duration(days: hoy.weekday - 1));
        desde = _fmt(lunes);
        hasta = _fmt(lunes.add(const Duration(days: 6)));
      }
    }
    final url = '/facturas?limit=500&desde=$desde&hasta=$hasta';
    return ApiClient.getList(url);
  }

  /// Selector de rango propio (dos fechas: Desde / Hasta). Se usa en lugar de
  /// showDateRangePicker, que en web no responde bien a la selección.
  Future<void> _elegirRango() async {
    final hoy = DateTime.now();
    var ini = _rango?.start ?? DateTime(hoy.year, hoy.month, 1);
    var fin = _rango?.end ?? hoy;
    final aplicar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Elegir período'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Desde'),
                subtitle: Text(_fmt(ini)),
                trailing: const Icon(Icons.edit_calendar, size: 20),
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: ini,
                    firstDate: DateTime(2024, 1, 1),
                    lastDate: hoy,
                    helpText: 'Fecha inicial',
                  );
                  if (p != null) setDlg(() => ini = p);
                },
              ),
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Hasta'),
                subtitle: Text(_fmt(fin)),
                trailing: const Icon(Icons.edit_calendar, size: 20),
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: fin,
                    firstDate: DateTime(2024, 1, 1),
                    lastDate: hoy,
                    helpText: 'Fecha final',
                  );
                  if (p != null) setDlg(() => fin = p);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    if (aplicar != true || !mounted) return;
    if (fin.isBefore(ini)) {
      final t = ini;
      ini = fin;
      fin = t;
    }
    setState(() {
      _rango = DateTimeRange(start: ini, end: fin);
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

  Widget _chips(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Wrap(
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
      ),
    );
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
        final items = raw.map((e) => Map<String, dynamic>.from(e)).toList();
        double suma = 0;
        for (final f in items) {
          final v = f['total_con_impuestos'];
          if (v is num) suma += v.toDouble();
          else if (v is String) suma += double.tryParse(v) ?? 0;
        }
        return Column(
          children: [
            _chips(cs),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(children: [
                const Icon(Icons.store, size: 18),
                const SizedBox(width: 8),
                Text('$total facturas de compra',
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
    final url = Uri.base.resolve('/archivos/$archivo').toString();
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

  @override
  void initState() {
    super.initState();
    _future = ApiClient.getList('/comprobantes?limit=100');
  }

  @override
  Widget build(BuildContext context) {
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
        final raw = data['data'] as List? ?? [];
        final items = raw.map((e) => Map<String, dynamic>.from(e)).toList();
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final c = items[i];
            return ListTile(
              title: Text(c['beneficiario_emisor'] ?? c['concepto'] ?? '-'),
              subtitle: Text('${c['fecha'] ?? '-'} · ${c['metodo_pago'] ?? '-'}'),
              trailing: Text(money(c['total_con_impuestos']),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => _openCompDetail(context, c),
            );
          },
        );
      },
    );
  }

  Future<void> _borrar(BuildContext context, dynamic id, String? nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar comprobante'),
        content: Text('¿Seguro que quieres borrar el comprobante ${nombre ?? ''}?\nEsta acción es permanente y definitiva.'),
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
    final r = await ApiClient.borrarComprobante(id as int);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r.ok ? 'Comprobante borrado.' : 'Error: ${r.message}')),
    );
    if (r.ok) setState(() => _future = ApiClient.getList('/comprobantes?limit=100'));
  }

  void _openCompDetail(BuildContext context, Map<String, dynamic> c) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(child: _CompDetalle(c: c)),
        actions: [
          if (ApiClient.isSuperadmin || ApiClient.isAdmin)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _borrar(context, c['id'], c['beneficiario_emisor'] ?? c['concepto']);
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Borrar comprobante'),
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
    final url = Uri.base.resolve('/archivos/$archivo').toString();
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
    final url = Uri.base.resolve('/archivos/$archivo').toString();
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