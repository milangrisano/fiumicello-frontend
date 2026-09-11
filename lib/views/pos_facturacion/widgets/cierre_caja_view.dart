import 'package:flutter/material.dart';
import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';

/// Pantalla de cierre de turno: arqueo de caja y cierre (bloqueado si faltante).
class CierreCajaView extends StatefulWidget {
  final Map<String, dynamic> turno;
  const CierreCajaView({super.key, required this.turno});

  @override
  State<CierreCajaView> createState() => _CierreCajaViewState();
}

class _CierreCajaViewState extends State<CierreCajaView> {
  Map<String, dynamic>? _arqueo;
  bool _loading = true;
  bool _cerrando = false;
  String? _error;

  final _efectivoFinal = TextEditingController();
  final _propinaEfectivo = TextEditingController();
  final _propinaOtros = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ApiClient.cajaArqueo(widget.turno['id'] as int);
    if (!mounted) return;
    setState(() {
      _arqueo = r.ok ? r.data : null;
      _loading = false;
      _error = r.ok ? null : r.message;
      if (r.ok && r.data != null) {
        _efectivoFinal.text = _num(r.data!['efectivo_teorico']).toStringAsFixed(0);
      }
    });
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : (double.tryParse('$v') ?? 0.0);

  Future<void> _cerrar() async {
    final teorico = _num(_arqueo!['efectivo_teorico']);
    final fisico = double.tryParse(_efectivoFinal.text.replaceAll(',', '.')) ?? 0;
    final faltante = teorico - fisico;
    if (faltante > 0) {
      _snack('No se puede cerrar: faltante de \$${faltante.toStringAsFixed(0)}. Cuadre la caja.');
      return;
    }
    setState(() => _cerrando = true);
    final r = await ApiClient.cajaCerrar(
      widget.turno['id'] as int,
      fisico,
      double.tryParse(_propinaEfectivo.text.replaceAll(',', '.')) ?? 0,
      double.tryParse(_propinaOtros.text.replaceAll(',', '.')) ?? 0,
    );
    if (!mounted) return;
    setState(() => _cerrando = false);
    if (r.ok) {
      _snack('Turno cerrado correctamente.');
      if (mounted) Navigator.of(context).pop(true);
    } else {
      _snack(r.message);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    final a = _arqueo!;
    final faltante = _num(a['faltante']);
    final puedeCerrar = a['puedeCerrar'] == true;
    return Scaffold(
      appBar: AppBar(title: Text('Cierre de caja — Turno ${widget.turno['numero_dia'] ?? ''}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ventas por medio de pago', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...((a['porMedio'] as List? ?? []).map<Widget>((m) => ListTile(
                  title: Text('${m['medio']}'),
                  trailing: Text(money(_num(m['total']))),
                ))),
            const Divider(),
            _fila('Efectivo inicial', money(_num(a['efectivoInicial']))),
            _fila('Ventas en efectivo', money(_num(a['ventasEfectivo']))),
            _fila('Propina en efectivo (sale)', '- ${money(_num(a['propinaEfectivo']))}'),
            _fila('Egresos', '- ${money(_num(a['egresos']))}'),
            _fila('Ingresos', '+ ${money(_num(a['ingresos']))}'),
            const Divider(),
            _fila('Efectivo teórico esperado', money(_num(a['efectivoTeorico'])), bold: true),
            const SizedBox(height: 12),
            TextField(
              controller: _efectivoFinal,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Efectivo contado físicamente', prefixText: '\$'),
            ),
            if (faltante > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('⚠ Faltante: ${money(faltante)} — no se puede cerrar.',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              )
            else if (_num(a['excedente']) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Excedente (propina/sobrante): ${money(_num(a['excedente']))}',
                    style: const TextStyle(color: Colors.green)),
              ),
            const SizedBox(height: 16),
            const Text('Propina a repartir', style: TextStyle(fontWeight: FontWeight.w600)),
            Row(children: [
              Expanded(child: TextField(controller: _propinaEfectivo, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Propina efectivo', prefixText: '\$'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _propinaOtros, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Propina otros medios', prefixText: '\$'))),
            ]),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: (_cerrando || !puedeCerrar) ? null : _cerrar,
              child: _cerrando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Cerrar turno'),
            ),
            if (!puedeCerrar)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('El cierre está bloqueado hasta cuadrar el efectivo.', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fila(String label, String valor, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
          Text(valor, style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
        ]),
      );
}
