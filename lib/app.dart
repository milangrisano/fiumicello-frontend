import 'package:flutter/material.dart';
import 'core/data/api_client.dart';
import 'navigation/app_shell.dart';
import 'views/login_view.dart';
import 'views/reset_password_view.dart';

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
        // A password-reset link arrives via the URL query/hash, e.g.
        //   /#/reset?token=XYZ&email=a@b.com
        final uri = Uri.base;
        final token = uri.queryParameters['token'];
        final email = uri.queryParameters['email'];
        if (settings.name == '/reset' &&
            token != null &&
            token.isNotEmpty &&
            email != null &&
            email.isNotEmpty) {
          return MaterialPageRoute(
            builder: (_) => ResetPasswordView(email: email, token: token),
          );
        }
        // Fall back to default routes.
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
    final uri = Uri.base;
    final token = uri.queryParameters['token'];
    final email = uri.queryParameters['email'];
    if (token != null && token.isNotEmpty && email != null && email.isNotEmpty) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/reset',
        (_) => false,
        arguments: null,
      );
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