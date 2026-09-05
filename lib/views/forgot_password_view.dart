import 'package:flutter/material.dart';
import '../core/data/api_client.dart';
import '../widgets/otp_input.dart';

/// Password recovery — follows the SAME pattern as registration:
/// Email -> Code (6 digits sent to the email) -> New password.
///
/// Everything is internal to the app (no external link / fragile routing).
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  final _otpKey = GlobalKey<OtpInputState>();
  int _step = 1;
  bool _loading = false;
  bool _done = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    setState(() { _loading = true; _error = null; _info = null; });
    final r = await ApiClient.forgotPassword(_email.text.trim());
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

  Future<void> _reset() async {
    final code = _otpKey.currentState?.value ?? '';
    if (code.length != 6) {
      setState(() => _error = 'Introduce el código de 6 dígitos.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    if (_pass.text != _confirm.text) {
      setState(() { _loading = false; _error = 'Las contraseñas no coinciden.'; });
      return;
    }
    final r = await ApiClient.resetPassword(
      _email.text.trim(), code, _pass.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _done = true;
        _info = 'Contraseña restablecida. Ahora puedes iniciar sesión.';
      } else {
        _error = r.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Restablecer contraseña', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (!_done)
                  Text('Paso $_step de 3 · Email, código y contraseña',
                      style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),

                if (_info != null) ...[
                  Text(_info!, style: const TextStyle(color: Colors.teal)),
                  const SizedBox(height: 16),
                ],

                if (_step == 1 && !_done) ...[
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email', prefixIcon: Icon(Icons.mail_outline),
                      border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _requestCode,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Enviar código'),
                  ),
                ],

                if (_step == 2 && !_done) ...[
                  OtpInput(key: _otpKey, onChanged: (_) {}),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : () => setState(() => _step = 3),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Siguiente'),
                  ),
                ],

                if (_step == 3 && !_done) ...[
                  TextField(
                    controller: _pass, obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nueva contraseña', prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirm, obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña', prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _reset,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Guardar nueva contraseña'),
                  ),
                ],

                if (_done) ...[
                  FilledButton(
                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false),
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