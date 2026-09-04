import 'package:flutter/material.dart';
import 'active_view.dart';
import 'app_sections.dart';

/// Shell #1 — Mobile app (width < 800).
/// Uses a bottom NavigationBar. No AppBar is shown.
class MobileShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const MobileShell({super.key, required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final visible = AppSections.visible();
    return Scaffold(
      body: SafeArea(child: ActiveView(index: selectedIndex)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelect,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
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