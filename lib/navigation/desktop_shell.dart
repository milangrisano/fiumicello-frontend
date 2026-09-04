import 'package:flutter/material.dart';
import 'active_view.dart';
import 'sidebar.dart';

/// Shell #3 — Desktop app (width >= 1200).
/// Shows a collapsible sidebar on the left; the body keeps the active view.
class DesktopShell extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const DesktopShell({super.key, required this.selectedIndex, required this.onSelect});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  bool _sidebarVisible = true;

  void _toggleSidebar() {
    setState(() => _sidebarVisible = !_sidebarVisible);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiumicello · Gestión'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Ocultar menú',
            icon: const Icon(Icons.menu_open),
            onPressed: _toggleSidebar,
          ),
        ],
      ),
      body: Row(
        children: [
          if (_sidebarVisible)
            SizedBox(
              width: 220,
              child: Sidebar(
                selectedIndex: widget.selectedIndex,
                onSelect: widget.onSelect,
              ),
            ),
          const VerticalDivider(width: 1),
          Expanded(child: ActiveView(index: widget.selectedIndex)),
        ],
      ),
    );
  }
}