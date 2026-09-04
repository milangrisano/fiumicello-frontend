import 'package:flutter/material.dart';
import '../responsive/responsive_layout.dart';

/// Top-level shell: keeps the active section index and hands it to the
/// responsive layout, which picks the correct shell for the screen width.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _onSelect(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(selectedIndex: _selectedIndex, onSelect: _onSelect);
  }
}