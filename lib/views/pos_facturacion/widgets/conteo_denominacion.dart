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

  List<Widget> _filas(String tipo) {
    return [
      for (final d in _DENOMINACIONES.where((x) => x['tipo'] == tipo))
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(money(d['valor'] as int), style: const TextStyle(fontSize: 14))),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _denominacionCtrl.putIfAbsent(d['valor'] as int, () => TextEditingController()),
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                onChanged: (_) {
                  setState(() {});
                  _notificar();
                },
                decoration: const InputDecoration(labelText: 'Cantidad', isDense: true, border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Billetes', style: TextStyle(fontWeight: FontWeight.w600)),
        ..._filas('Billete'),
        const SizedBox(height: 12),
        const Text('Monedas', style: TextStyle(fontWeight: FontWeight.w600)),
        ..._filas('Moneda'),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total efectivo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(money(_total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
