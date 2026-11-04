import 'package:flutter/material.dart';
import '../../../core/data/api_client.dart';
import '../../../core/utils/formatters.dart';
import 'conteo_denominacion.dart';

/// Ventana emergente (dialog) de cierre de turno: arqueo de caja y cierre
/// (bloqueado si faltante). Sin Scaffold propio: se muestra dentro de un
/// [Dialog], que le da el marco y el botón de cerrar (X).
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

  // Efectivo contado físicamente, calculado por el widget de denominaciones.
  double _efectivoContado = 0;

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
    });
  }

  double _num(dynamic v) =>
      v is num ? v.toDouble() : (double.tryParse('$v') ?? 0.0);

  Future<void> _cerrar() async {
    final teorico = _num(_arqueo!['efectivo_teorico']);
    final fisico = _efectivoContado;
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
    if (_loading) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    if (_error != null) return Padding(padding: const EdgeInsets.all(24), child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    final a = _arqueo!;
    final teorico = _num(a['efectivoTeorico']);
    // Faltante/excedente recalculados en vivo según lo contado por el widget.
    final faltante = teorico - _efectivoContado;
    final excedente = _efectivoContado - teorico;
    final puedeCerrar = a['puedeCerrar'] == true && faltante <= 0;
    // Contenido de la ventana emergente (sin Scaffold/AppBar: el Dialog le da
    // el marco). Encabezado con título y botón de cerrar (X).
    return SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(child: Text('Cierre de caja — Turno ${widget.turno['numero_dia'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(false)),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            const Text('Ventas por medio de pago', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...((a['porMedio'] as List? ?? []).map<Widget>((m) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${m['medio']}'),
                  trailing: Text(money(_num(m['total']))),
                ))),
            const Divider(),
            _fila('Efectivo inicial', money(_num(a['efectivoInicial']))),
            _fila('Ventas en efectivo', money(_num(a['ventasEfectivo']))),
            _fila('Propina en efectivo (sale)', '- ${money(_num(a['propinaEfectivo']))}'),
            _fila('Egresos', '- ${money(_num(a['egresos']))}'),
            _fila('Ingresos', '+ ${money(_num(a['ingresos']))}'),
            const SizedBox(height: 4),
            // Registro de retiro/ingreso de caja desde la propia ventana de cierre.
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await _dialogMovimiento();
                if (ok == true) await _load(); // recargar arqueo: actualiza egresos/ingresos
              },
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Registrar retiro / ingreso de caja'),
            ),
            const Divider(),
            _fila('Efectivo teórico esperado', money(_num(a['efectivoTeorico'])), bold: true),
            const SizedBox(height: 12),
            const Text('Cuente el efectivo contado físicamente por denominación.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            ConteoDenominacion(
              onTotalChanged: (t) => setState(() => _efectivoContado = t),
            ),
            if (faltante > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('⚠ Faltante: ${money(faltante)} — no se puede cerrar.',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              )
            else if (excedente > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Excedente (propina/sobrante): ${money(excedente)}',
                    style: const TextStyle(color: Colors.green)),
              ),
            const SizedBox(height: 16),
            const Text('Propina a repartir', style: TextStyle(fontWeight: FontWeight.w600)),
            Row(children: [
              Expanded(child: TextField(controller: _propinaEfectivo, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Propina efectivo', prefixText: '\$'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _propinaOtros, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Propina otros medios', prefixText: '\$'))),
            ]),
            const SizedBox(height: 16),
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
            ),
          ),
        ],
      ),
    );
  }

  /// Diálogo para registrar un movimiento de caja (retiro/egreso o ingreso)
  /// desde la ventana de cierre. El egreso no exige autorización; el ingreso
  /// exige seleccionar un autorizador (admin/encargado), como en movimientos.
  Future<bool?> _dialogMovimiento() async {
    String tipo = 'egreso';
    final concepto = TextEditingController();
    final monto = TextEditingController();
    List<Map<String, dynamic>> autorizadores = [];
    int? autorizadoPor;
    final cargarAutorizadores = await ApiClient.listarUsuarios();
    if (cargarAutorizadores.ok) {
      autorizadores = cargarAutorizadores.list
          .cast<Map<String, dynamic>>()
          .where((x) => ['admin', 'encargado', 'superadmin'].contains('${x['rol']}'))
          .toList();
    }
    final guardar = StatefulBuilder(
      builder: (ctx, setDlg) {
        return AlertDialog(
          title: const Text('Registrar movimiento de caja'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'egreso', label: Text('Retiro (egreso)')),
                  ButtonSegment(value: 'ingreso', label: Text('Ingreso')),
                ],
                selected: {tipo},
                onSelectionChanged: (s) => setDlg(() => tipo = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: concepto,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Concepto', hintText: 'Ej. Retiro para insumos'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: monto,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto', prefixText: r'$'),
              ),
              if (tipo == 'ingreso') ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: autorizadoPor,
                  items: autorizadores
                      .map<DropdownMenuItem<int>>((a) => DropdownMenuItem(value: a['id'] as int, child: Text('${a['rol']} (${a['email']})')))
                      .toList(),
                  onChanged: (v) => setDlg(() => autorizadoPor = v),
                  decoration: const InputDecoration(labelText: 'Autorizado por'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final m = double.tryParse(monto.text.replaceAll(',', '.')) ?? 0;
                if (concepto.text.trim().isEmpty) { _snack('Describa el concepto.'); return; }
                if (m <= 0) { _snack('Ingrese un monto válido.'); return; }
                if (tipo == 'ingreso' && autorizadoPor == null) { _snack('Seleccione quién autoriza el ingreso.'); return; }
                Navigator.pop(ctx, true);
                final r = tipo == 'egreso'
                    ? await ApiClient.cajaEgreso(widget.turno['id'] as int, concepto.text.trim(), m)
                    : await ApiClient.cajaIngreso(widget.turno['id'] as int, concepto.text.trim(), m, autorizadoPor!);
                if (r.ok) {
                  _snack('Movimiento registrado.');
                } else {
                  _snack(r.message);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    return showDialog<bool?>(context: context, builder: (_) => guardar);
  }

  Widget _fila(String label, String valor, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
          Text(valor, style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
        ]),
      );
}
