import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';

/// Conteo de denominaciones (billetes y monedas COP) para apertura/cierre de caja.
/// El usuario solo teclea la CANTIDAD de cada denominación; el total se calcula
/// solo y se notifica por `onTotalChanged`. Reutilizable: se usa tanto al abrir
/// como al cerrar la caja.
///
/// Cono monetario colombiano: el billete de $1.000 salió del cono, por lo que el
/// $1.000 es SOLO moneda.
class ConteoDenominacion extends StatefulWidget {
  final ValueChanged<double> onTotalChanged;
  const ConteoDenominacion({super.key, required this.onTotalChanged});

  @override
  State<ConteoDenominacion> createState() => _ConteoDenominacionState();
}

class _ConteoDenominacionState extends State<ConteoDenominacion> {
  static const _DENOMINACIONES = <Map<String, dynamic>>[
    {'valor': 100000, 'tipo': 'Billete'}, {'valor': 50000, 'tipo': 'Billete'},
    {'valor': 20000, 'tipo': 'Billete'},  {'valor': 10000, 'tipo': 'Billete'},
    {'valor': 5000, 'tipo': 'Billete'},   {'valor': 2000, 'tipo': 'Billete'},
    {'valor': 1000, 'tipo': 'Moneda'},
    {'valor': 500, 'tipo': 'Moneda'},    {'valor': 200, 'tipo': 'Moneda'},
    {'valor': 100, 'tipo': 'Moneda'},    {'valor': 50, 'tipo': 'Moneda'},
  ];
  final _denominacionCtrl = <int, TextEditingController>{};

  double get _total {
    double t = 0;
    for (final d in _DENOMINACIONES) {
      final c = _denominacionCtrl[d['valor'] as int];
      if (c == null) continue;
      t += (d['valor'] as int) * (double.tryParse(c.text.replaceAll(',', '.')) ?? 0);
    }
    return t;
  }

  void _notificar() => widget.onTotalChanged(_total);

  @override
  void initState() {
    super.initState();
    // Notificar el total inicial (0) al montar.
    WidgetsBinding.instance.addPostFrameCallback((_) => _notificar());
  }

  @override
  void dispose() {
    for (final c in _denominacionCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Sección (Billetes / Monedas) como una tarjeta con encabezado y filas.
  Widget _seccion(BuildContext context, String tipo, IconData icono, String titulo) {
    final entries = _DENOMINACIONES.where((x) => x['tipo'] == tipo).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Encabezado de sección con icono.
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icono, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(titulo, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0)
                  Divider(height: 2, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6)),
                _filaDenominacion(context, entries[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Fila de una denominación: valor a la izquierda + stepper (− cantidad +) a la derecha.
  Widget _filaDenominacion(BuildContext context, Map<String, dynamic> d) {
    final valor = d['valor'] as int;
    final scheme = Theme.of(context).colorScheme;
    final ctrl = _denominacionCtrl.putIfAbsent(valor, () => TextEditingController());

    int _valorActual() => int.tryParse(ctrl.text.replaceAll(',', '.').trim()) ?? 0;

    void _cambiar(int delta) {
      setState(() {
        final n = _valorActual() + delta;
        if (n < 0) return;
        ctrl.text = n == 0 ? '' : '$n';
      });
      _notificar();
    }

    // Botones con fondo de color para que resalten contra el fondo del campo.
    // Se renderizan con texto del símbolo en negrita para que el "−" se vea tan
    // claro como el "+" (el icono remo del guión era demasiado fino).
    Widget _boton(IconData icono) {
      final esSuma = icono == Icons.add;
      return InkWell(
        onTap: () => _cambiar(esSuma ? 1 : -1),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.all(4),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            esSuma ? '+' : '−',
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              money(valor),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
            ),
          ),
          // Stepper: botón −, campo de cantidad, botón +.
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _boton(Icons.remove),
                SizedBox(
                  width: 44,
                  child: TextField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15),
                    onChanged: (_) {
                      setState(() {});
                      _notificar();
                    },
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: '0',
                      hintStyle: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                _boton(Icons.add),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _seccion(context, 'Billete', Icons.payments_outlined, 'Billetes'),
        const SizedBox(height: 16),
        _seccion(context, 'Moneda', Icons.monetization_on_outlined, 'Monedas'),
        const SizedBox(height: 16),
        // Total destacado en una barra con el acento de la app.
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.primary.withValues(alpha: 0.82)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onPrimary)),
              Text(money(_total), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: scheme.onPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}
