import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app.dart';

void main() {
  // Clean path-based routing (e.g. /login, /register, /app) instead of #/...
  usePathUrlStrategy();
  runApp(const FiumicelloApp());
}