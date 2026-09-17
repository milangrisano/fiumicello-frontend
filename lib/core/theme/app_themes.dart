import 'package:flutter/material.dart';

/// Paletas de la app Fiumicello — dos temas completos.
///
/// LIGHT "Tierra Volcánica": fondo blanco roto, tarjetas crema, acento
/// terracotta/dorado, texto negro volcánico.
///
/// DARK "Calidez Mediterránea": fondo azul profundo, tarjetas negro volcánico,
/// acento turquesa/dorado, texto amarillo pálido/blanco.
class AppPalette {
  AppPalette._();

  // ---- Tierra Volcánica (LIGHT) ----
  static const lightBackground = Color(0xFFF8F5F0); // blanco roto
  static const lightCard = Color(0xFFF5EBDD); // crema
  static const lightPrimary = Color(0xFFC65D3B); // terracotta
  static const lightSecondary = Color(0xFFC9A227); // dorado
  static const lightOnSurface = Color(0xFF2B2620); // negro volcánico
  static const lightOnSurfaceVariant = Color(0xFF9C948F); // gris piedra

  // ---- Calidez Mediterránea (DARK) ----
  static const darkBackground = Color(0xFF0E2A3A); // azul profundo
  static const darkCard = Color(0xFF2B2620); // negro volcánico
  static const darkPrimary = Color(0xFF2FB9A6); // turquesa
  static const darkSecondary = Color(0xFFC9A227); // dorado
  static const darkOnSurface = Color(0xFFF0D9A6); // amarillo pálido
  static const darkOnSurfaceVariant = Color(0xFFFFFFFF); // blanco
}

/// Tema LIGHT "Tierra Volcánica".
ThemeData buildLightTheme() {
  final scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.lightPrimary,
    onPrimary: AppPalette.lightBackground,
    primaryContainer: AppPalette.lightCard,
    onPrimaryContainer: AppPalette.lightOnSurface,
    secondary: AppPalette.lightSecondary,
    onSecondary: AppPalette.lightBackground,
    secondaryContainer: AppPalette.lightCard,
    onSecondaryContainer: AppPalette.lightOnSurface,
    tertiary: AppPalette.lightSecondary,
    onTertiary: AppPalette.lightBackground,
    error: const Color(0xFFB3261E),
    onError: Colors.white,
    surface: AppPalette.lightBackground,
    onSurface: AppPalette.lightOnSurface,
    surfaceContainerHighest: AppPalette.lightCard,
    onSurfaceVariant: AppPalette.lightOnSurfaceVariant,
    outline: AppPalette.lightOnSurfaceVariant,
    outlineVariant: const Color(0xFFE0D8CC),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppPalette.darkOnSurface,
    onInverseSurface: AppPalette.lightOnSurface,
  );

  return _base(Brightness.light, scheme);
}

/// Tema DARK "Calidez Mediterránea".
ThemeData buildDarkTheme() {
  final scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.darkPrimary,
    onPrimary: AppPalette.darkBackground,
    primaryContainer: AppPalette.darkCard,
    onPrimaryContainer: AppPalette.darkOnSurface,
    secondary: AppPalette.darkSecondary,
    onSecondary: AppPalette.darkBackground,
    secondaryContainer: AppPalette.darkCard,
    onSecondaryContainer: AppPalette.darkOnSurface,
    tertiary: AppPalette.darkSecondary,
    onTertiary: AppPalette.darkBackground,
    error: const Color(0xFFCF6679),
    onError: Colors.black,
    surface: AppPalette.darkBackground,
    onSurface: AppPalette.darkOnSurface,
    surfaceContainerHighest: AppPalette.darkCard,
    onSurfaceVariant: AppPalette.darkOnSurfaceVariant,
    outline: AppPalette.darkOnSurfaceVariant,
    outlineVariant: const Color(0xFF3A4B53),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppPalette.darkOnSurface,
    onInverseSurface: AppPalette.darkCard,
  );

  return _base(Brightness.dark, scheme);
}

/// Base del ThemeData (componentes por defecto coherentes con la paleta).
ThemeData _base(Brightness b, ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    // Botones: acento principal como fondo, contraste con onPrimary.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainer,
      selectedIconTheme: IconThemeData(color: scheme.primary),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainer,
      selectedColor: scheme.primary,
      labelStyle: TextStyle(color: scheme.onSurface, fontSize: 13),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
  );
}