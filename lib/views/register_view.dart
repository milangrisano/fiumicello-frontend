import 'package:flutter/material.dart';
import '../core/data/api_client.dart';

/// Registration: a single page that advances through 3 discreet steps:
/// Email -> Code (sent to the email) -> Password.
///
/// Subtle by design: no loud announcement, just a small flow. Success leaves
/// the user in "pendiente de aprobación" (superadmin approval).
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  int _step = 1;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    setState(() { _loading = true; _error = null; _info = null; });
    final r = await ApiClient.register(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _step = 2;
        _info = 'Te enviamos un código a ${_email.text.trim()}';
      } else {
        _error = r.message;
      }
    });
  }

  Future<void> _verifyAndSet() async {
    setState(() { _loading = true; _error = null; _info = null; });
    if (_pass.text != _confirm.text) {
      setState(() { _loading = false; _error = 'Las contraseñas no coinciden.'; });
      return;
    }
    final r = await ApiClient.verify(_email.text.trim(), _code.text.trim(), _pass.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _info = 'Cuenta creada. Queda pendiente de aprobación.';
        // stay on step 3 with a done message
      } else {
        _error = r.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Registro', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Paso $_step de 3 · Email, código y contraseña',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),

                if (_info != null) ...[
                  Text(_info!, style: const TextStyle(color: Colors.teal)),
                  const SizedBox(height: 16),
                ],

                if (_step == 1) ...[
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _requestCode,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Continuar'),
                  ),
                ],

                if (_step == 2) ...[
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Código (6 dígitos)',
                      prefixIcon: Icon(Icons.pin),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : () => setState(() => _step = 3),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Siguiente'),
                  ),
                ],

                if (_step == 3) ...[
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _verifyAndSet,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Crear cuenta'),
                  ),
                ],

                if (_step == 3 && _info != null && _error == null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Volver a iniciar sesión'),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}