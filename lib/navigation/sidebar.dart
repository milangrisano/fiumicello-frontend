import 'package:flutter/material.dart';
import 'app_sections.dart';
import '../core/data/api_client.dart';
import '../core/app_version.dart';
import '../core/theme/theme_controller.dart';

/// Reusable lateral menu used by the desktop shell (and optionally as a drawer).
/// Ahora es una barra de SOLO ICONOS (sin textos): al pasar el mouse sobre cada
/// icono, un Tooltip (la nube característica) muestra el nombre de la sección.
/// El botón de cerrar sesión vive al fondo de la barra.
class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const Sidebar({super.key, required this.selectedIndex, required this.onSelect});

  Future<void> _logout(BuildContext context) async {
    await ApiClient.logout();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  /// Ícono de sección con su tooltip (nube con el nombre). Vertical apilado.
  Widget _iconoSec(BuildContext context, SectionEntry s) {
    final scheme = Theme.of(context).colorScheme;
    final activo = selectedIndex == s.index;
    final color = activo ? scheme.primary : scheme.onSurfaceVariant;
    return Tooltip(
      message: s.label,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: selectedIndex == s.index ? null : () => onSelect(s.index),
        customBorder: const CircleBorder(),
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: activo
              ? BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                )
              : null,
          child: Icon(s.icon, color: color, size: 26),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = AppSections.visible();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Logo (gorro) arriba, como acceso a la carta.
        const SizedBox(height: 8),
        Tooltip(
          message: 'Carta',
          waitDuration: const Duration(milliseconds: 400),
          child: InkWell(
            onTap: () => onSelect(AppSections.carta),
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                Theme.of(context).brightness == Brightness.dark
                    ? 'assets/gorro_fiumicello_blanco.png'
                    : 'assets/gorro_fiumicello.png',
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [for (final s in visible) _iconoSec(context, s)],
          ),
        ),
        const Divider(height: 1),
        // Alternar tema (claro/oscuro).
        AnimatedBuilder(
          animation: ThemeController.instance,
          builder: (context, _) {
            final ctrl = ThemeController.instance;
            final oscuro = Theme.of(context).brightness == Brightness.dark;
            return Tooltip(
              message: 'Tema: ${oscuro ? 'Oscuro' : 'Claro'}',
              waitDuration: const Duration(milliseconds: 400),
              child: InkWell(
                onTap: () => ctrl.toggle(),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  child: Icon(
                    oscuro ? Icons.light_mode : Icons.dark_mode,
                    color: scheme.onSurfaceVariant,
                    size: 26,
                  ),
                ),
              ),
            );
          },
        ),
        // Cerrar sesión (la versión se muestra justo debajo).
        Tooltip(
          message: 'Cerrar sesión',
          waitDuration: const Duration(milliseconds: 400),
          child: InkWell(
            onTap: () => _logout(context),
            customBorder: const CircleBorder(),
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              child: Icon(Icons.logout, color: scheme.onSurfaceVariant, size: 26),
            ),
          ),
        ),
        // Versión de la app justo debajo del icono de cerrar sesión.
        const SizedBox(height: 2),
        Text('v.$APP_VERSION',
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
        // Versión del backend (leída de /health) para verificar coincidencia.
        FutureBuilder<String>(
          future: ApiClient.leerBackendVersion(),
          builder: (context, snap) {
            final bv = snap.data ?? '';
            final coincide = bv.isNotEmpty && bv == APP_VERSION;
            final col = coincide
                ? scheme.onSurfaceVariant
                : (bv.isEmpty ? scheme.onSurfaceVariant : scheme.error);
            return Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                bv.isEmpty ? 'backend —' : 'be: v$bv${coincide ? '' : ' ⚠'}',
                style: TextStyle(fontSize: 9, color: col),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}