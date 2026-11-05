import 'package:flutter/material.dart';
import '../core/data/api_client.dart';
import '../core/app_version.dart';
import 'register_view.dart';
import 'forgot_password_view.dart';

/// Login screen. The identifier is the user's email. Registration and password
/// recovery are deliberately subtle — small text links at the bottom.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _showPass = false; // toggle mostrar/ocultar contraseña
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final ok = await ApiClient.login(_user.text.trim(), _pass.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacementNamed('/app');
    } else {
      setState(() { _loading = false; _error = 'Email o contraseña incorrectos.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _PieVersiones(),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo de Fiumicello (imagen con gorro + nombre), según tema.
                // Reemplaza el icono genérico + texto de antes conservando el
                // ancho/centrado del bloque (maxWidth 380).
                Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/logo_fiumicello_blanco.png'
                      : 'assets/logo_fiumicello.png',
                  width: 200,
                  fit: BoxFit.fitWidth,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Inicia sesión para continuar',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 28),
                AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _user,
                        keyboardType: TextInputType.emailAddress,
                        // Hace que el navegador ofrezca el email guardado en las
                        // credenciales (sin esto solo detecta la contraseña).
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _pass,
                        obscureText: !_showPass,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      // Icono del ojo siempre visible (mismo color del texto/hint),
                      // no solo al pasar el mouse.
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showPass = !_showPass),
                      tooltip: _showPass ? 'Ocultar contraseña' : 'Mostrar contraseña',
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                    ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Entrar'),
                ),
                const SizedBox(height: 12),
                // Subtle ancillary links
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterView())),
                      child: const Text('Crear cuenta'),
                    ),
                    const Text('·'),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ForgotPasswordView())),
                      child: const Text('Recuperar contraseña'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pie del login: muestra la versión del FRONTEND y la del BACKEND (leída del
/// endpoint público /health) para poder verificar que ambos coinciden y que no
/// haya un backend viejo desplegado. Si no coinciden, se marca en rojo.
class _PieVersiones extends StatefulWidget {
  const _PieVersiones();
  @override
  State<_PieVersiones> createState() => _PieVersionesState();
}

class _PieVersionesState extends State<_PieVersiones> {
  String? _back;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final v = await ApiClient.leerBackendVersion();
    if (mounted) setState(() => _back = v);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final back = _back;
    final coincide = back != null && back.isNotEmpty && back == APP_VERSION;
    final color = coincide
        ? Colors.grey
        : (back == null ? Colors.grey : scheme.error);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Versión frontend: v$APP_VERSION',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(
          back == null
              ? 'Versión backend: —'
              : 'Versión backend: v$back${coincide ? '' : '  ⚠ no coincide'}',
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 12, fontWeight: coincide ? FontWeight.normal : FontWeight.bold),
        ),
      ],
    );
  }
}