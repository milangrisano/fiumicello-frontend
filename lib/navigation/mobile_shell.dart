import 'package:flutter/material.dart';
import 'active_view.dart';
import 'app_sections.dart';
import 'radial_nav.dart';
import '../core/data/api_client.dart';

/// Shell #1 — Mobile app (width < 800).
///
/// AppBar with: chef-hat logo button (far left) that navigates to the menu/home
/// (carta), the logged-in user email centered, and a logout action (right).
/// The bottom navigation is a FLOATING RADIAL button (bottom-right), replacing
/// the classic NavigationBar. It fans out the section icons in an inset 90° arc.
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
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
      // El body superpone el contenido y el FAB radial (navegación inferior).
      body: SafeArea(
        child: Stack(children: [
          Positioned.fill(child: ActiveView(index: selectedIndex, onNavegar: onSelect)),
          // FAB radial de navegación, esquina inferior derecha (sin barra).
          RadialNav(
            sections: visible,
            selectedIndex: selectedIndex,
            onSelect: onSelect,
          ),
        ]),
      ),
    );
  }
}