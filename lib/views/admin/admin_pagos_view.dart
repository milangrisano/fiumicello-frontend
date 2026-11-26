import 'package:flutter/material.dart';
import '../../core/data/api_client.dart';

/// SuperAdmin/Admin panel: payment methods catalog management.
/// Persistence rule: a method is never deleted — it's activated/disabled
/// (`activo`). Disabled methods are not shown in the POS payment dialog.
class PagosView extends StatefulWidget {
  const PagosView({super.key});

  @override
  State<PagosView> createState() => _PagosViewState();
}

class _PagosViewState extends State<PagosView> {
  List<Map<String, dynamic>> _formas = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiClient.listarFormasPago();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _formas = r.list.cast<Map<String, dynamic>>();
      } else {
        _error = r.message;
      }
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<String?> _dialogTexto(String titulo, {String inicial = '', String hint = ''}) async {
    final c = TextEditingController(text: inicial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder(), isDense: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Guardar')),
        ],
      ),
    );
  }

  Future<void> _crear() async {
    final nombre = await _dialogTexto('Nueva forma de pago', hint: 'Ej. Nequi, Tarjeta, Efectivo');
    if (nombre == null || nombre.trim().isEmpty) return;
    final r = await ApiClient.crearFormaPago(nombre.trim());
    // El endpoint devuelve la entidad (sin message) en éxito: no mostrar el
    // genérico "No se pudo completar la operación" en un caso exitoso.
    _snack(r.ok ? 'Forma de pago creada.' : r.message);
    await _load();
  }

  Future<void> _editar(Map<String, dynamic> f) async {
    final nombre = await _dialogTexto('Editar forma de pago', inicial: f['nombre'] ?? '');
    if (nombre == null || nombre.trim().isEmpty) return;
    final r = await ApiClient.actualizarFormaPago(f['id'] as int, nombre.trim());
    _snack(r.ok ? 'Forma de pago actualizada.' : r.message);
    await _load();
  }

  Future<void> _toggleActivo(Map<String, dynamic> f) async {
    final nuevo = !((f['activo'] ?? true) as bool);
    final r = await ApiClient.actualizarFormaPago(
      f['id'] as int,
      f['nombre'] ?? '',
      activo: nuevo,
    );
    _snack(nuevo ? 'Forma de pago activada.' : 'Forma de pago desactivada.');
    await _load();
  }

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
              Text('Métodos de pago', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Nuevo método'),
                onPressed: _crear,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _formas.isEmpty
              ? const Center(child: Text('No hay métodos de pago registrados.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _formas.length,
                  itemBuilder: (context, i) {
                    final f = _formas[i];
                    final activo = (f['activo'] ?? true) as bool;
                    final esEfectivo =
                        (f['nombre'] ?? '').toString().toLowerCase() == 'efectivo';
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          activo ? Icons.check_circle : Icons.block,
                          color: activo ? Colors.green : Colors.grey,
                        ),
                        title: Text(
                          f['nombre'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: activo ? null : Colors.grey,
                          ),
                        ),
                        subtitle: Text(activo ? 'Activo' : 'Desactivado'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Editar nombre',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editar(f),
                            ),
                            if (!esEfectivo)
                              Switch(
                                value: activo,
                                onChanged: (_) => _toggleActivo(f),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
