import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app.dart';

/// Captured once at startup, before Flutter can rewrite the URL.
/// Holds query params from a password-reset link (e.g. /reset?token=X&email=Y).
final Map<String, String> initialUrlParams = () {
  final out = <String, String>{};
  final base = Uri.base;
  base.queryParameters.forEach((k, v) => out[k] = v);
  final frag = base.fragment;
  if (frag.contains('?')) {
    final qs = frag.split('?').last;
    for (final pair in qs.split('&')) {
      if (pair.contains('=')) {
        final parts = pair.split('=');
        if (parts.length == 2) out[parts[0]] = Uri.decodeQueryComponent(parts[1]);
      }
    }
  }
  return out;
}();

void main() {
  // Use clean path-based routing (e.g. /reset?token=...) instead of #/...
  usePathUrlStrategy();
  runApp(const FiumicelloApp());
}