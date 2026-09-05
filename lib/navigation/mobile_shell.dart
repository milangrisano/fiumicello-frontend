import 'package:flutter/material.dart';
import 'active_view.dart';
import 'app_sections.dart';
import '../core/data/api_client.dart';

/// Shell #1 — Mobile app (width < 800).
///
/// AppBar with: Fiumicello logo (left), logged-in user email (center), and a
/// logout action (right). Bottom NavigationBar shows only the navigation
/// sections (icons only, no text labels).
class MobileShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const MobileShell({super.key, required this.selectedIndex, required this.onSelect});

  Future<void> _logout(BuildContext context) async {
    await ApiClient.logout();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = AppSections.visible();
    final email = ApiClient.currentEmail ?? 'Fiumicello';
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu, color: Color(0xFF0969DA)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                email,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SafeArea(child: ActiveView(index: selectedIndex)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        onDestinationSelected: onSelect,
        destinations: [
          for (final s in visible)
            NavigationDestination(
              icon: Icon(s.icon),
              label: s.label,
            ),
        ],
      ),
    );
  }
}