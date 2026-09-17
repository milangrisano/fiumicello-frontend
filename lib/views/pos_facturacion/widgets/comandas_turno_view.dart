import 'package:flutter/material.dart';
import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Lista las comandas (ventas cobradas) de un turno de caja concreto.
/// Se llega desde las cards del POS; el turno se elige en el selector del POS.
class ComandasTurnoView extends StatefulWidget {
  final int idTurno;
  final Map<String, dynamic>? turno;
  const ComandasTurnoView({super.key, required this.idTurno, this.turno});

  @override
  State<ComandasTurnoView> createState() => _ComandasTurnoViewState();
}

class _ComandasTurnoViewState extends State<ComandasTurnoView> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _ventas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    final r = await ApiClient.obtenerVentasTurno(widget.idTurno);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _ventas = r.list.cast<Map<String, dynamic>>();
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
        title: const Text('Comandas del turno'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargar,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error', style: TextStyle(color: cs.error)))
              : _ventas.isEmpty
                  ? const Center(child: Text('No hay comandas en este turno.', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _ventas.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final v = _ventas[i];
                        final items = (v['items'] as List? ?? []).cast<Map<String, dynamic>>();
                        final esc = v['escenario'] ?? '';
                        final mesa = v['numero_mesa'];
                        final subtitulo = [
                          if (mesa != null) 'Mesa $mesa',
                          if (esc.isNotEmpty && esc != 'mesa') esc,
                          if (v['forma_pago_nombre'] != null) '${v['forma_pago_nombre']}',
                        ].where((e) => e.isNotEmpty).join(' · ');
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: cs.primaryContainer,
                            foregroundColor: cs.onPrimaryContainer,
                            child: Text('${i + 1}'),
                          ),
                          title: Text('Factura #${v['numero_factura'] ?? v['id']}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(subtitulo, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                          trailing: Text(money(_num(v['total'])),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          onTap: () => _verDetalle(v, items),
                        );
                      },
                    ),
    );
  }

  void _verDetalle(Map<String, dynamic> v, List<Map<String, dynamic>> items) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Factura #${v['numero_factura'] ?? v['id']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('Total: ${money(_num(v['total']))}'),
              Text('Forma de pago: ${v['forma_pago_nombre'] ?? '—'}'),
              const SizedBox(height: 8),
              const Text('Ítems:', style: TextStyle(fontWeight: FontWeight.w600)),
              ...items.map((it) => Text(
                  '${it['cantidad']} × ${it['nombre']}${it['tamanio'] != null ? ' (${it['tamanio']})' : ''} — ${money(_num(it['subtotal']))}')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
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