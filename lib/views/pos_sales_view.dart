import 'dart:async';
import 'package:flutter/material.dart';
import '../core/data/api_client.dart';
import '../core/utils/formatters.dart';

/// POS invoicing — 3-stage flow.
class PosSalesView extends StatefulWidget {
  const PosSalesView({super.key});

  @override
  State<PosSalesView> createState() => _PosSalesViewState();
}

/// A product line being composed (stage 1).
class _Linea {
  final int idProducto;
  final String nombre;
  final String? tamanio;
  final double precio;
  int cantidad;
  String nota;

  _Linea({
    required this.idProducto,
    required this.nombre,
    this.tamanio,
    required this.precio,
    this.cantidad = 1,
    this.nota = '',
  });

  double get subtotal => precio * cantidad;
}

class _Pantalla {
  static const int inicio = 0;
  static const int comanda = 1;
  static const int asignacion = 2;
  static const int cobro = 3;
  static const int mesas = 4;
  static const int entregas = 5;
}

class _PosSalesViewState extends State<PosSalesView> {
  Map<String, dynamic>? _carta;
  List<Map<String, dynamic>> _formas = [];
  final List<_Linea> _comanda = [];
  String _escenario = 'mesa';
  String _numeroMesa = '';
  String _clienteNombre = '';
  String _direccion = '';
  String _telefono = '';
  int _pantalla = _Pantalla.inicio;

  List<Map<String, dynamic>> _mesasAbiertas = [];
  List<Map<String, dynamic>> _pendientes = [];

  bool _loading = true;
  bool _cobrando = false;
  String? _error;
  String _busqueda = '';
  int? _categoriaSel;
  int? _cobroFormaPago;
  int? _cobroPedidoId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final c = await ApiClient.obtenerCarta().timeout(const Duration(seconds: 15));
      final f = await ApiClient.listarFormasPago().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        if (c.ok && c.data != null) _carta = c.data;
        else _error = c.message;
        if (f.ok) _formas = f.list.cast<Map<String, dynamic>>();
        if (_cobroFormaPago == null && _formas.isNotEmpty) {
          _cobroFormaPago = _formas.first['id'] as int?;
        }
        _loading = false;
      });
      await _refreshVivos();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _refreshVivos() async {
    final m = await ApiClient.listarPedidos(estado: 'abierta', escenario: 'mesa');
    final p = await ApiClient.listarPedidos(estado: 'pagada_pendiente');
    if (!mounted) return;
    setState(() {
      _mesasAbiertas = m.ok ? m.list.cast<Map<String, dynamic>>() : [];
      _pendientes = p.ok ? p.list.cast<Map<String, dynamic>>() : [];
    });
  }

  List<Map<String, dynamic>> get _categorias =>
      (_carta?['categorias'] as List? ?? []).cast<Map<String, dynamic>>();

  double get _totalComanda {
    double t = 0;
    for (final l in _comanda) t += l.subtotal;
    return t;
  }

  void _agregar(Map<String, dynamic> item, String? tamanio) {
    final precio = _precioDe(item, tamanio);
    setState(() {
      for (final l in _comanda) {
        if (l.idProducto == (item['id'] as int?) && l.tamanio == tamanio) {
          l.cantidad++;
          return;
        }
      }
      _comanda.add(_Linea(
        idProducto: item['id'] as int,
        nombre: item['nombre'] ?? '',
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

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  List<Map<String, dynamic>> get _itemsComandaJson => [
        for (final l in _comanda)
          {
            'id_producto': l.idProducto,
            'tamanio': l.tamanio,
            'cantidad': l.cantidad,
            'nota': l.nota.isEmpty ? null : l.nota,
          }
      ];

  Future<void> _siguienteEtapa() async {
    if (_comanda.isEmpty) {
      _snack('Agrega al menos un producto.');
      return;
    }
    setState(() => _pantalla = _Pantalla.asignacion);
  }

  Future<void> _crearPedido() async {
    if (_escenario == 'mesa' && _numeroMesa.trim().isEmpty) {
      _snack('Indique el número de mesa.');
      return;
    }
    if (_escenario == 'para_llevar' && _clienteNombre.trim().isEmpty) {
      _snack('Indique el nombre de la persona para llevar.');
      return;
    }
    if (_escenario == 'domicilio' && _clienteNombre.trim().isEmpty) {
      _snack('Indique el nombre para el domicilio.');
      return;
    }
    setState(() => _cobrando = true);
    final body = <String, dynamic>{
      'escenario': _escenario,
      'numero_mesa': _escenario == 'mesa' ? _numeroMesa.trim() : null,
      'cliente_nombre': _escenario == 'mesa' ? null
          : (_clienteNombre.trim().isEmpty ? null : _clienteNombre.trim()),
      'direccion': (_escenario == 'domicilio' && _direccion.isNotEmpty) ? _direccion : null,
      'telefono': (_escenario == 'domicilio' && _telefono.isNotEmpty) ? _telefono : null,
      'items': _itemsComandaJson,
    };
    final r = await ApiClient.crearPedido(body);
    if (!mounted) return;
    setState(() => _cobrando = false);
    if (!r.ok) {
      _snack(r.message);
      return;
    }
    final id = await _idDelPedido();
    if (_escenario == 'mesa') {
      _snack('Mesa ${_numeroMesa.trim()} abierta.');
      setState(() {
        _pantalla = _Pantalla.mesas;
        _comanda.clear();
        _numeroMesa = '';
      });
      await _refreshVivos();
    } else {
      setState(() {
        _cobroPedidoId = id;
        _pantalla = _Pantalla.cobro;
      });
    }
  }

  Future<int?> _idDelPedido() async {
    final p = await ApiClient.listarPedidos();
    if (p.ok && p.list.isNotEmpty) {
      final last = p.list.first as Map<String, dynamic>;
      return last['id'] as int?;
    }
    return null;
  }

  Future<void> _ejecutarCobro(int pedidoId) async {
    setState(() => _cobrando = true);
    final r = await ApiClient.cobrarPedido(pedidoId, _cobroFormaPago);
    if (!mounted) return;
    setState(() => _cobrando = false);
    _snack(r.ok ? 'Cobrado: ${r.message}' : r.message);
    if (r.ok) {
      setState(() {
        _pantalla = _Pantalla.inicio;
        _comanda.clear();
        _numeroMesa = '';
        _clienteNombre = '';
        _direccion = '';
        _telefono = '';
      });
      await _refreshVivos();
    }
  }

  Future<void> _agregarAMesa(int pedidoId, Map<String, dynamic> item, String? tamanio) async {
    final nota = await _dialogNota('${item['nombre']} — Nota (opcional)');
    setState(() => _cobrando = true);
    final r = await ApiClient.agregarItemsPedido(pedidoId, [
          {
            'id_producto': item['id'] as int,
            'tamanio': tamanio,
            'cantidad': 1,
            'nota': (nota != null && nota.trim().isNotEmpty) ? nota : null,
          }
        ]);
    if (!mounted) return;
    setState(() => _cobrando = false);
    _snack(r.ok ? 'Producto agregado a la mesa.' : r.message);
    await _refreshVivos();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    }
    // Renderizado por pantalla del flujo POS.
    switch (_pantalla) {
      case _Pantalla.comanda:
        return _vistaComanda();
      case _Pantalla.asignacion:
        return _vistaAsignacion();
      case _Pantalla.cobro:
        return _vistaCobro();
      case _Pantalla.mesas:
        return _vistaMesas();
      case _Pantalla.entregas:
        return _vistaEntregas();
      default:
        return _vistaInicio();
    }
  }

  Widget _icono(IconData i, {double size = 28}) {
    return Icon(i, size: size, color: Theme.of(context).colorScheme.primary);
  }

  // ---------- Inicio ----------
  Widget _vistaInicio() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: const Text('POS de facturación', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        ),
        _inicioCard('Nueva comanda', Icons.menu_book, () => setState(() { _comanda.clear(); _pantalla = _Pantalla.comanda; })),
        _inicioCard('Mesas abiertas (${_mesasAbiertas.length})', Icons.restaurant, () async {
          await _refreshVivos();
          if (!mounted) return;
          if (_mesasAbiertas.isEmpty) {
            _snack('No hay mesas abiertas en este momento.');
            return;
          }
          setState(() => _pantalla = _Pantalla.mesas);
        }),
        _inicioCard('Pedidos por entregar (${_pendientes.length})', Icons.motorcycle, () async {
          await _refreshVivos();
          if (!mounted) return;
          if (_pendientes.isEmpty) {
            _snack('No hay pedidos pendientes de entrega.');
            return;
          }
          setState(() => _pantalla = _Pantalla.entregas);
        }),
      ],
    );
  }

  Widget _inicioCard(String titulo, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton.icon(
        onPressed: onTap,
        icon: _icono(icon, size: 24),
        label: Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ---------- Etapa 1: Comanda ----------
  Widget _vistaComanda() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _pantalla = _Pantalla.inicio)),
          const Spacer(),
          const Text('Etapa 1 · Comanda', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        _catalogoPanel(),
        const Divider(),
        const Text('Comanda', style: TextStyle(fontWeight: FontWeight.bold)),
        if (_comanda.isEmpty)
          const Text('Sin productos aún.', style: TextStyle(color: Colors.grey)),
        for (final l in _comanda)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${l.nombre}${l.tamanio != null ? ' (${l.tamanio})' : ''}'),
            subtitle: Text('${money(l.precio)} ×${l.cantidad}${l.nota.isEmpty ? '' : ' · nota: ${l.nota}'}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() { if (l.cantidad > 1) l.cantidad--; else _comanda.remove(l); }), visualDensity: VisualDensity.compact),
              IconButton(icon: const Icon(Icons.create), tooltip: 'Nota', onPressed: () async { final n = await _dialogNota('${l.nombre} — Nota'); if (n != null) { if (mounted) setState(() => l.nota = n); } }, visualDensity: VisualDensity.compact),
              IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => l.cantidad++), visualDensity: VisualDensity.compact),
            ]),
          ),
        const Divider(),
        Text('Total: ${money(_totalComanda)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _siguienteEtapa,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Continuar → Asignación'),
        ),
      ]),
    );
  }

  Widget _catalogoPanel() {
    Widget content;
    if (_error != null) {
      content = Text('Error: $_error', style: const TextStyle(color: Colors.red));
    } else {
      content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final c in _categorias)
                Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                  label: Text(c['nombre'] ?? ''),
                  selected: _categoriaSel == (c['id'] as int?),
                  onSelected: (_) => setState(() => _categoriaSel = c['id'] as int?),
                )),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 130,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final it in _itemsDeCategoriaSel())
                Padding(padding: const EdgeInsets.only(right: 8), child: SizedBox(width: 150, child: _productoBoton(it))),
            ],
          ),
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        onChanged: (v) => setState(() => _busqueda = v),
        decoration: const InputDecoration(hintText: 'Buscar producto…', prefixIcon: Icon(Icons.search), isDense: true, border: OutlineInputBorder()),
      ),
      content,
    ]);
  }

  List<Map<String, dynamic>> _itemsDeCategoriaSel() {
    final b = _busqueda.toLowerCase();
    if (_categoriaSel == null) {
      return _categorias
          .expand((c) => (c['items'] as List? ?? []).cast<Map<String, dynamic>>())
          .cast<Map<String, dynamic>>()
          .where((i) => b.isEmpty || (i['nombre'] ?? '').toString().toLowerCase().contains(b))
          .toList();
    }
    for (final c in _categorias) {
      if (c['id'] == _categoriaSel) return _filtrados(c);
    }
    return [];
  }

  List<Map<String, dynamic>> _filtrados(Map<String, dynamic> cat) {
    final its = (cat['items'] as List? ?? []).cast<Map<String, dynamic>>();
    if (_busqueda.isEmpty) return its;
    final b = _busqueda.toLowerCase();
    return its.where((i) => (i['nombre'] ?? '').toString().toLowerCase().contains(b)).toList();
  }

  Widget _productoBoton(Map<String, dynamic> it) {
    final conTamanos = it['precio_personal'] != null;
    final nombre = it['nombre'] ?? '';
    return FilledButton(
      onPressed: () {
        if (conTamanos) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(nombre),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                FilledButton(onPressed: () { Navigator.pop(context); _agregar(it, 'personal'); }, child: Text('Personal · ${money(it['precio_personal'])}')),
                const SizedBox(height: 6),
                FilledButton(onPressed: () { Navigator.pop(context); _agregar(it, 'mediana'); }, child: Text('Mediana · ${money(it['precio_mediana'])}')),
                const SizedBox(height: 6),
                FilledButton(onPressed: () { Navigator.pop(context); _agregar(it, 'grande'); }, child: Text('Grande · ${money(it['precio_grande'])}')),
              ]),
            ),
          );
        } else {
          _agregar(it, null);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text(money(it['precio_personal'] ?? it['precio']), style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }

  // ---------- Etapa 2: Asignación ----------
  Widget _vistaAsignacion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _pantalla = _Pantalla.comanda)),
          const Spacer(),
          const Text('Etapa 2 · Asignación', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Mesa'), selected: _escenario == 'mesa', onSelected: (_) => setState(() => _escenario = 'mesa')),
          ChoiceChip(label: const Text('Para llevar'), selected: _escenario == 'para_llevar', onSelected: (_) => setState(() => _escenario = 'para_llevar')),
          ChoiceChip(label: const Text('Domicilio'), selected: _escenario == 'domicilio', onSelected: (_) => setState(() => _escenario = 'domicilio')),
        ]),
        const SizedBox(height: 12),
        if (_escenario == 'mesa')
          TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Número de mesa', border: OutlineInputBorder(), isDense: true), onChanged: (v) => _numeroMesa = v),
        if (_escenario == 'para_llevar' || _escenario == 'domicilio') ...[
          TextField(decoration: const InputDecoration(labelText: 'Nombre de la persona', border: OutlineInputBorder(), isDense: true), onChanged: (v) => _clienteNombre = v),
          if (_escenario == 'domicilio') ...[
            const SizedBox(height: 8),
            TextField(decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder(), isDense: true), onChanged: (v) => _direccion = v),
            const SizedBox(height: 8),
            TextField(decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder(), isDense: true), onChanged: (v) => _telefono = v),
          ],
        ],
        const SizedBox(height: 16),
        Text('Items: ${_comanda.length} · Total: ${money(_totalComanda)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _cobrando ? null : _crearPedido,
          icon: const Icon(Icons.checklist),
          label: Text(_escenario == 'mesa' ? 'Abrir mesa' : 'Cobrar ahora y a preparar'),
        ),
      ]),
    );
  }

  // ---------- Etapa 3: Cobro ----------
  Widget _vistaCobro() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _pantalla = _Pantalla.asignacion)),
          const Spacer(),
          const Text('Etapa 3 · Cobro', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        const Text('Para llevar / Domicilio — se cobra ahora y queda pendiente de entrega.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        Text('Total: ${money(_totalComanda)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        DropdownButtonFormField<int?>(
          value: _cobroFormaPago,
          decoration: const InputDecoration(labelText: 'Forma de pago', border: OutlineInputBorder(), isDense: true),
          items: [for (final f in _formas) DropdownMenuItem(value: f['id'] as int, child: Text(f['nombre'] ?? ''))],
          onChanged: (v) => setState(() => _cobroFormaPago = v),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _cobrando || _cobroPedidoId == null ? null : () => _ejecutarCobro(_cobroPedidoId!),
          icon: const Icon(Icons.payments),
          label: Text(_cobrando ? 'Procesando…' : 'Confirmar cobro'),
        ),
      ]),
    );
  }

  // ---------- Mesas abiertas ----------
  Widget _vistaMesas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _pantalla = _Pantalla.inicio)),
          const Spacer(),
          Text('Mesas abiertas (${_mesasAbiertas.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        if (_mesasAbiertas.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No hay mesas abiertas.', style: TextStyle(color: Colors.grey))),
        for (final m in _mesasAbiertas) _mesaCard(m),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: () => setState(() => _pantalla = _Pantalla.comanda), icon: const Icon(Icons.menu_book), label: const Text('Nueva comanda')),
      ]),
    );
  }

  Widget _mesaCard(Map<String, dynamic> m) {
    final id = m['id'] as int;
    final items = (m['items'] as List? ?? []).cast<Map<String, dynamic>>();
    final total = _num(m['total']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _icono(Icons.restaurant, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text('Mesa ${m['numero_mesa'] ?? m['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          Text(money(total), style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        for (final i in items)
          Text('• ${i['nombre']}${i['tamanio'] != null ? ' (${i['tamanio']})' : ''} ×${i['cantidad']}${i['nota'] != null ? ' — ${i['nota']}' : ''}', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [
          OutlinedButton(onPressed: () async { await _agregarProductoMesa(m); }, child: const Text('Agregar')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () async { final ok = await _dialogConfirm('¿Pedir la cuenta de la mesa ${m['numero_mesa']}?'); if (ok == true) await _ejecutarCobro(id); }, child: const Text('Pedir la cuenta')),
        ]),
      ]),
    );
  }

  Future<void> _agregarProductoMesa(Map<String, dynamic> m) async {
    final nombre = m['numero_mesa'] ?? m['id'];
    final it = await _dialogElegirProducto('Agregar a mesa $nombre');
    if (it == null) return;
    final conTamanos = it['precio_personal'] != null;
    if (conTamanos) {
      final tam = await _dialogTamanio(it);
      if (tam == null) return;
      await _agregarAMesa(m['id'] as int, it, tam);
    } else {
      await _agregarAMesa(m['id'] as int, it, null);
    }
  }

  Future<Map<String, dynamic>?> _dialogElegirProducto(String titulo) async {
    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final it in _todosItems())
                Padding(padding: const EdgeInsets.only(right: 8), child: SizedBox(width: 150, child: _productoMini(it))),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _todosItems() =>
      _categorias.expand((c) => (c['items'] as List? ?? []).cast<Map<String, dynamic>>()).cast<Map<String, dynamic>>().toList();

  Widget _productoMini(Map<String, dynamic> it) {
    return FilledButton(
      onPressed: () => Navigator.pop(context, it),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(it['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          Text(money(it['precio_personal'] ?? it['precio']), style: const TextStyle(fontSize: 11)),
        ]),
      ),
    );
  }

  Future<String?> _dialogTamanio(Map<String, dynamic> it) async {
    return showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(it['nombre'] ?? ''),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: const Text('Personal'), subtitle: Text(money(it['precio_personal'])), onTap: () => Navigator.pop(context, 'personal')),
          ListTile(title: const Text('Mediana'), subtitle: Text(money(it['precio_mediana'])), onTap: () => Navigator.pop(context, 'mediana')),
          ListTile(title: const Text('Grande'), subtitle: Text(money(it['precio_grande'])), onTap: () => Navigator.pop(context, 'grande')),
        ]),
      ),
    );
  }

  // ---------- Pedidos por entregar ----------
  Widget _vistaEntregas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _pantalla = _Pantalla.inicio)),
          const Spacer(),
          Text('Pedidos por entregar (${_pendientes.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: () async { await _refreshVivos(); }),
        ]),
        const SizedBox(height: 8),
        if (_pendientes.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No hay pedidos pendientes de entrega.', style: TextStyle(color: Colors.grey))),
        for (final p in _pendientes) _pendienteCard(p),
      ]),
    );
  }

  Widget _pendienteCard(Map<String, dynamic> p) {
    final esDomicilio = p['escenario'] == 'domicilio';
    final nombre = (p['cliente_nombre'] ?? p['numero_mesa'] ?? '').toString();
    final transcurrido = _tiempoTranscurrido((p['hora_pedido'] ?? '').toString());
    final tint = esDomicilio ? Colors.orange : Colors.green;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint.shade100,
        border: Border.all(color: tint.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _icono(esDomicilio ? Icons.motorcycle : Icons.takeout_dining, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(esDomicilio ? 'Domicilio' : 'Para llevar', style: const TextStyle(fontWeight: FontWeight.bold))),
          Text(transcurrido, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ]),
        const SizedBox(height: 2),
        Text('Cliente: $nombre', style: const TextStyle(fontWeight: FontWeight.w600)),
        if (p['direccion'] != null) Text('Dirección: ${p['direccion']}', style: const TextStyle(fontSize: 13)),
        Text('Total: ${money(_num(p['total']))}', style: const TextStyle(fontWeight: FontWeight.w600)),
        if (p['numero_factura'] != null) Text('Factura: ${p['numero_factura']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: () async {
            final ok = await _dialogConfirm('¿Marcar como entregado?');
            if (ok == true) {
              final r = await ApiClient.entregarPedido(p['id'] as int);
              _snack(r.message);
              await _refreshVivos();
            }
          },
          icon: const Icon(Icons.check),
          label: const Text('Marcar entregado'),
        ),
      ]),
    );
  }

  String _tiempoTranscurrido(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    final min = diff.inMinutes;
    if (min < 1) return 'ahora';
    return '${min.toString()} min';
  }

  // ---------- Dialogs ----------
  Future<String?> _dialogNota(String titulo) async {
    final c = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(labelText: 'Nota (opcional)', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Aceptar')),
        ],
      ),
    );
  }

  Future<bool?> _dialogConfirm(String msg) async {
    return showDialog<bool?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
        ],
      ),
    );
  }

  Future<void> _gestionarFormas() async {
    final nombre = await _dialogNota('Nueva forma de pago');
    if (nombre != null && nombre.trim().isNotEmpty) {
      final r = await ApiClient.crearFormaPago(nombre.trim());
      _snack(r.message);
      await _load();
    }
  }
}