import 'package:flutter/material.dart';
import 'active_view.dart';
import 'app_sections.dart';

/// Shell #2 — Tablet app (800 <= width < 1200).
/// AppBar with ONLY icons in the actions; the title is fixed.
class TabletShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const TabletShell({super.key, required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiumicello · Gestión'),
        automaticallyImplyLeading: false,
        actions: [
          for (var i = 0; i < AppSections.labels.length; i++)
            IconButton(
              tooltip: AppSections.labels[i],
              icon: Icon(AppSections.icons[i]),
              isSelected: selectedIndex == i,
              onPressed: () => onSelect(i),
            ),
        ],
      ),
      body: ActiveView(index: selectedIndex),
    );
  }
}