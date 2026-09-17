import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controla el tema de la app (light/dark/sistema) y lo persiste.
///
/// - Por defecto sigue al sistema (ThemeMode.system): dark si el equipo está
///   en dark, light si está en light.
/// - El toggle permite forzar light o dark; queda guardado para la próxima vez.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _key = 'theme_mode'; // 'system' | 'light' | 'dark'
  ThemeMode _mode = ThemeMode.system;
  bool _loaded = false;

  ThemeMode get mode => _mode;
  bool get isLoaded => _loaded;

  bool get isDark => _mode == ThemeMode.dark;

  /// Carga la preferencia guardada (o system por defecto).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      _mode = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      _mode = ThemeMode.system;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Fuerza un modo concreto (para el toggle).
  Future<void> setMode(ThemeMode m) async {
    _mode = m;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });
    } catch (_) {/* la preferencia no es crítica */}
  }

  /// Alterna light <-> dark (desde el toggle del sidebar).
  Future<void> toggle() => setMode(isDark ? ThemeMode.light : ThemeMode.dark);
}
