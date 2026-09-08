import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app.dart';

void main() {
  // Clean path-based routing (e.g. /login, /register, /app) instead of #/...
  usePathUrlStrategy();
  // Show build/render errors on screen (red panel with the message) instead of
  // a silent grey/blank area. Helps diagnose runtime layout exceptions.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.red.shade50,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
              'ERROR DE RENDER:\n${details.exception}',
              style: TextStyle(color: Colors.red.shade900, fontSize: 13),
            ),
        ),
      ),
    );
  };
  runApp(const FiumicelloApp());
}