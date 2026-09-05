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
/// permissions (loaded into ApiClient via `cargarPermisos`).
class AppSections {
  AppSections._();

  static const int invoices = 0;
  static const int pos = 1;
  static const int summaries = 2;
  static const int admin = 3;

  static const List<String> _labelsAll = [
    'Facturas y comprobantes',
    'POS facturación',
    'Resúmenes contables',
    'Administración',
  ];

  static const List<IconData> _iconsAll = [
    Icons.receipt_long,
    Icons.point_of_sale,
    Icons.savings,
    Icons.admin_panel_settings,
  ];

  /// Permission required to see each section (index-aligned).
  static const List<String> _permsAll = [
    'facturas:ver',
    'ventas:ver',
    'resumenes:ver',
    'usuarios:gestionar', // admin section
  ];

  /// Whether the current user can see a given real index section.
  static bool _visible(int index) {
    if (ApiClient.isSuperadmin) return true;
    if (index == admin) {
      // Admin section: shown if the user can manage roles or users.
      return ApiClient.hasPermiso('roles:gestionar') ||
          ApiClient.hasPermiso('usuarios:gestionar');
    }
    return ApiClient.hasPermiso(_permsAll[index]);
  }

  /// Visible sections for the current user.
  static List<SectionEntry> visible() {
    return [
      for (var i = 0; i < _labelsAll.length; i++)
        if (_visible(i)) SectionEntry(_labelsAll[i], _iconsAll[i], i),
    ];
  }
}