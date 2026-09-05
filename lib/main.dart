import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app.dart';

void main() {
  // Use clean path-based routing (e.g. /reset?token=...) instead of #/...
  usePathUrlStrategy();
  runApp(const FiumicelloApp());
}