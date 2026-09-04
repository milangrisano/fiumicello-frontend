import 'package:flutter/material.dart';
import '../navigation/mobile_shell.dart';
import '../navigation/tablet_shell.dart';
import '../navigation/desktop_shell.dart';
import '../responsive/breakpoints.dart';

/// Selects the correct app shell according to the screen width.
///
/// Returns one of the three top-level shells:
///  - [MobileShell]  when width < 800
///  - [TabletShell]  when 800 <= width < 1200
///  - [DesktopShell] when width >= 1200
class ResponsiveLayout extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const ResponsiveLayout({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (Breakpoints.isMobile(width)) {
      return MobileShell(selectedIndex: selectedIndex, onSelect: onSelect);
    }
    if (Breakpoints.isTablet(width)) {
      return TabletShell(selectedIndex: selectedIndex, onSelect: onSelect);
    }
    return DesktopShell(selectedIndex: selectedIndex, onSelect: onSelect);
  }
}