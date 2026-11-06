import 'package:flutter/material.dart';
import '../core/data/api_client.dart';

/// Vista dedicada para que el usuario logueado cambie su contraseña.
/// Se llega desde el menú del gorro (PerfilMenu). Al éxito vuelve atrás con
/// confirmación; los errores se muestran en rojo dentro del formulario.
class CambiarContrasenaView extends StatefulWidget {
  const CambiarContrasenaView({super.key});

  @override
  State<CambiarContrasenaView> createState() => _CambiarContrasenaViewState();
}

class _CambiarContrasenaViewState extends State<CambiarContrasenaView> {
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();
  String? _error;
  bool _guardando = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Nueva contraseña',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Debe tener al menos 6 caracteres.',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _actual,
                      obscureText: true,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña actual',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nueva,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nueva contraseña (mín. 6)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmar,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar nueva contraseña',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _guardando ? null : _cambiar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.lock, size: 18),
                      label: const Text('Cambiar contraseña'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cambiar() async {
    final a = _actual.text;
    final n = _nueva.text;
    final c = _confirmar.text;
    if (n.length < 6) {
      setState(() => _error = 'La nueva contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (n != c) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    setState(() {
      _error = null;
      _guardando = true;
    });
    final r = await ApiClient.cambiarContrasena(a, n);
    if (!mounted) return;
    setState(() => _guardando = false);
    if (r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
      Navigator.of(context).pop();
    } else {
      setState(() => _error = r.message);
    }
  }
}