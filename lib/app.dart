import 'package:flutter/material.dart';
import 'navigation/app_shell.dart';

/// Root widget: MaterialApp with the app theme and the top-level shell.
class FiumicelloApp extends StatelessWidget {
  const FiumicelloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fiumicello',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF0969DA), useMaterial3: true),
      home: const AppShell(),
    );
  }
}