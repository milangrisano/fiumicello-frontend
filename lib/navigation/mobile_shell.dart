import 'package:flutter/material.dart';
import 'active_view.dart';
import 'app_sections.dart';
import '../core/data/api_client.dart';

/// Shell #1 — Mobile app (width < 800).
/// Uses a bottom NavigationBar with icons only. The last icon is "logout",
/// handled via onDestinationSelected (NavigationDestination has no onTap).
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
    final logoutIndex = visible.length; // extra destination after sections
    return Scaffold(
      body: SafeArea(child: ActiveView(index: selectedIndex)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        onDestinationSelected: (i) {
          if (i == logoutIndex) {
            _logout(context);
          } else {
            onSelect(i);
          }
        },
        destinations: [
          for (final s in visible)
            NavigationDestination(
              icon: Icon(s.icon),
              label: s.label,
            ),
          const NavigationDestination(
            icon: Icon(Icons.logout),
            label: 'Cerrar sesión',
          ),
        ],
      ),
    );
  }
}