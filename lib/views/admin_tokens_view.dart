import 'package:flutter/material.dart';
import '../core/data/api_client.dart';

/// Superadmin admin panel: manage service tokens (herb and future services)
/// and approve pending user registrations.
///
/// Only reachable for the superadmin role.
class AdminTokensView extends StatefulWidget {
  const AdminTokensView({super.key});

  @override
  State<AdminTokensView> createState() => _AdminTokensViewState();
}

class _AdminTokensViewState extends State<AdminTokensView> {
  final _nombre = TextEditingController();
  List<Map<String, dynamic>> _servicios = [];
  List<Map<String, dynamic>> _pendientes = [];
  bool _loading = true;
  String? _newToken; // shown once after generation

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; });
    final s = await ApiClient.listServicios();
    final p = await ApiClient.listPendientes();
    if (!mounted) return;
    setState(() {
      _servicios = s.ok ? s.list.cast<Map<String, dynamic>>() : [];
      _pendientes = p.ok ? p.list.cast<Map<String, dynamic>>() : [];
      _loading = false;
    });
  }

  Future<void> _generar() async {
    if (_nombre.text.trim().isEmpty) return;
    final r = await ApiClient.generarServicio(_nombre.text.trim());
    if (!mounted) return;
    setState(() {
      if (r.ok) {
        _newToken = r.data?['token'];
        _nombre.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
      }
    });
    _load();
  }

  Future<void> _revocar(int id) async {
    final r = await ApiClient.revocarServicio(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    _load();
  }

  Future<void> _aprobar(int id) async {
    final r = await ApiClient.aprobar(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Generate a new service token (shown once) ----
        const Text('Tokens de servicio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nombre,
                decoration: const InputDecoration(
                  labelText: 'Nombre del servicio (ej. herb)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _generar, child: const Text('Generar')),
          ],
        ),
        if (_newToken != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.amber.shade50,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('NUEVO TOKEN (cópialo ahora — no volverá a mostrarse):',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              SelectableText(_newToken!, style: const TextStyle(fontFamily: 'monospace')),
            ]),
          ),
        ],

        const SizedBox(height: 20),
        ..._servicios.map((s) => ListTile(
              dense: true,
              leading: const Icon(Icons.vpn_key),
              title: Text(s['nombre'] ?? 'servicio'),
              subtitle: Text('id ${s['id']} · creado ${s['creado'] ?? '-'}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _revocar(s['id']),
                tooltip: 'Revocar token',
              ),
            )),
        if (_servicios.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('No hay tokens de servicio.', style: TextStyle(color: Colors.grey)),
          ),

        const Divider(height: 32),
        const Text('Registros pendientes de aprobación',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (_pendientes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('No hay registros pendientes.', style: TextStyle(color: Colors.grey)),
          ),
        ..._pendientes.map((u) => ListTile(
              dense: true,
              leading: const Icon(Icons.person_outline),
              title: Text(u['email'] ?? '-'),
              subtitle: Text('rol ${u['rol']}'),
              trailing: IconButton(
                icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                onPressed: () => _aprobar(u['id']),
                tooltip: 'Aprobar',
              ),
            )),
      ],
    );
  }
}