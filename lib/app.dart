import 'package:flutter/material.dart';
import 'core/data/api_client.dart';
import 'navigation/app_shell.dart';
import 'views/login_view.dart';
import 'views/reset_password_view.dart';

/// Extracts [k] from the URL query OR from the hash fragment (Flutter web
/// puts route+query after `#`). This lets a reset link like
///   /#/?token=X&email=a@b.com
/// be read even though `Uri.base.queryParameters` doesn't parse hash queries.
Map<String, String> _urlParams() {
  final out = <String, String>{};
  final base = Uri.base;
  base.queryParameters.forEach((k, v) => out[k] = v);
  // Parse the fragment (after '#') for key=value pairs too.
  final frag = base.fragment; // e.g. "/?token=X&email=a@b.com" or "/reset?x=1"
  if (frag.contains('?')) {
    final qs = frag.split('?').last;
    for (final pair in qs.split('&')) {
      if (pair.contains('=')) {
        final parts = pair.split('=');
        if (parts.length == 2) out[parts[0]] = Uri.decodeQueryComponent(parts[1]);
      }
    }
  }
  return out;
}

/// Root widget: MaterialApp with the app theme, login gate and top-level shell.
class FiumicelloApp extends StatelessWidget {
  const FiumicelloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fiumicello',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF0969DA), useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/': (_) => const _SessionGate(),
        '/login': (_) => const LoginView(),
        '/app': (_) => const AppShell(),
      },
      onGenerateRoute: (settings) {
        final params = _urlParams();
        final token = params['token'];
        final email = params['email'];
        if (settings.name == '/reset' &&
            token != null && token.isNotEmpty &&
            email != null && email.isNotEmpty) {
          return MaterialPageRoute(builder: (_) => ResetPasswordView(email: email, token: token));
        }
        final widget = _routeWidget(settings.name);
        return MaterialPageRoute(builder: (_) => widget);
      },
    );
  }

  Widget _routeWidget(String? name) {
    switch (name) {
      case '/login':
        return const LoginView();
      case '/app':
        return const AppShell();
      default:
        return const _SessionGate();
    }
  }
}

/// Decides the first screen: login if no stored session, otherwise the app.
class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    // If the URL carries a password-reset token, go there instead of login/app.
    final params = _urlParams();
    final token = params['token'];
    final email = params['email'];
    if (token != null && token.isNotEmpty && email != null && email.isNotEmpty) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/reset', (_) => false);
      return;
    }
    await ApiClient.restoreSession();
    if (!mounted) return;
    final logged = ApiClient.isLoggedIn;
    Navigator.of(context).pushReplacementNamed(logged ? '/app' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}