import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../core/data/api_client.dart';
import '../../core/utils/formatters.dart';

/// Module 1 — Invoices and payment vouchers.
///
/// Contains two tabs: purchase invoices ("Facturas de compra") and payment
/// vouchers ("Comprobantes de pago"). Loading/error states are handled.
class InvoicesView extends StatelessWidget {
  const InvoicesView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(tabs: [
            Tab(text: 'Facturas de compra'),
            Tab(text: 'Comprobantes de pago'),
          ]),
          const Expanded(
            child: TabBarView(children: [
              FacturasList(),
              ComprobantesList(),
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

  @override
  void initState() {
    super.initState();
    _future = ApiClient.getList('/facturas?limit=100');
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
        final data = snapshot.data!;
        final total = data['total'] ?? 0;
        final raw = data['data'] as List? ?? [];
        final items = raw.map((e) => Map<String, dynamic>.from(e)).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                const Icon(Icons.store),
                const SizedBox(width: 8),
                Text('$total facturas de compra',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final f = items[i];
                  final id = f['id'];
                  return ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(f['proveedor'] ?? 'Sin proveedor'),
                    subtitle: Text('${f['fecha'] ?? '-'} · ${f['numero_factura'] ?? '-'}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(money(f['total_con_impuestos']),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (ApiClient.isSuperadmin || ApiClient.isAdmin) ...[
                        if (f['archivo'] != null)
                          IconButton(
                            icon: const Icon(Icons.photo, color: Color(0xFF2FB9A6)),
                            tooltip: 'Ver imagen de la factura',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _verImagen(context, f['archivo'] as String),
                          ),
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, color: Color(0xFF2FB9A6)),
                          tooltip: 'Ver detalle extraído',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _openDetail(context, id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Borrar factura',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _borrar(context, f['id'], f['proveedor']),
                        ),
                      ],
                    ]),
                    onTap: () => _openDetail(context, id),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openDetail(BuildContext context, dynamic id) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => FacturaDetail(id: id),
    );
  }

  /// Muestra la imagen/escaneo del documento a pantalla completa (con zoom).
  void _verImagen(BuildContext context, String archivo) {
    final url = Uri.base.resolve('/archivos/$archivo').toString();
    final esImagen = RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false)
        .hasMatch(archivo);
    if (!esImagen) {
      // PDF u otro documento: abrir en pestaña nueva para ver/descargar.
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
    if (r.ok) setState(() => _future = ApiClient.getList('/facturas?limit=100'));
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, scrollController) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data ?? {};
            final factura = Map<String, dynamic>.from(data['factura'] ?? {});
            final items2 = data['items'] as List? ?? [];
            final items = items2.map((e) => Map<String, dynamic>.from(e)).toList();
            return ListView(
              controller: scrollController,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Factura #${factura['numero_factura']}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      // Foto / escaneo del documento si está guardado.
                      if (factura['archivo'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ImagenDoc(
                            archivo: factura['archivo'] as String,
                          ),
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
        );
      },
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
              leading: const Icon(Icons.payment),
              title: Text(c['beneficiario_emisor'] ?? c['concepto'] ?? '-'),
              subtitle: Text('${c['fecha'] ?? '-'} · ${c['metodo_pago'] ?? '-'}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(money(c['total_con_impuestos']),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (ApiClient.isSuperadmin || ApiClient.isAdmin) ...[
                  if (c['archivo'] != null)
                    IconButton(
                      icon: const Icon(Icons.photo, color: Color(0xFF2FB9A6)),
                      tooltip: 'Ver imagen del comprobante',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _verImagen(context, c['archivo'] as String),
                    ),
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, color: Color(0xFF2FB9A6)),
                    tooltip: 'Ver detalle extraído',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openCompDetail(context, c),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Borrar comprobante',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _borrar(context, c['id'], c['beneficiario_emisor'] ?? c['concepto']),
                  ),
                ],
              ]),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CompDetalle(c: c),
    );
  }

  /// Muestra la imagen/escaneo del documento a pantalla completa (con zoom).
  void _verImagen(BuildContext context, String archivo) {
    final url = Uri.base.resolve('/archivos/$archivo').toString();
    final esImagen = RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false)
        .hasMatch(archivo);
    if (!esImagen) {
      // PDF u otro documento: abrir en pestaña nueva para ver/descargar.
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
    // Documento que no es imagen (PDF u otro): botón para abrir en pestaña nueva.
    if (!esImagen) {
      return OutlinedButton.icon(
        onPressed: () => web.window.open(url, '_blank'),
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Abrir documento (PDF)'),
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
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