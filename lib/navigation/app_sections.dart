import 'package:flutter/material.dart';
import '../core/data/api_client.dart';

/// A single visible section entry.
class SectionEntry {
  final String label;
  final IconData icon;
  final int index;
  SectionEntry(this.label, this.icon, this.index);
}

/// Application sections shown in the navigation menus.
/// The menu is dynamic: sections appear based on the logged-in user's
/// permissions. The "Carta" section is always present for authenticated users
/// (so no one lands on an empty menu).
class AppSections {
  AppSections._();

  static const int carta = 0;
  static const int invoices = 1;
  static const int pos = 2;
  static const int summaries = 3;
  static const int admin = 4;

  static const List<String> _labelsAll = [
    'Carta',
    'Facturas y comprobantes',
    'POS facturación',
    'Resúmenes contables',
    'Administración',
  ];

  static const List<IconData> _iconsAll = [
    Icons.restaurant_menu,
    Icons.receipt_long,
    Icons.point_of_sale,
    Icons.savings,
    Icons.admin_panel_settings,
  ];

  /// Permission required for each non-carta section (index-aligned).
  static const List<String?> _permsAll = [
    null, // carta: always
    'facturas:ver',
    'ventas:ver',
    'resumenes:ver',
    'usuarios:gestionar', // admin section
  ];

  /// Whether the current user can see a given real index section.
  static bool _visible(int index) {
    if (ApiClient.isSuperadmin) return true;
    if (index == carta) return true; // always visible
    if (index == admin) {
      return ApiClient.hasPermiso('roles:gestionar') ||
          ApiClient.hasPermiso('usuarios:gestionar');
    }
    final p = _permsAll[index];
    return p == null || ApiClient.hasPermiso(p);
  }

  /// Visible sections for the current user.
  static List<SectionEntry> visible() {
    return [
      for (var i = 0; i < _labelsAll.length; i++)
        if (_visible(i)) SectionEntry(_labelsAll[i], _iconsAll[i], i),
    ];
  }
}