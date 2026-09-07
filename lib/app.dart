import 'package:flutter/material.dart';
import 'core/data/api_client.dart';
import 'navigation/app_shell.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';
import 'views/carta_view.dart';

/// Root widget. Clean, explicit named routes.
///   /         -> public carte (CartaView) — the restaurant menu
///   /login    -> LoginView
///   /register -> RegisterView
///   /app      -> AppShell (authenticated)
///
/// The public root shows the menu; a login/FAB lets a user go into the app.
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
        '/': (_) => const HomeView(),
        '/login': (_) => const LoginView(),
        '/register': (_) => const RegisterView(),
        '/app': (_) => const AppShell(),
      },
      onGenerateRoute: (settings) {
        // Unknown route -> home (public carte).
        return MaterialPageRoute(builder: (_) => const HomeView());
      },
    );
  }
}

/// The public root: shows the carte. Offers access to login / the app.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await ApiClient.restoreSession();
    if (mounted) {
      setState(() => _logged = ApiClient.isLoggedIn);
    }
  }

  Future<void> _go(BuildContext context) async {
    await ApiClient.restoreSession();
    if (context.mounted) {
      Navigator.of(context)
          .pushReplacementNamed(ApiClient.isLoggedIn ? '/app' : '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // In the public home, a small top-right action (not a floating overlay over
    // the menu content) to enter: 'Ingresar' if not logged, 'Ir a la app' if so.
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _go(context),
              icon: Icon(_logged ? Icons.dashboard : Icons.login, size: 18),
              label: Text(_logged ? 'Ir a la app' : 'Ingresar'),
            ),
          ),
        ],
      ),
      body: const SafeArea(child: CartaView()),
    );
  }
}