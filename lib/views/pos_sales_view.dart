import 'package:flutter/material.dart';

/// Module 2 — POS invoicing (placeholder for now).
class PosSalesView extends StatelessWidget {
  const PosSalesView({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
      title: 'POS de facturación',
      icon: Icons.point_of_sale,
    );
  }
}

/// Reusable placeholder used by modules not yet developed.
class PlaceholderView extends StatelessWidget {
  final String title;
  final IconData icon;
  const PlaceholderView({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72, color: Colors.grey),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Este módulo se desarrollará en el siguiente paso.',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}