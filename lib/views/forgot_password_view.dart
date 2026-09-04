import 'package:flutter/material.dart';
import '../core/data/api_client.dart';

/// Password recovery — request step. Subtle: only asks email and shows a
/// generic "if the email exists we sent you a link" (no user enumeration).
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _email = TextEditingController();
  bool _loading = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; _message = null; });
    final r = await ApiClient.forgotPassword(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _message = 'Si el email existe, recibirás un enlace de recuperación.';
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
                Text('Ingresa tu email', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Te enviaremos un enlace para restablecer tu contraseña.',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(_message!, style: const TextStyle(color: Colors.teal)),
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
                      : const Text('Enviar enlace'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}