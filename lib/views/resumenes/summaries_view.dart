import 'package:flutter/material.dart';
import '../placeholder_view.dart';

/// Module 3 — Accounting summaries (place — reserved for ventas vs compras).
class SummariesView extends StatelessWidget {
  const SummariesView({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
      title: 'Resúmenes contables',
      icon: Icons.savings,
    );
  }
}