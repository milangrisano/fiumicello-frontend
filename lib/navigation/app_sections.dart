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

  /// Whether the current user can see the admin section (superadmin only).
  static bool get canSeeAdmin => ApiClient.isSuperadmin;

  /// Visible sections for the current user. Non-superadmins do not see admin.
  static List<SectionEntry> visible() {
    final count = canSeeAdmin ? _labelsAll.length : _labelsAll.length - 1;
    return [
      for (var i = 0; i < count; i++)
        SectionEntry(_labelsAll[i], _iconsAll[i], i),
    ];
  }
}