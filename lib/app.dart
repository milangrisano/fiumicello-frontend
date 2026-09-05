import 'package:flutter/material.dart';
import 'core/data/api_client.dart';
import 'navigation/app_shell.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';
import 'views/reset_password_view.dart';
import 'main.dart' show initialUrlParams;

/// A single view that decides at startup whether the user should land on the
/// app or the login. It is the default widget for `/` but does NOT intercept
/// the /reset route (which is handled explicitly by onGenerateRoute).
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

/// Root widget. Each screen maps to an explicit, clean route:
///   /         -> session gate (forwards to /app or /login)
///   /login    -> LoginView
///   /register -> RegisterView
///   /reset    -> ResetPasswordView (reads token & email from query params)
///   /app      -> AppShell
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
        // /reset?token=X&email=Y -> ResetPasswordView with pre-filled account.
        if (settings.name == '/reset') {
          final token = initialUrlParams['token'];
          final email = initialUrlParams['email'];
          if (token != null && token.isNotEmpty && email != null && email.isNotEmpty) {
            return MaterialPageRoute(
              builder: (_) => ResetPasswordView(email: email, token: token),
            );
          }
          // Missing/invalid params: fall back to login.
          return MaterialPageRoute(builder: (_) => const LoginView());
        }
        // Any other unknown route -> login.
        return MaterialPageRoute(builder: (_) => const LoginView());
      },
    );
  }
}