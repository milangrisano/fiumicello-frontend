import 'package:flutter/material.dart';
import 'core/data/api_client.dart';
import 'navigation/app_shell.dart';
import 'views/login_view.dart';

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
    );
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