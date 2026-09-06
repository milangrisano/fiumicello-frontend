import 'package:flutter/material.dart';
import '../core/data/api_client.dart';
import '../core/utils/formatters.dart';

/// Public Fiumicello menu (carta). Shown at the app's root `/` and as a section
/// for authenticated users. Structured: categories with their items and prices.
class CartaView extends StatefulWidget {
  const CartaView({super.key});

  @override
  State<CartaView> createState() => _CartaViewState();
}

class _CartaViewState extends State<CartaView> {
  Map<String, dynamic>? _carta;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiClient.obtenerCarta();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _carta = r.data;
      } else {
        _error = r.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));
    final cats =
        (_carta?['categorias'] as List? ?? []).cast<Map<String, dynamic>>();
    return Container(
      color: const Color(0xFF1E1B1A), // dark, textured-like background
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header with logo + brand
          Center(
            child: Column(
              children: [
                Image.asset('assets/logo_fiumicello.png', width: 72, height: 72),
                const SizedBox(height: 8),
                const Text(
                  'Fiumicello Trattoria',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const Text('Des 2024 · Bogotá e Ibagué',
                    style: TextStyle(color: Colors.amber)),
                const SizedBox(height: 8),
                const Text('MENÚ',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 4)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          for (final c in cats) ...[
            Text(
              c['nombre'] ?? '',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 6),
            for (final it in (c['items'] as List? ?? []).cast<Map<String, dynamic>>())
              _item(it),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 12),
          const Center(
            child: Text('¡BUON APPETITO!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 2)),
          ),
        ],
      ),
    );
  }

  Widget _item(Map<String, dynamic> it) {
    final nombre = it['nombre'] ?? '';
    final desc = it['descripcion'] as String?;
    final conTamanos = it['precio_personal'] != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(nombre,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              if (conTamanos)
                _precio('Desde ${money(it['precio_personal'])}')
              else
                _precio(money(it['precio'])),
            ],
          ),
          if (desc != null && desc.isNotEmpty)
            Text(desc, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          if (conTamanos)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Personal ${money(it['precio_personal'])} · '
                'Mediana ${money(it['precio_mediana'])} · '
                'Grande ${money(it['precio_grande'])}',
                style: TextStyle(color: Colors.amber[200], fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _precio(String s) => Text(s,
      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold));
}