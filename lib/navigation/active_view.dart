import 'package:flutter/material.dart';
import '../views/facturas/invoices_view.dart';
import '../views/pos_sales_view.dart';
import '../views/resumenes/summaries_view.dart';
import '../views/admin/admin_view.dart';
import '../views/carta/carta_view.dart';
import 'app_sections.dart';

/// Returns the widget for the active menu section.
class ActiveView extends StatelessWidget {
  final int index;
  /// Callback para que una vista (p. ej. el POS) navegue a otra sección.
  final ValueChanged<int>? onNavegar;
  const ActiveView({super.key, required this.index, this.onNavegar});

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case AppSections.carta:
        return const CartaView();
      case AppSections.pos:
        return PosSalesView(onNavegar: onNavegar);
      case AppSections.summaries:
        return const SummariesView();
      case AppSections.admin:
        return const AdminView();
      default:
        return const InvoicesView();
    }
  }
}