import 'package:flutter/material.dart';
import '../core/data/api_client.dart';
import '../core/utils/formatters.dart';

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
                    trailing: Text(money(f['total_con_impuestos']),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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
              trailing: Text(money(c['total_con_impuestos']),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            );
          },
        );
      },
    );
  }
}