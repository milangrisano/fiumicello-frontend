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
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  Future<void> _go(BuildContext context) async {
    // If logged in, go to the app; otherwise to login.
    await ApiClient.restoreSession();
    if (context.mounted) {
      Navigator.of(context)
          .pushReplacementNamed(ApiClient.isLoggedIn ? '/app' : '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _go(context),
        icon: const Icon(Icons.login),
        label: const Text('Ingresar'),
      ),
      body: const SafeArea(child: CartaView()),
    );
  }
}