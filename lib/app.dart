import 'package:flutter/material.dart';
import 'core/data/api_client.dart';
import 'navigation/app_shell.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';

/// Root widget. Clean, explicit named routes. Every screen maps to one route.
/// Password recovery lives inside the app (ForgotPasswordView) as a same-pattern
/// flow (email -> code -> new password); there is no external /reset link.
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
        '/': (_) => const SessionGate(),
        '/login': (_) => const LoginView(),
        '/register': (_) => const RegisterView(),
        '/app': (_) => const AppShell(),
      },
      onGenerateRoute: (settings) {
        // Unknown route -> login.
        return MaterialPageRoute(builder: (_) => const LoginView());
      },
    );
  }
}

/// Decides the first screen: app if logged in, otherwise login.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
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