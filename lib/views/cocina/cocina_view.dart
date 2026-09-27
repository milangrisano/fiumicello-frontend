import 'package:flutter/material.dart';
import '../../core/data/api_client.dart';
import '../../core/services/realtime_service.dart';
import '../../core/theme/app_themes.dart';

/// Pantalla de cocina: colas de comandas en tiempo real.
///
/// Muestra las comandas con su estado de cocina (recibida -> preparando ->
/// lista -> retirada), ordenadas por llegada. El cocinero avanza
/// recibida/preparando/lista; el mesero marca retirada al llevarla a la mesa.
/// Responsive: cards en <640px, tabla en >=640px.
class CocinaView extends StatefulWidget {
  const CocinaView({super.key});

  @override
  State<CocinaView> createState() => _CocinaViewState();
}

class _CocinaViewState extends State<CocinaView> {
  List<Map<String, dynamic>> _cola = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    final rt = RealtimeService.instance;
    rt.conectar();
    // Actualiza la cola en tiempo real con cada evento relevante.
    rt.on('comanda:nueva', (_) => _load());
    rt.on('cocina:estado', (_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final r = await ApiClient.colaCocina();
    if (!mounted) return;
    setState(() {
      _cola = r.ok ? r.list.cast<Map<String, dynamic>>() : [];
      _loading = false;
      if (!r.ok) _error = r.message;
    });
  }

  Future<void> _cambiarEstado(Map<String, dynamic> comanda, String estado) async {
    final id = comanda['id'];
    if (id == null) return;
    final r = await ApiClient.cambiarEstadoCocina(id as int, estado);
    if (!mounted) return;
    if (!r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    }
    _load();
  }

  // Roles: cocinero avanza los 3 primeros; mesero puede marcar retirada.
  bool get _esCocinero =>
      ApiClient.isSuperadmin || ApiClient.hasPermiso('cocina:actualizar');

  String _tituloComanda(Map<String, dynamic> c) {
    if (c['numero_mesa'] != null && (c['numero_mesa'] as String).isNotEmpty) {
      return 'Mesa ${c['numero_mesa']}';
    }
    if (c['cliente_nombre'] != null && (c['cliente_nombre'] as String).isNotEmpty) {
      return '${c['escenario'] == 'domicilio' ? 'Domicilio' : 'Para llevar'} · ${c['cliente_nombre']}';
    }
    return c['escenario'] ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    }
    if (_cola.isEmpty) {
      return const Center(child: Text('No hay comandas en cocina.'));
    }
    // Orden por llegada: id ASC (ya viene así del backend).
    return LayoutBuilder(builder: (context, constraints) {
      final esMovil = constraints.maxWidth < 640;
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (esMovil) ...[
            for (final c in _cola) _cardMovil(c),
          ] else ...[
            _tablaCabecera(),
            for (final c in _cola) _filaTabla(c),
          ],
        ],
      );
    });
  }

  Widget _estadoBadge(String estado) {
    Color color;
    switch (estado) {
      case 'preparando':
        color = AppPalette.darkSecondary;
        break;
      case 'lista':
        color = AppPalette.darkPrimary;
        break;
      case 'retirada':
        color = AppPalette.lightOnSurfaceVariant;
        break;
      default: // recibida
        color = AppPalette.lightPrimary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(estado, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  // ---- Móvil (cards) ----
  Widget _cardMovil(Map<String, dynamic> c) {
    final estado = c['estado_cocina'] ?? 'recibida';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#${c['id']} ${_tituloComanda(c)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                _estadoBadge(estado),
              ],
            ),
            if ((c['total'] ?? 0) != 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Total: \$ ${(c['total'] ?? 0)}', style: const TextStyle(color: Colors.grey)),
              ),
            const SizedBox(height: 8),
            _acciones(c),
          ],
        ),
      ),
    );
  }

  // ---- PC (tabla) ----
  Widget _tablaCabecera() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0x11000000),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('Comanda', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _filaTabla(Map<String, dynamic> c) {
    final estado = c['estado_cocina'] ?? 'recibida';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x22000000)))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('#${c['id']} ${_tituloComanda(c)}')),
          Expanded(flex: 1, child: Text('\$ ${(c['total'] ?? 0)}')),
          Expanded(flex: 1, child: _estadoBadge(estado)),
          Expanded(flex: 2, child: _acciones(c)),
        ],
      ),
    );
  }

  // ---- Acciones según estado y rol ----
  Widget _acciones(Map<String, dynamic> c) {
    final estado = c['estado_cocina'] ?? 'recibida';
    // Botones a mostrar:
    // - Cocinero: recibida -> "Empezar" (preparando); preparando -> "Listo" (lista); nunca marca retirada.
    // - Todo el que pueda ver cocina (incl. mesero/admin): en 'lista' puede marcar 'retirada'.
    final puedeRetirar = estado == 'lista';
    return Row(
      children: [
        if (_esCocinero && estado == 'recibida')
          _btn('Preparar', () => _cambiarEstado(c, 'preparando')),
        if (_esCocinero && estado == 'preparando')
          _btn('Listo', () => _cambiarEstado(c, 'lista')),
        if (puedeRetirar)
          _btn('Entregar', () => _cambiarEstado(c, 'retirada')),
      ],
    );
  }

  Widget _btn(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilledButton(onPressed: onTap, child: Text(label)),
    );
  }
}