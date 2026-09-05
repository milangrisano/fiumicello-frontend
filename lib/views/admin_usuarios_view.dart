import 'package:flutter/material.dart';
import '../core/data/api_client.dart';

/// Superadmin/Admin screen: manage users and their roles.
///
/// Hierarchical:
/// - SuperAdmin sees/manages everyone (including admins), can assign any role.
/// - Admin sees operational users only (not superadmin), assigns operational roles.
class UsuariosView extends StatefulWidget {
  const UsuariosView({super.key});

  @override
  State<UsuariosView> createState() => _UsuariosViewState();
}

class _UsuariosViewState extends State<UsuariosView> {
  List<Map<String, dynamic>> _usuarios = [];
  bool _loading = true;
  String? _error;

  // Roles a non-superadmin (admin) can assign.
  static const _rolesOperativos = ['encargado', 'cajero', 'cocinero', 'mesero', 'ayudante'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiClient.listUsuarios();
    if (!mounted) return;
    setState(() {
      _usuarios = r.ok ? r.list.cast<Map<String, dynamic>>() : [];
      _loading = false;
      if (!r.ok) _error = r.message;
    });
  }

  bool get _esSuper => ApiClient.isSuperadmin;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Usuarios', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Text('${_usuarios.length} usuarios', style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            children: [
              for (final u in _usuarios)
                if (_esSuper || (u['rol'] != 'superadmin')) _usuarioCard(u),
            ],
          ),
        ),
      ],
    );
  }

  Widget _usuarioCard(Map<String, dynamic> u) {
    final email = u['email'] ?? '(servicio: ${u['nombre_servicio'] ?? '?'})';
    final rol = u['rol'] ?? '—';
    final esSuperUsuario = rol == 'superadmin';
    return ListTile(
      leading: esSuperUsuario ? const Icon(Icons.shield) : const Icon(Icons.person_outline),
      title: Text(email),
      subtitle: Text('Rol: $rol · ${u['estado'] ?? ''}'),
      trailing: _esSuper || !esSuperUsuario
          ? IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Cambiar rol',
              onPressed: () => _asignarRol(u),
            )
          : null,
    );
  }

  Future<void> _asignarRol(Map<String, dynamic> u) async {
    final id = u['id'];
    final options = _esSuper
        ? ['encargado', 'cajero', 'cocinero', 'mesero', 'ayudante', 'admin']
        : _rolesOperativos;
    final actual = (u['rol'] ?? '') as String;
    final seleccion = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Cambiar rol de ${u['email'] ?? id}'),
        children: [
          for (final r in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: Row(
                children: [
                  Icon(r == actual ? Icons.radio_button_checked : Icons.radio_button_off, size: 18),
                  const SizedBox(width: 8),
                  Text(r),
                ],
              ),
            ),
        ],
      ),
    );
    if (seleccion == null || seleccion == actual) return;
    final res = await ApiClient.asignarRolUsuario(id as int, seleccion);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    _load();
  }
}