import 'package:flutter/material.dart';
import '../core/data/api_client.dart';
import '../core/utils/formatters.dart';

/// SuperAdmin/Admin screen: manage menu products (active/disabled), edit them,
/// create/delete. Uses the carta items (single catalog).
class ProductsView extends StatefulWidget {
  const ProductsView({super.key});

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView> {
  Map<String, dynamic>? _carta;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiClient.obtenerCartaAdmin();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _carta = r.data;
      } else {
        _error = r.message;
      }
    });
  }

  List<Map<String, dynamic>> get _categorias =>
      (_carta?['categorias'] as List? ?? []).cast<Map<String, dynamic>>();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text('Productos', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Nuevo producto'),
                onPressed: _crear,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final c in _categorias) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Text(c['nombre'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                for (final it in (c['items'] as List? ?? []).cast<Map<String, dynamic>>())
                  _item(it, c['id'] as int? ?? 0, c['nombre'] as String? ?? ''),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _item(Map<String, dynamic> it, int catId, String catNombre) {
    final id = it['id'] as int? ?? 0;
    final activo = it['activo'] == true;
    final conTamanos = it['precio_personal'] != null;
    Color chipColor = activo ? Colors.green[600]! : Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: activo ? Colors.transparent : Colors.grey.shade300),
      ),
      child: ListTile(
        enabled: activo,
        leading: CircleAvatar(
          backgroundColor: chipColor,
          child: activo ? const Icon(Icons.check, color: Colors.white, size: 18) : const Icon(Icons.block, color: Colors.white, size: 18),
        ),
        title: Text(it['nombre'] ?? '', style: activo ? null : const TextStyle(color: Colors.grey)),
        subtitle: Text(
          conTamanos
              ? 'Personal ${money(it['precio_personal'])} · Mediana ${money(it['precio_mediana'])} · Grande ${money(it['precio_grande'])}'
              : money(it['precio']),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.visibility_off, color: activo ? Colors.grey : Colors.orange),
              tooltip: activo ? 'Deshabilitar' : 'Habilitar',
              onPressed: () => _toggle(id, activo),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: () => _editar(it, catId, catNombre),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Eliminar',
              onPressed: () => _eliminar(id, it['nombre'] ?? ''),
            ),
          ],
        ),
        onTap: () => _editar(it, catId, catNombre),
      ),
    );
  }

  Future<void> _toggle(int id, bool activo) async {
    final r = await ApiClient.toggleProductoActivo(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.ok ? (activo ? 'Producto deshabilitado' : 'Producto habilitado') : r.message)));
    _load();
  }

  Future<void> _eliminar(int id, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "$nombre"? Solo se elimina si nunca se ha facturado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final r = await ApiClient.eliminarItemCarta(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    _load();
  }

  Future<void> _crear() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductEditView(categorias: _categorias),
    ));
    _load();
  }

  Future<void> _editar(Map<String, dynamic> it, int catId, String catNombre) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductEditView(
        categorias: _categorias,
        producto: it,
        categoriaId: catId,
        categoriaNombre: catNombre,
      ),
    ));
    _load();
  }
}

/// Create/edit form for a single product.
class ProductEditView extends StatefulWidget {
  final List<Map<String, dynamic>> categorias;
  final Map<String, dynamic>? producto;
  final int? categoriaId;
  final String? categoriaNombre;

  const ProductEditView({
    super.key,
    required this.categorias,
    this.producto,
    this.categoriaId,
    this.categoriaNombre,
  });

  @override
  State<ProductEditView> createState() => _ProductEditViewState();
}

class _ProductEditViewState extends State<ProductEditView> {
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final TextEditingController _precio;
  late final TextEditingController _pPersonal;
  late final TextEditingController _pMediana;
  late final TextEditingController _pGrande;
  int _categoria;
  bool _esNuevo = true;
  bool _saving = false;

  _ProductEditViewState() : _categoria = 0;

  @override
  void initState() {
    super.initState();
    _esNuevo = widget.producto == null;
    _categoria = widget.categoriaId ?? (widget.categorias.isNotEmpty ? widget.categorias.first['id'] as int : 0);
    _nombre = TextEditingController(text: widget.producto?['nombre'] ?? '');
    _descripcion = TextEditingController(text: widget.producto?['descripcion'] ?? '');
    _precio = TextEditingController(text: _fmt(widget.producto?['precio']));
    _pPersonal = TextEditingController(text: _fmt(widget.producto?['precio_personal']));
    _pMediana = TextEditingController(text: _fmt(widget.producto?['precio_mediana']));
    _pGrande = TextEditingController(text: _fmt(widget.producto?['precio_grande']));
  }

  String _fmt(dynamic v) {
    if (v == null) return '';
    return v.toString();
  }

  double _toNum(String s) => double.tryParse(s.trim().replaceAll('.', '')) ?? 0;

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre requerido.')));
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'id_categoria': _categoria,
      'nombre': nombre,
      'descripcion': _descripcion.text.trim().isEmpty ? null : _descripcion.text.trim(),
      'precio': _precio.text.trim().isEmpty ? null : _toNum(_precio.text),
      'precio_personal': _pPersonal.text.trim().isEmpty ? null : _toNum(_pPersonal.text),
      'precio_mediana': _pMediana.text.trim().isEmpty ? null : _toNum(_pMediana.text),
      'precio_grande': _pGrande.text.trim().isEmpty ? null : _toNum(_pGrande.text),
    };
    final r = _esNuevo
        ? await ApiClient.crearItemCarta(body)
        : await ApiClient.actualizarItemCarta(widget.producto!['id'] as int, body);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    if (r.ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esNuevo ? 'Nuevo producto' : 'Editar producto')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            value: _categoria,
            decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
            items: [
              for (final c in widget.categorias)
                DropdownMenuItem(value: c['id'] as int, child: Text(c['nombre'] ?? '')),
            ],
            onChanged: (v) => setState(() => _categoria = v ?? 0),
          ),
          const SizedBox(height: 12),
          TextField(controller: _nombre, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _descripcion, decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          const Text('Precio (si no tiene tamaños)'),
          TextField(controller: _precio, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 12),
          const Text('Precios por tamaño (opcional)'),
          Row(children: [
            Expanded(child: TextField(controller: _pPersonal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Personal', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _pMediana, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Mediana', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _pGrande, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Grande', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _guardar,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_esNuevo ? 'Crear producto' : 'Guardar cambios'),
          ),
        ],
      ),
    );
  }
}