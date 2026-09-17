import 'package:flutter/material.dart';
import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Lista las comandas (ventas cobradas) de un turno de caja concreto.
/// Se llega desde las cards del POS; el turno se elige en el selector del POS.
///
/// Diseño: toda la información visible en línea (sin diálogos ocultos). Cada
/// comanda es una tarjeta con factura, mesa/escenario, forma de pago, hora y
/// total, y sus ítems listados debajo.
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

  String _hora(dynamic fecha) {
    if (fecha == null) return '';
    try {
      final d = DateTime.parse(fecha.toString());
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _fechaTurno(dynamic fecha) {
    if (fecha == null) return '';
    try {
      final d = DateTime.parse(fecha.toString());
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return fecha.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final turnoFecha = _fechaTurno(widget.turno?['fecha']);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Comandas del turno'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualizar', onPressed: _cargar),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error', style: TextStyle(color: cs.error)))
              : _ventas.isEmpty
                  ? const Center(child: Text('No hay comandas en este turno.', style: TextStyle(color: Colors.grey)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (turnoFecha.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Row(
                              children: [
                                Icon(Icons.history, size: 16, color: cs.onSurfaceVariant),
                                const SizedBox(width: 6),
                                Text('Turno #${widget.idTurno} · $turnoFecha',
                                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                                const Spacer(),
                                Text('${_ventas.length} comandas',
                                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                              ],
                            ),
                          ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _ventas.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final v = _ventas[i];
                              final items = (v['items'] as List? ?? []).cast<Map<String, dynamic>>();
                              final esc = (v['escenario'] ?? '').toString();
                              final mesa = v['numero_mesa'];
                              final subtitulo = [
                                if (mesa != null) 'Mesa $mesa',
                                if (esc.isNotEmpty && esc != 'mesa') esc,
                              ].where((e) => e.isNotEmpty).join(' · ');
                              return Card(
                                elevation: 0,
                                color: cs.surfaceContainerHighest,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Fila principal: factura + hora a la izquierda, total a la derecha.
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Factura #${v['numero_factura'] ?? v['id']}',
                                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                                if (subtitulo.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 2),
                                                    child: Text(subtitulo,
                                                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(money(_num(v['total'])),
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                              if (_hora(v['fecha']).isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text(_hora(v['fecha']),
                                                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      // Forma de pago.
                                      if (v['forma_pago_nombre'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: cs.primaryContainer,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text('${v['forma_pago_nombre']}',
                                              style: TextStyle(color: cs.onPrimaryContainer, fontSize: 12)),
                                        ),
                                      const SizedBox(height: 8),
                                      // Ítems (toda la info visible, sin tap).
                                      ...items.map((it) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 1),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '${it['cantidad']} × ${it['nombre']}${it['tamanio'] != null ? ' (${it['tamanio']})' : ''}',
                                                    style: const TextStyle(fontSize: 13),
                                                  ),
                                                ),
                                                Text(money(_num(it['subtotal'])),
                                                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                                              ],
                                            ),
                                          )),
                                    ],
                                  ),
                                ),
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