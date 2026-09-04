import 'package:flutter/material.dart';

/// Application sections shown in the navigation menus.
class AppSections {
  AppSections._();

  static const int invoices = 0;
  static const int pos = 1;
  static const int summaries = 2;

  static const List<String> labels = [
    'Facturas y comprobantes',
    'POS facturación',
    'Resúmenes contables',
  ];

  static const List<IconData> icons = [
    Icons.receipt_long,
    Icons.point_of_sale,
    Icons.savings,
  ];
}