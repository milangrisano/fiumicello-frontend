import 'dart:async';
import 'package:flutter/material.dart';
import '../core/data/api_client.dart';
import '../core/utils/formatters.dart';
import 'pos_facturacion/pos_models.dart';
import 'pos_facturacion/pos_utils.dart'
    show numVal, precioDe;
import 'pos_facturacion/widgets/comanda_view.dart';
import 'pos_facturacion/widgets/resumen_ventas_view.dart';

/// POS invoicing — 3-stage flow.
class PosSalesView extends StatefulWidget {
  /// Callback para navegar a otra sección (p. ej. el Resumen de ventas).
  final ValueChanged<int>? onNavegar;
  const PosSalesView({super.key, this.onNavegar});

  @override
  State<PosSalesView> createState() => _PosSalesViewState();
}

class _PosSalesViewState extends State<PosSalesView> {
  Map<String, dynamic>? _carta;
  List<Map<String, dynamic>> _formas = [];
  final List<Linea> _comanda = [];
  String _escenario = 'mesa';
  String _numeroMesa = '';
  String _clienteNombre = '';
  String _direccion = '';
  String _telefono = '';
  int _pantalla = Pantalla.inicio;
  // Modo "agregar a mesa abierta": si no es null, la comanda se agrega a ese
  // pedido (mesa) al continuar, sin pasar por la etapa de asignación.
  int? _modoAgregarMesaId;

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
    final precio = precioDe(item, tamanio);
    setState(() {
      for (final l in _comanda) {
        if (l.idProducto == (item['id'] as int?) && l.tamanio == tamanio) {
          l.cantidad++;
          return;
        }
      }
      _comanda.add(Linea(
        idProducto: item['id'] as int,
        nombre: item['nombre'] ?? '',
        tamanio: tamanio,
        precio: precio,
      ));
    });
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  List<Map<String, dynamic>> get _itemsComandaJson => [
        for (final l in _comanda)
          if (!l.yaEnMesa) // no re-enviar los productos que ya estaban en la mesa
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
    // Modo "agregar a mesa abierta": añade la comanda a ese pedido y vuelve a
    // las mesas (sin pasar por la asignación, que ya se hizo la primera vez).
    if (_modoAgregarMesaId != null) {
      final nuevos = _comanda.where((l) => !l.yaEnMesa).toList();
      if (nuevos.isEmpty) {
        _snack('Agrega al menos un producto nuevo.');
        return;
      }
      setState(() => _cobrando = true);
      final r = await ApiClient.agregarItemsPedido(_modoAgregarMesaId!, _itemsComandaJson);
      if (!mounted) return;
      setState(() => _cobrando = false);
      if (!r.ok) {
        _snack(r.message);
        return;
      }
      _snack('Productos agregados a la mesa.');
      setState(() {
        _pantalla = Pantalla.mesas;
        _comanda.clear();
        _modoAgregarMesaId = null;
      });
      await _refreshVivos();
      return;
    }
    setState(() => _pantalla = Pantalla.asignacion);
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
        _pantalla = Pantalla.mesas;
        _comanda.clear();
        _numeroMesa = '';
      });
      await _refreshVivos();
    } else {
      setState(() {
        _cobroPedidoId = id;
        _pantalla = Pantalla.cobro;
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
        _pantalla = Pantalla.inicio;
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
      case Pantalla.comanda:
        return _vistaComanda();
      case Pantalla.asignacion:
        return _vistaAsignacion();
      case Pantalla.cobro:
        return _vistaCobro();
      case Pantalla.mesas:
        return _vistaMesas();
      case Pantalla.entregas:
        return _vistaEntregas();
      case Pantalla.resumen:
        return const ResumenVentasView();
      default:
        return _vistaInicio();
    }
  }

  Widget appIcon(IconData i, {double size = 28}) {
    return Icon(i, size: size, color: Theme.of(context).colorScheme.primary);
  }

  // ---------- Inicio ----------
  Widget _vistaInicio() {
    // Uniforme en TODAS las vistas: las 4 cards reparten el ancho disponible
    // (mismo tamaño flex), con gap uniforme y margen simétrico a los bordes.
    // Ancho grande -> 4 en fila; tablet/móvil -> se acomodan en cuadrícula, nunca
    // quedan flotando en espacio extra.
    final cards = <Widget>[
      _inicioCard('Nueva comanda', Icons.menu_book, () => setState(() { _comanda.clear(); _modoAgregarMesaId = null; _pantalla = Pantalla.comanda; })),
      _inicioCard('Mesas abiertas (${_mesasAbiertas.length})', Icons.restaurant, () async {
        await _refreshVivos();
        if (!mounted) return;
        if (_mesasAbiertas.isEmpty) { _snack('No hay mesas abiertas en este momento.'); return; }
        setState(() => _pantalla = Pantalla.mesas);
      }),
      _inicioCard('Pedidos por entregar (${_pendientes.length})', Icons.motorcycle, () async {
        await _refreshVivos();
        if (!mounted) return;
        if (_pendientes.isEmpty) { _snack('No hay pedidos pendientes de entrega.'); return; }
        setState(() => _pantalla = Pantalla.entregas);
      }),
      _inicioCard('Resumen de ventas', Icons.pie_chart, () => setState(() => _pantalla = Pantalla.resumen)),
    ];
    // Wrap uniforme: cards del mismo ancho (según ancho real de pantalla)
    // y mismo alto (IntrinsicHeight dentro de un alto fijo), gaps uniformes y
    // margen simétrico. Se acomoda a 4/2/1 columnas según el espacio.
    return LayoutBuilder(builder: (context, c) {
      final ancho = c.maxWidth;
      final gap = 20.0;
      final borde = 20.0;
      final cols = ancho >= 240 * 4 ? 4 : (ancho >= 240 * 2 ? 2 : 1);
      final cardAncho = (ancho - borde * 2 - gap * (cols - 1)) / cols;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: const Text('POS de facturación', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: EdgeInsets.all(borde),
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final card in cards)
                  SizedBox(width: cardAncho, child: card),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _inicioCard(String titulo, IconData icon, VoidCallback onTap) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Flexible(child: Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Etapa 1: Comanda ----------
  Widget _vistaComanda() {
    return ComandaView(
      items: _comanda.toList(),
      total: _totalComanda,
      categorias: _categorias,
      busqueda: _busqueda,
      categoriaSel: _categoriaSel,
      error: _error,
      onAgregar: (it, tam) => _agregar(it, tam),
      onBuscar: (v) => setState(() => _busqueda = v),
      onCategoria: (id) => setState(() => _categoriaSel = id),
      onQuitar: _quitarLinea,
      onNota: _editarNota,
      onSumar: _sumarLinea,
      onContinuar: _siguienteEtapa,
      onVolver: () => setState(() => _pantalla = Pantalla.inicio),
    );
  }

  void _quitarLinea(Linea l) {
    setState(() { if (l.cantidad > 1) l.cantidad--; else _comanda.remove(l); });
  }

  Future<void> _editarNota(Linea l) async {
    final n = await _dialogNota('${l.nombre} — Nota');
    if (n != null && mounted) setState(() => l.nota = n);
  }

  void _sumarLinea(Linea l) {
    setState(() => l.cantidad++);
  }

// ---------- Etapa 2: Asignación ----------
  Widget _vistaAsignacion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _pantalla = Pantalla.comanda)),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _pantalla = Pantalla.asignacion)),
          const Text('Etapa 3 · Cobro', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        const Text('Para llevar / Domicilio — se cobra ahora y queda pendiente de entrega.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        Text('Total: ${money(_totalComanda)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        DropdownButtonFormField<int?>(
          initialValue: _cobroFormaPago,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _pantalla = Pantalla.inicio)),
          Text('Mesas abiertas (${_mesasAbiertas.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        if (_mesasAbiertas.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No hay mesas abiertas.', style: TextStyle(color: Colors.grey))),
        for (final m in _mesasAbiertas) _mesaCard(m),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: () => setState(() { _comanda.clear(); _modoAgregarMesaId = null; _pantalla = Pantalla.comanda; }), icon: const Icon(Icons.menu_book), label: const Text('Nueva comanda')),
      ]),
    );
  }

  Widget _mesaCard(Map<String, dynamic> m) {
    final id = m['id'] as int;
    final items = (m['items'] as List? ?? []).cast<Map<String, dynamic>>();
    final total = numVal(m['total']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            appIcon(Icons.restaurant, size: 22),
            const SizedBox(width: 8),
            Flexible(child: Text('Mesa ${m['numero_mesa'] ?? m['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            const SizedBox(width: 8),
            Text(money(total), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
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
    // Va a la comanda en modo "agregar a esta mesa": carga los productos que la
    // mesa YA tiene ordenados (para ver el contexto) y al continuar se añaden
    // los nuevos al pedido existente (sin pasar por la asignación).
    setState(() {
      _comanda.clear();
      for (final it in (m['items'] as List? ?? []).cast<Map<String, dynamic>>()) {
        _comanda.add(Linea(
          idProducto: (it['id_producto'] ?? it['id']) as int,
          nombre: it['nombre'] ?? '',
          tamanio: it['tamanio'] as String?,
          precio: numVal(it['precio_unitario'] ?? it['precio']),
          cantidad: (it['cantidad'] as int?) ?? 1,
          nota: it['nota'] as String? ?? '',
          yaEnMesa: true,
        ));
      }
      _modoAgregarMesaId = m['id'] as int?;
      _pantalla = Pantalla.comanda;
    });
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _pantalla = Pantalla.inicio)),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            appIcon(esDomicilio ? Icons.motorcycle : Icons.takeout_dining, size: 22),
            const SizedBox(width: 8),
            Flexible(child: Text(esDomicilio ? 'Domicilio' : 'Para llevar', style: const TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
            Text(transcurrido, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 2),
        Text('Cliente: $nombre', style: const TextStyle(fontWeight: FontWeight.w600)),
        if (p['direccion'] != null) Text('Dirección: ${p['direccion']}', style: const TextStyle(fontSize: 13)),
        Text('Total: ${money(numVal(p['total']))}', style: const TextStyle(fontWeight: FontWeight.w600)),
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