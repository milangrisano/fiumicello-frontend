import 'package:flutter/material.dart';
import 'active_view.dart';
import 'sidebar.dart';
import 'app_titulo.dart';

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
  @override
  Widget build(BuildContext context) {
    // Sidebar siempre visible (solo iconos). Sin botón burger en el AppBar.
    return Scaffold(
      // Logo (gorro) como leading para ir a la carta: se mantiene igual pero
      // sin duplicarlo con el sidebar; el sidebar ya lo ofrece arriba.
      appBar: AppBar(
        title: ValueListenableBuilder<String>(
          valueListenable: AppTitulo.titulo,
          builder: (context, t, _) => Text(t),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Row(
        children: [
          SizedBox(
            width: 68,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Sidebar(
                selectedIndex: widget.selectedIndex,
                onSelect: widget.onSelect,
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: ActiveView(index: widget.selectedIndex, onNavegar: widget.onSelect)),
        ],
      ),
    );
  }
}