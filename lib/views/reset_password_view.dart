import 'package:flutter/material.dart';
import '../core/data/api_client.dart';

/// Password recovery — confirm step. User lands here with the reset token
/// (received in the link from the email) and sets a new password.
class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pass.text != _confirm.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    setState(() { _loading = true; _error = null; _message = null; });
    final r = await ApiClient.resetPassword(
      _email.text.trim(), _token.text.trim(), _pass.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _message = 'Contraseña restablecida. Ahora puedes iniciar sesión.';
      } else {
        _error = r.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva contraseña')),
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
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email', prefixIcon: Icon(Icons.mail_outline),
                    border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _token,
                  decoration: const InputDecoration(
                    labelText: 'Token de recuperación', prefixIcon: Icon(Icons.vpn_key_outlined),
                    border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
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
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(_message!, style: const TextStyle(color: Colors.teal)),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Volver a iniciar sesión'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar nueva contraseña'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}