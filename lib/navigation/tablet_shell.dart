import 'package:flutter/material.dart';
import 'active_view.dart';
import 'app_sections.dart';
import '../core/data/api_client.dart';
import '../core/theme/theme_controller.dart';

/// Shell #2 — Tablet app (800 <= width < 1200).
/// AppBar with ONLY icons in the actions; the title is fixed.
class TabletShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const TabletShell({super.key, required this.selectedIndex, required this.onSelect});

  Future<void> _logout(BuildContext context) async {
    await ApiClient.logout();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = AppSections.visible();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiumicello · Gestión'),
        automaticallyImplyLeading: false,
        actions: [
          for (final s in visible)
            IconButton(
              tooltip: s.label,
              icon: Icon(s.icon),
              isSelected: selectedIndex == s.index,
              onPressed: () => onSelect(s.index),
            ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Cambiar tema',
            icon: AnimatedBuilder(
              animation: ThemeController.instance,
              builder: (context, _) =>
                  Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode),
            ),
            onPressed: () => ThemeController.instance.toggle(),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: ActiveView(index: selectedIndex, onNavegar: onSelect),
    );
  }
}