import 'package:flutter/material.dart';
import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Registro del pago/entrega de propinas a los trabajadores (por día).
class PagoPropinaView extends StatefulWidget {
  const PagoPropinaView({super.key});

  @override
  State<PagoPropinaView> createState() => _PagoPropinaViewState();
}

class _PagoPropinaViewState extends State<PagoPropinaView> {
  final _fecha = TextEditingController();
  final _montoEf = TextEditingController();
  final _montoOt = TextEditingController();
  final _notas = TextEditingController();
  final _desde = TextEditingController();
  final _hasta = TextEditingController();
  List<Map<String, dynamic>> _pagos = [];
  bool _loading = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fecha.text = DateTime.now().toIso8601String().split('T').first;
    _load();
  }

  Future<void> _load() async {
    final p = await ApiClient.cajaPagosPropina();
    if (!mounted) return;
    setState(() {
      _pagos = p.ok ? p.list.cast<Map<String, dynamic>>() : [];
      _loading = false;
      _error = p.ok ? null : p.message;
    });
  }

  double _num(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0.0);

  Future<void> _guardar() async {
    final me = _num(_montoEf.text.replaceAll(',', '.'));
    final mo = _num(_montoOt.text.replaceAll(',', '.'));
    if (me <= 0 && mo <= 0) { _snack('Ingrese al menos un monto de propina.'); return; }
    if (_fecha.text.trim().isEmpty) { _snack('Indique la fecha de pago.'); return; }
    setState(() => _guardando = true);
    final r = await ApiClient.cajaPagarPropina(
      _fecha.text.trim(),
      me,
      mo,
      int.tryParse(_desde.text),
      int.tryParse(_hasta.text),
      _notas.text.trim(),
    );
    if (!mounted) return;
    setState(() => _guardando = false);
    if (r.ok) {
      _snack('Pago de propina registrado.');
      _montoEf.clear(); _montoOt.clear(); _desde.clear(); _hasta.clear(); _notas.clear();
      await _load();
    } else {
      _snack(r.message);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    return Scaffold(
      appBar: AppBar(title: const Text('Pago de propinas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Registrar entrega a trabajadores', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _fecha,
              decoration: const InputDecoration(labelText: 'Fecha de pago', hintText: 'AAAA-MM-DD'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _montoEf, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Propina efectivo', prefixText: '\$'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _montoOt, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Propina otros medios', prefixText: '\$'))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _desde, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Turno desde (opcional)'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _hasta, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Turno hasta (opcional)'))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: _notas, decoration: const InputDecoration(labelText: 'Notas (opcional)')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Registrar pago'),
            ),
            const Divider(height: 32),
            const Text('Pagos registrados', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...(_pagos.map<Widget>((p) => ListTile(
                  title: Text('${p['fecha_pago']}'),
                  subtitle: Text('Efectivo: ${money(_num(p['monto_efectivo']))} · Otros: ${money(_num(p['monto_otros']))}'),
                  trailing: Text(p['notas']?.toString().isNotEmpty == true ? p['notas'].toString() : ''),
                ))),
          ],
        ),
      ),
    );
  }
}
