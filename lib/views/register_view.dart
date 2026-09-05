import 'package:flutter/material.dart';
import '../core/data/api_client.dart';

/// Registration: a single page that advances through 3 discreet steps:
/// Email -> Code (sent to the email) -> Password.
///
/// Subtle by design: no loud announcement, just a small flow. The code from
/// step 2 is validated against the backend before moving on. On success the
/// account stays "pendiente de aprobación" until a superadmin approves it.
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
  bool _pendingDone = false;
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

  Future<void> _verifyCode() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiClient.verifyCode(_email.text.trim(), _code.text.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _step = 3;
      } else {
        _error = r.message;
      }
    });
  }

  Future<void> _createAccount() async {
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
        _pendingDone = true;
        _info = 'Cuenta creada. Queda pendiente de aprobación.';
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
                if (!_pendingDone) ...[
                  Text('Paso $_step de 3 · Email, código y contraseña',
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                ] else
                  const SizedBox(height: 16),

                if (_pendingDone) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_top, color: Colors.teal),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Tu cuenta quedó pendiente de aprobación. '
                            'Te avisaremos cuando sea aprobada.',
                            style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (!_pendingDone && _info != null) ...[
                  Text(_info!, style: const TextStyle(color: Colors.teal)),
                  const SizedBox(height: 16),
                ],

                if (_step == 1 && !_pendingDone) ...[
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

                if (_step == 2 && !_pendingDone) ...[
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
                    onPressed: _loading ? null : _verifyCode,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Verificar código'),
                  ),
                ],

                if (_step == 3 && !_pendingDone) ...[
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
                    onPressed: _loading ? null : _createAccount,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Crear cuenta'),
                  ),
                ],

                if (_pendingDone) ...[
                  const SizedBox(height: 8),
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