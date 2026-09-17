import 'package:flutter/material.dart';
import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Lista los ítems vendidos (línea por línea) de todas las comandas del turno.
/// Cada venta aporta sus ítems; se muestran en orden, sin agrupar.
class ItemsTurnoView extends StatefulWidget {
  final int idTurno;
  final Map<String, dynamic>? turno;
  const ItemsTurnoView({super.key, required this.idTurno, this.turno});

  @override
  State<ItemsTurnoView> createState() => _ItemsTurnoViewState();
}

class _ItemsTurnoViewState extends State<ItemsTurnoView> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  int _totalCantidad = 0;
  double _totalMonto = 0.0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    final r = await ApiClient.obtenerVentasTurno(widget.idTurno);
    if (!mounted) return;
    final filas = <Map<String, dynamic>>[];
    int cant = 0;
    double monto = 0.0;
    if (r.ok) {
      for (final v in r.list) {
        final items = (v['items'] as List? ?? []).cast<Map<String, dynamic>>();
        for (final it in items) {
          filas.add({...it, 'factura': v['numero_factura'] ?? v['id']});
          cant += (_num(it['cantidad'])).toInt();
          monto += _num(it['subtotal']);
        }
      }
    }
    setState(() {
      _loading = false;
      if (r.ok) {
        _items = filas;
        _totalCantidad = cant;
        _totalMonto = monto;
        _error = null;
      } else {
        _error = r.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Ítems vendidos del turno'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _cargar),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error', style: TextStyle(color: cs.error)))
              : _items.isEmpty
                  ? const Center(child: Text('No hay ítems en este turno.', style: TextStyle(color: Colors.grey)))
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          color: cs.surfaceContainerHighest,
                          child: Row(
                            children: [
                              Text('Total ítems: $_totalCantidad',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text('Suma: ${money(_totalMonto)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final it = _items[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('${it['nombre']}${it['tamanio'] != null ? ' (${it['tamanio']})' : ''}',
                                    style: const TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: Text('Factura #${it['factura']} · ×${_num(it['cantidad']).toInt()}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                                trailing: Text(money(_num(it['subtotal'])), style: const TextStyle(fontWeight: FontWeight.bold)),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }
}