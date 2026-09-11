import 'package:flutter/material.dart';
import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Registro de movimientos de caja durante un turno:
/// - Egreso: compra en efectivo (libre, lo registra el cajero).
/// - Ingreso: devolución u otro (requiere autorizador admin/encargado).
class MovimientosCajaView extends StatefulWidget {
  final Map<String, dynamic> turno;
  const MovimientosCajaView({super.key, required this.turno});

  @override
  State<MovimientosCajaView> createState() => _MovimientosCajaViewState();
}

class _MovimientosCajaViewState extends State<MovimientosCajaView> {
  List<Map<String, dynamic>> _movimientos = [];
  List<Map<String, dynamic>> _autorizadores = [];
  bool _loading = true;
  String? _error;
  String _tipo = 'egreso';
  final _concepto = TextEditingController();
  final _monto = TextEditingController();
  int? _autorizadoPor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await ApiClient.listarUsuarios();
    final m = await ApiClient.cajaMovimientos(widget.turno['id'] as int);
    if (!mounted) return;
    setState(() {
      _autorizadores = (u.ok ? (u.list) : [])
          .where((x) => ['admin', 'encargado', 'superadmin'].contains('${x['rol']}'))
          .cast<Map<String, dynamic>>()
          .toList();
      _movimientos = m.ok ? (m.list).cast<Map<String, dynamic>>() : [];
      _loading = false;
      _error = (u.ok && m.ok) ? null : (u.message.isNotEmpty ? u.message : m.message);
    });
  }

  double _num(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0.0);

  Future<void> _guardar() async {
    final monto = _num(_monto.text.replaceAll(',', '.'));
    if (monto <= 0) { _snack('Ingrese un monto válido.'); return; }
    if (_concepto.text.trim().isEmpty) { _snack('Describa el concepto.'); return; }
    if (_tipo == 'ingreso' && _autorizadoPor == null) {
      _snack('Seleccione quién autoriza el ingreso.');
      return;
    }
    PostResult r;
    if (_tipo == 'egreso') {
      r = await ApiClient.cajaEgreso(widget.turno['id'] as int, _concepto.text.trim(), monto);
    } else {
      r = await ApiClient.cajaIngreso(widget.turno['id'] as int, _concepto.text.trim(), monto, _autorizadoPor!);
    }
    if (!mounted) return;
    if (r.ok) {
      _snack('Movimiento registrado.');
      _concepto.clear();
      _monto.clear();
      setState(() => _autorizadoPor = null);
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
      appBar: AppBar(title: Text('Movimientos — Turno ${widget.turno['numero_dia']}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Registrar movimiento', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'egreso', label: Text('Egreso (compra)')),
                ButtonSegment(value: 'ingreso', label: Text('Ingreso (devolución)')),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _concepto,
              decoration: const InputDecoration(labelText: 'Concepto', hintText: 'Ej. Compra de insumos'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _monto,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto', prefixText: '\$'),
            ),
            const SizedBox(height: 8),
            if (_tipo == 'ingreso')
              DropdownButtonFormField<int>(
                value: _autorizadoPor,
                items: _autorizadores
                    .map<DropdownMenuItem<int>>((a) => DropdownMenuItem(
                          value: a['id'] as int,
                          child: Text('${a['nombre_servicio'] ?? a['email']} (${a['rol']})'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _autorizadoPor = v),
                decoration: const InputDecoration(labelText: 'Autorizado por'),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _guardar, child: const Text('Registrar movimiento')),
            const Divider(height: 32),
            const Text('Movimientos del turno', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...(_movimientos.map<Widget>((m) => ListTile(
                  leading: Icon(m['tipo'] == 'egreso' ? Icons.arrow_upward : Icons.arrow_downward,
                      color: m['tipo'] == 'egreso' ? Colors.red : Colors.green),
                  title: Text('${m['concepto']}'),
                  subtitle: m['tipo'] == 'ingreso'
                      ? Text('Autorizado por: ${m['autorizado_por'] ?? '—'}')
                      : null,
                  trailing: Text((m['tipo'] == 'egreso' ? '- ' : '+ ') + money(_num(m['monto'])),
                      style: TextStyle(
                          color: m['tipo'] == 'egreso' ? Colors.red : Colors.green,
                          fontWeight: FontWeight.w600)),
                ))),
          ],
        ),
      ),
    );
  }
}
