import 'package:flutter/material.dart';
import '../views/invoices_view.dart';
import '../views/pos_sales_view.dart';
import '../views/summaries_view.dart';
import '../views/admin_view.dart';
import 'app_sections.dart';

/// Returns the widget for the active menu section.
class ActiveView extends StatelessWidget {
  final int index;
  const ActiveView({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case AppSections.pos:
        return const PosSalesView();
      case AppSections.summaries:
        return const SummariesView();
      case AppSections.admin:
        return const AdminView();
      default:
        return const InvoicesView();
    }
  }
}