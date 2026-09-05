import 'package:flutter/material.dart';
import '../core/data/api_client.dart';

/// Superadmin/Admin screen: manage roles and their permissions dynamically.
///
/// Lists roles, lets you create new ones, rename them, and toggle which
/// permissions (module:action) each role has.
class RolesPermisosView extends StatefulWidget {
  const RolesPermisosView({super.key});

  @override
  State<RolesPermisosView> createState() => _RolesPermisosViewState();
}

class _RolesPermisosViewState extends State<RolesPermisosView> {
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _catalogo = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiClient.listRoles();
    final c = await ApiClient.catalogoPermisos();
    if (!mounted) return;
    setState(() {
      _roles = r.ok ? r.list.cast<Map<String, dynamic>>() : [];
      _catalogo = c.ok ? c.list.cast<Map<String, dynamic>>() : [];
      _loading = false;
      if (!r.ok) _error = r.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text('Roles y permisos', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Nuevo rol'),
              onPressed: _openCrear,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Configura qué puede ver y hacer cada rol.',
            style: TextStyle(color: Colors.grey)),
        const Divider(height: 24),
        for (final r in _roles) _rolCard(r),
      ],
    );
  }

  Widget _rolCard(Map<String, dynamic> rol) {
    final nombre = rol['nombre'] ?? '';
    final permisos = (rol['permisos'] as List? ?? []).cast<String>();
    final esBase = rol['es_base'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: Text(nombre),
        subtitle: Text(
          esBase ? '${permisos.length} permisos · rol base' : '${permisos.length} permisos',
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar permisos',
              onPressed: () => _openEditar(rol),
            ),
            if (!esBase)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Eliminar rol',
                onPressed: () => _eliminar(nombre),
              ),
          ],
        ),
        onTap: () => _openEditar(rol),
      ),
    );
  }

  Future<void> _openCrear() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _RoleEditView(catalogo: _catalogo),
    ));
    _load();
  }

  Future<void> _openEditar(Map<String, dynamic> rol) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _RoleEditView(
        catalogo: _catalogo,
        rolNombre: rol['nombre'] as String?,
        rolDescripcion: rol['descripcion'] as String?,
        rolPermisos: (rol['permisos'] as List? ?? []).cast<String>(),
      ),
    ));
    _load();
  }

  Future<void> _eliminar(String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar rol'),
        content: Text('¿Eliminar el rol "$nombre"?'),
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
    final r = await ApiClient.eliminarRol(nombre);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    _load();
  }
}

/// Editor for a single role: name, description, and permission toggles.
class _RoleEditView extends StatefulWidget {
  final List<Map<String, dynamic>> catalogo;
  final String? rolNombre;
  final String? rolDescripcion;
  final List<String> rolPermisos;

  const _RoleEditView({
    required this.catalogo,
    this.rolNombre,
    this.rolDescripcion,
    this.rolPermisos = const [],
  });

  @override
  State<_RoleEditView> createState() => _RoleEditViewState();
}

class _RoleEditViewState extends State<_RoleEditView> {
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late final Set<String> _permisos = {...widget.rolPermisos};
  bool _esNuevo = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _esNuevo = widget.rolNombre == null || widget.rolNombre!.isEmpty;
    _nombre = TextEditingController(text: widget.rolNombre ?? '');
    _descripcion = TextEditingController(text: widget.rolDescripcion ?? '');
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim().toLowerCase();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre requerido.')));
      return;
    }
    setState(() => _saving = true);
    final r = _esNuevo
        ? await ApiClient.crearRol(nombre, _descripcion.text.trim(), _permisos.toList())
        : await ApiClient.actualizarRol(
            widget.rolNombre!, nombre, _descripcion.text.trim(), _permisos.toList());
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    if (r.ok) Navigator.of(context).pop();
  }

  // Group catalog by modulo.
  Map<String, List<Map<String, dynamic>>> get _porModulo {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final p in widget.catalogo) {
      final m = (p['modulo'] ?? 'Otros').toString();
      map.putIfAbsent(m, () => []).add(p);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esNuevo ? 'Nuevo rol' : 'Editar rol')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nombre,
            decoration: const InputDecoration(labelText: 'Nombre del rol', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descripcion,
            decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
          ),
          const Divider(height: 32),
          Text('Permisos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final entry in _porModulo.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final p in entry.value)
              CheckboxListTile(
                dense: true,
                title: Text(p['label'].toString()),
                value: _permisos.contains(p['key']),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _permisos.add(p['key'].toString());
                    } else {
                      _permisos.remove(p['key'].toString());
                    }
                  });
                },
              ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _guardar,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_esNuevo ? 'Crear rol' : 'Guardar cambios'),
          ),
        ],
      ),
    );
  }
}