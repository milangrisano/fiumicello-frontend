import 'package:flutter/material.dart';
import 'active_view.dart';
import 'app_sections.dart';
import '../core/data/api_client.dart';

/// Shell #1 — Mobile app (width < 800).
///
/// AppBar with: chef-hat logo button (far left) that navigates to the menu/home
/// (carta), the logged-in user email centered, and a logout action (right).
/// Bottom NavigationBar shows the visible navigation sections (icons only).
///
/// IMPORTANT: the NavigationBar works with POSITION indices (0..visible.length-1).
/// We map position -> the real section index from `visible` so that hidden
/// sections never desync the selection, and `ActiveView` receives the real index.
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
    final email = ApiClient.currentEmail ?? 'Fiumicello';
    // Current real index -> its position in `visible` (for selectedIndex marker).
    final currentPos = visible.indexWhere((s) => s.index == selectedIndex);
    final safePos = currentPos < 0 ? 0 : currentPos;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Ver menú',
          icon: Image.asset(
            'assets/gorro_fiumicello.png',
            height: 40,
            fit: BoxFit.contain,
          ),
          onPressed: () => onSelect(AppSections.carta),
        ),
        title: Text(
          email,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SafeArea(child: ActiveView(index: selectedIndex)),
      // Floating rounded, near-transparent navigation bar with side/bottom gaps.
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            selectedIndex: safePos,
            height: 64,
            elevation: 0,
            backgroundColor: Colors.white.withOpacity(0.55),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            onDestinationSelected: (pos) {
              // Map position back to the real section index.
              if (pos >= 0 && pos < visible.length) {
                onSelect(visible[pos].index);
              }
            },
            destinations: [
              for (final s in visible)
                NavigationDestination(
                  icon: Icon(s.icon),
                  label: s.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}