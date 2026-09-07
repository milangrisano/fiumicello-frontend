import 'package:flutter/material.dart';
import '../core/data/api_client.dart';
import '../core/utils/formatters.dart';

/// POS invoicing screen.
/// The cashier picks products from the carta (menu), sets a scenario
/// (mesa / para llevar / domicilio), and cobra with a payment method.
class PosSalesView extends StatefulWidget {
  const PosSalesView({super.key});

  @override
  State<PosSalesView> createState() => _PosSalesViewState();
}

/// A line in the current order.
class _PedidoLine {
  final int idProducto;
  final String nombre;
  final String? tamanio;
  final double precio;
  int cantidad;

  _PedidoLine({
    required this.idProducto,
    required this.nombre,
    this.tamanio,
    required this.precio,
    this.cantidad = 1,
  });

  double get subtotal => precio * cantidad;
}

class _PosSalesViewState extends State<PosSalesView> {
  Map<String, dynamic>? _carta;
  List<Map<String, dynamic>> _formas = [];
  final List<_PedidoLine> _pedido = [];
  String _escenario = 'mesa';
  String _numeroMesa = '';
  String _clienteNombre = '';
  String _direccion = '';
  String _telefono = '';
  int? _formaPagoId;
  bool _loading = true;
  bool _cobrando = false;
  String? _error;
  String _busqueda = '';
  int? _categoriaSel; // selected category for the mobile chips

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Cargar catálogo (carta pública, siempre disponible) y formas de pago.
      final c = await ApiClient.obtenerCarta().timeout(const Duration(seconds: 15));
      final f = await ApiClient.listarFormasPago().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        if (c.ok && c.data != null) {
          _carta = c.data;
        } else {
          _error = c.message.isEmpty ? 'No se pudo cargar la carta.' : c.message;
        }
        if (f.ok) {
          _formas = f.list.cast<Map<String, dynamic>>();
        }
        if (_formaPagoId == null && _formas.isNotEmpty) {
          _formaPagoId = _formas.first['id'] as int?;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
      debugPrint('POS load error: $e');
    }
  }

  List<Map<String, dynamic>> get _categorias =>
      (_carta?['categorias'] as List? ?? []).cast<Map<String, dynamic>>();

  void _agregar(Map<String, dynamic> item, String? tamanio) {
    final nombre = item['nombre'] ?? '';
    final precio = _precioDe(item, tamanio);
    setState(() {
      for (final l in _pedido) {
        if (l.idProducto == (item['id'] as int?) && l.tamanio == tamanio) {
          l.cantidad++;
          return;
        }
      }
      _pedido.add(_PedidoLine(
        idProducto: item['id'] as int,
        nombre: nombre,
        tamanio: tamanio,
        precio: precio,
      ));
    });
  }

  double _precioDe(Map<String, dynamic> item, String? tamanio) {
    final t = tamanio?.toLowerCase() ?? '';
    if (t == 'personal') return _num(item['precio_personal']);
    if (t == 'mediana') return _num(item['precio_mediana']);
    if (t == 'grande') return _num(item['precio_grande']);
    return _num(item['precio'] ?? item['precio_personal']);
  }

  double _num(dynamic v) => (v ?? 0).toDouble();

  double get _total {
    double t = 0;
    for (final l in _pedido) t += l.subtotal;
    return t;
  }

  bool _validarEscenario() {
    if (_escenario == 'mesa' && _numeroMesa.trim().isEmpty) {
      _snack('Indique el número de mesa.');
      return false;
    }
    if (_escenario == 'para_llevar' && _clienteNombre.trim().isEmpty) {
      _snack('Indique el nombre de la persona para llevar.');
      return false;
    }
    if (_pedido.isEmpty) {
      _snack('El pedido está vacío.');
      return false;
    }
    return true;
  }

  Future<void> _cobrar() async {
    if (!_validarEscenario()) return;
    setState(() => _cobrando = true);
    final body = <String, dynamic>{
      'escenario': _escenario,
      'numero_mesa': _escenario == 'mesa' ? _numeroMesa.trim() : null,
      'cliente_nombre':
          (_escenario == 'para_llevar' || _escenario == 'domicilio')
              ? _clienteNombre.trim().isEmpty
                  ? null
                  : _clienteNombre.trim()
              : null,
      'direccion': _escenario == 'domicilio' && _direccion.isNotEmpty ? _direccion : null,
      'telefono': _escenario == 'domicilio' && _telefono.isNotEmpty ? _telefono : null,
      'id_forma_pago': _formaPagoId,
      'items': [
        for (final l in _pedido)
          {
            'id_producto': l.idProducto,
            'tamanio': l.tamanio,
            'cantidad': l.cantidad,
          }
      ],
    };
    final r = await ApiClient.crearVenta(body);
    if (!mounted) return;
    setState(() => _cobrando = false);
    if (r.ok) {
      _snack('Venta registrada: $r.message');
      setState(() {
        _pedido.clear();
        _numeroMesa = '';
        _clienteNombre = '';
        _direccion = '';
        _telefono = '';
      });
    } else {
      _snack(r.message);
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    // Always render the POS structure. The catalog area shows its own loader
    // or error; the screen never blocks on an infinite spinner.
    // Responsive: wide => two columns (catalog left, order right).
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 1000;
      final catalogo = _catalogoPanel(wide: wide);
      final comanda = _comandaPanel();
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: catalogo),
          SizedBox(width: 360, child: comanda),
        ]);
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          _selectorEscenario(),
          const SizedBox(height: 8),
          catalogo,
          const SizedBox(height: 12),
          comanda,
        ]),
      );
    });
  }

  Widget _selectorEscenario() {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Mesa'),
          selected: _escenario == 'mesa',
          onSelected: (_) => setState(() => _escenario = 'mesa'),
        ),
        ChoiceChip(
          label: const Text('Para llevar'),
          selected: _escenario == 'para_llevar',
          onSelected: (_) => setState(() => _escenario = 'para_llevar'),
        ),
        ChoiceChip(
          label: const Text('Domicilio'),
          selected: _escenario == 'domicilio',
          onSelected: (_) => setState(() => _escenario = 'domicilio'),
        ),
      ],
    );
  }

  Widget _catalogoPanel({bool wide = false}) {
    // Mobile: chips (horizontal) + horizontal slider of products.
    // Desktop: full grid of categories.
    Widget content;
    if (_loading) {
      content = const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    } else if (_error != null) {
      content = Padding(padding: const EdgeInsets.all(16), child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    } else if (wide) {
      content = ListView(
        padding: const EdgeInsets.all(8),
        children: [
          for (final cat in _categorias) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(cat['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final it in _filtrados(cat))
                  SizedBox(width: 150, child: _productoBoton(it)),
              ],
            ),
          ],
        ],
      );
    } else {
      // Mobile: chips to pick a category, then horizontal slider of its products.
      content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final c in _categorias)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c['nombre'] ?? ''),
                    selected: _categoriaSel == (c['id'] as int?),
                    onSelected: (_) => setState(() => _categoriaSel = c['id'] as int?),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final it in _itemsDeCategoriaSel())
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(width: 150, child: _productoBoton(it)),
                ),
            ],
          ),
        ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: const InputDecoration(
                hintText: 'Buscar producto…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Formas de pago',
            icon: const Icon(Icons.tune),
            onPressed: _gestionarFormas,
          ),
        ]),
      ),
      if (wide)
        Expanded(child: content)
      else
        content,
    ]);
  }

  /// Products of the selected category (or all if none selected / searching).
  List<Map<String, dynamic>> _itemsDeCategoriaSel() {
    if (_categoriaSel == null) {
      // all categories' items, flattened, filtered by search
      return _categorias
          .expand((c) => (c['items'] as List? ?? []).cast<Map<String, dynamic>>())
          .cast<Map<String, dynamic>>()
          .where((i) {
            final n = (i['nombre'] ?? '').toString().toLowerCase();
            return _busqueda.isEmpty || n.contains(_busqueda.toLowerCase());
          })
          .toList();
    }
    for (final c in _categorias) {
      if (c['id'] == _categoriaSel) {
        return _filtrados(c);
      }
    }
    return [];
  }

  List<Map<String, dynamic>> _filtrados(Map<String, dynamic> cat) {
    final its = (cat['items'] as List? ?? []).cast<Map<String, dynamic>>();
    if (_busqueda.isEmpty) return its;
    return its.where((i) {
      final n = (i['nombre'] ?? '').toString().toLowerCase();
      return n.contains(_busqueda.toLowerCase());
    }).toList();
  }

  Widget _productoBoton(Map<String, dynamic> it) {
    final conTamanos = it['precio_personal'] != null;
    final nombre = it['nombre'] ?? '';
    // On tap, if the product has sizes, ask which size; else add directly.
    return Material(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (conTamanos) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(nombre),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                    title: const Text('Personal'),
                    subtitle: Text(money(it['precio_personal'])),
                    onTap: () { Navigator.pop(context); _agregar(it, 'personal'); },
                  ),
                  ListTile(
                    title: const Text('Mediana'),
                    subtitle: Text(money(it['precio_mediana'])),
                    onTap: () { Navigator.pop(context); _agregar(it, 'mediana'); },
                  ),
                  ListTile(
                    title: const Text('Grande'),
                    subtitle: Text(money(it['precio_grande'])),
                    onTap: () { Navigator.pop(context); _agregar(it, 'grande'); },
                  ),
                ]),
              ),
            );
          } else {
            _agregar(it, null);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            Text(money(it['precio_personal'] ?? it['precio']),
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
        ),
      ),
    );
  }

  Widget _comandaPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_escenario == 'mesa')
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Número de mesa', border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => _numeroMesa = v,
          ),
        if (_escenario == 'para_llevar' || _escenario == 'domicilio')
          TextField(
            decoration: const InputDecoration(labelText: 'Nombre de la persona', border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => _clienteNombre = v,
          ),
        if (_escenario == 'domicilio') ...[
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => _direccion = v,
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => _telefono = v,
          ),
        ],
        const SizedBox(height: 10),
        const Text('Pedido', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        if (_pedido.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Toca un producto para agregarlo.', style: TextStyle(color: Colors.grey)),
          ),
        for (final l in _pedido)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${l.nombre}${l.tamanio != null ? ' (${l.tamanio})' : ''}'),
            subtitle: Text('${money(l.precio)} ×${l.cantidad}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() { if (l.cantidad > 1) l.cantidad--; else _pedido.remove(l); }), visualDensity: VisualDensity.compact),
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => l.cantidad++), visualDensity: VisualDensity.compact),
              ],
            ),
          ),
        const Divider(),
        Row(children: [
          const Text('Total: ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(money(_total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<int?>(
          value: _formaPagoId,
          decoration: const InputDecoration(labelText: 'Forma de pago', border: OutlineInputBorder(), isDense: true),
          items: [
            for (final f in _formas)
              DropdownMenuItem(value: f['id'] as int, child: Text(f['nombre'] ?? '')),
          ],
          onChanged: (v) => setState(() => _formaPagoId = v),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _cobrando ? null : _cobrar,
          icon: const Icon(Icons.payments),
          label: Text(_cobrando ? 'Procesando…' : 'Cobrar'),
        ),
      ]),
    );
  }

  /// Manage payment methods (editable catalog).
  Future<void> _gestionarFormas() async {
    final nombre = await _dialogNombre('Nueva forma de pago');
    if (nombre != null && nombre.trim().isNotEmpty) {
      final r = await ApiClient.crearFormaPago(nombre.trim());
      _snack(r.message);
      _load();
    }
  }

  Future<String?> _dialogNombre(String titulo) async {
    final c = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'Nombre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Guardar')),
        ],
      ),
    );
    return res;
  }
}