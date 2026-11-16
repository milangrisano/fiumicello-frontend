import 'package:flutter/material.dart';
import '../../core/data/api_client.dart';

/// Superadmin/Admin screen: manage roles and their permissions dynamically.
///
/// Lists roles, lets you create new ones, rename them, and toggle which
/// permissions each role has. Permissions are presented as a 3-level tree
/// (Botón del sidebar → Pestaña → CRUD por servicio), fetched from the
/// hierarchical catalog endpoint.
class RolesPermisosView extends StatefulWidget {
  const RolesPermisosView({super.key});

  @override
  State<RolesPermisosView> createState() => _RolesPermisosViewState();
}

class _RolesPermisosViewState extends State<RolesPermisosView> {
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _catalogo = []; // jerárquico (3 niveles)
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
    final c = await ApiClient.catalogoArbol();
    if (!mounted) return;
    setState(() {
      _roles = r.ok ? r.list.cast<Map<String, dynamic>>() : [];
      _catalogo = c.ok ? c.list.cast<Map<String, dynamic>>() : [];
      _loading = false;
      if (!r.ok) _error = r.message;
      if (!c.ok) _error = c.message;
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
        const Text('Configura qué puede ver y hacer cada rol por botón, pestaña y servicio.',
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

/// Editor for a single role: name, description, and permission toggles shown
/// as a 3-LEVEL TREE (Botón → Pestaña → Servicio/CRUD).
class _RoleEditView extends StatefulWidget {
  final List<Map<String, dynamic>> catalogo; // jerárquico
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

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
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
          const SizedBox(height: 4),
          const Text('Abre cada botón para asignar pestañas y qué puede hacer el rol por servicio.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          // Árbol de 3 niveles: Botón → Pestaña → Servicio/CRUD
          for (final boton in widget.catalogo) _arbolBoton(context, boton),
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

  // ---------- Nivel 1: Botón del sidebar ----------
  Widget _arbolBoton(BuildContext context, Map<String, dynamic> boton) {
    final nivel1 = (boton['nivel1'] ?? '').toString();
    final pestanas = (boton['pestañas'] as List? ?? const []).cast<Map<String, dynamic>>();
    final todas = _permisosDeNivel(pestanas);
    final marcadas = todas.where((p) => _permisos.contains(p)).length;
    final completo = todas.isNotEmpty && marcadas == todas.length;
    final parcial = marcadas > 0 && !completo;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        leading: _iconoEstado(completo, parcial),
        title: Text(nivel1, style: const TextStyle(fontWeight: FontWeight.w700)),
        children: [
          for (final pestana in pestanas) _arbolPestana(context, pestana),
        ],
      ),
    );
  }

  List<String> _permisosDeNivel(List<Map<String, dynamic>> lista) {
    final out = <String>[];
    for (final item in lista) {
      for (final s in ((item['servicios'] ?? const []) as List).cast<Map<String, dynamic>>()) {
        for (final c in ((s['crud'] ?? const []) as List).cast<Map<String, dynamic>>()) {
          final p = c['permiso']?.toString();
          if (p != null && p.isNotEmpty) out.add(p);
        }
      }
    }
    return out;
  }

  // ---------- Nivel 2: Pestaña ----------
  Widget _arbolPestana(BuildContext context, Map<String, dynamic> pestana) {
    final nombre = (pestana['pestana'] ?? '').toString();
    final servicios =
        (pestana['servicios'] as List? ?? const []).cast<Map<String, dynamic>>();
    final todas = _permisosDeServicios(servicios);
    final marcadas = todas.where((p) => _permisos.contains(p)).length;
    final completo = todas.isNotEmpty && marcadas == todas.length;
    final parcial = marcadas > 0 && !completo;

    return ExpansionTile(
      shape: const Border(),
      leading: _iconoEstado(completo, parcial),
      title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text('Pestaña'),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final servicio in servicios) _arbolServicio(context, servicio),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _permisosDeServicios(List<Map<String, dynamic>> servicios) {
    final out = <String>[];
    for (final s in servicios) {
      for (final c in ((s['crud'] ?? const []) as List).cast<Map<String, dynamic>>()) {
        final p = c['permiso']?.toString();
        if (p != null && p.isNotEmpty) out.add(p);
      }
    }
    return out;
  }

  // ---------- Nivel 3: Servicio con su CRUD ----------
  Widget _arbolServicio(BuildContext context, Map<String, dynamic> servicio) {
    final nombre = (servicio['servicio'] ?? '').toString();
    final crud = (servicio['crud'] as List? ?? const []).cast<Map<String, dynamic>>();
    final todas = crud.map((c) => c['permiso'].toString()).toList();
    final marcadas = todas.where((p) => _permisos.contains(p)).length;
    final completo = todas.isNotEmpty && marcadas == todas.length;
    final parcial = marcadas > 0 && !completo;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ExpansionTile(
        shape: const Border(),
        leading: _iconoEstado(completo, parcial),
        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Servicio'),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in crud) _crudCheckbox(context, c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconoEstado(bool completo, bool parcial) {
    final color = completo ? Colors.green : (parcial ? Colors.orange : null);
    return Icon(
      completo ? Icons.check_box : (parcial ? Icons.indeterminate_check_box : Icons.check_box_outline_blank),
      color: color,
    );
  }

  // ---------- Casilla CRUD (permiso individual) ----------
  Widget _crudCheckbox(BuildContext context, Map<String, dynamic> crudDef) {
    final permiso = (crudDef['permiso'] ?? '').toString();
    final etiqueta = (crudDef['etiqueta'] ?? '').toString();
    final marcado = _permisos.contains(permiso);
    final esSoft = permiso.contains(':eliminar');
    return CheckboxListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 8),
      secondary: esSoft
          ? const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 20)
          : null,
      title: Text(
        etiqueta,
        style: TextStyle(
            fontSize: 13,
            fontWeight: esSoft ? FontWeight.w600 : FontWeight.w400,
            color: esSoft ? Colors.redAccent : null),
      ),
      value: marcado,
      onChanged: (v) {
        setState(() {
          if (v == true) {
            _permisos.add(permiso);
          } else {
            _permisos.remove(permiso);
          }
        });
      },
    );
  }
}
