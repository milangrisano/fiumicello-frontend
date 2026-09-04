import 'package:flutter/material.dart';
import 'app_sections.dart';

/// Reusable lateral menu used by the desktop shell (and optionally as a drawer).
class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const Sidebar({super.key, required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final visible = AppSections.visible();
    return ListView(
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
    );
  }
}