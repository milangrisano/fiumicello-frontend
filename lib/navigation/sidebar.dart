import 'package:flutter/material.dart';
import 'app_sections.dart';

/// Reusable lateral menu used by the desktop shell (and optionally as a drawer).
class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const Sidebar({super.key, required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        for (var i = 0; i < AppSections.labels.length; i++)
          ListTile(
            selected: selectedIndex == i,
            leading: Icon(AppSections.icons[i]),
            title: Text(AppSections.labels[i]),
            onTap: selectedIndex == i ? null : () => onSelect(i),
          ),
      ],
    );
  }
}