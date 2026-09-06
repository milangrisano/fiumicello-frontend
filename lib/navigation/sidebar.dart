import 'package:flutter/material.dart';
import 'app_sections.dart';
import '../core/data/api_client.dart';
import '../core/app_version.dart';

/// Reusable lateral menu used by the desktop shell (and optionally as a drawer).
/// The logout button sits at the bottom of the sidebar.
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

  @override
  Widget build(BuildContext context) {
    final visible = AppSections.visible();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              for (final s in visible)
                ListTile(
                  selected: selectedIndex == s.index,
                  leading: Icon(s.icon),
                  title: Text(s.label),
                  onTap: selectedIndex == s.index ? null : () => onSelect(s.index),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // App version above logout.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.info_outline, size: 14, color: Colors.grey),
              SizedBox(width: 6),
              Text('Versión $APP_VERSION', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Cerrar sesión'),
          onTap: () => _logout(context),
        ),
      ],
    );
  }
}