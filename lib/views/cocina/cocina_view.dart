import 'package:flutter/material.dart';
import '../../core/data/api_client.dart';
import '../../core/services/realtime_service.dart';
import '../../core/theme/app_themes.dart';

/// Pantalla de cocina en tiempo real.
///
/// Cada card ES un botón (onTap sobre toda la card, sin iconos de play ni
/// botones internos). Flujo por toque:
///   - Franja izquierda (1/3): comandas pendientes (recibida) en TERRACOTA.
///     Al tocar una -> pasa a 'preparando' y va al swiper central.
///   - Swiper (2/3): la comanda que se está preparando en DORADO (protagonismo).
///     Al tocar -> pasa a 'lista' y baja a la barra inferior.
///   - Barra inferior (ribbon): comandas ya preparadas (lista) en TURQUESA.
///     Al tocar -> se marca retirada (desaparece de cocina).
class CocinaView extends StatefulWidget {
  const CocinaView({super.key});

  @override
  State<CocinaView> createState() => _CocinaViewState();
}

class _CocinaViewState extends State<CocinaView> {
  List<Map<String, dynamic>> _cola = [];
  bool _loading = true;
  String? _error;
  final PageController _pageController = PageController(viewportFraction: 0.7);

  @override
  void initState() {
    super.initState();
    _load();
    final rt = RealtimeService.instance;
    rt.conectar();
    rt.on('comanda:nueva', (_) => _load());
    rt.on('cocina:estado', (_) => _load());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await ApiClient.colaCocina();
    if (!mounted) return;
    setState(() {
      _cola = r.ok ? r.list.cast<Map<String, dynamic>>() : [];
      _loading = false;
      if (!r.ok) _error = r.message;
    });
  }

  /// Cambia el estado de cocina (la card fue tocada como botón).
  Future<void> _tocarEstado(Map<String, dynamic> comanda, String estado) async {
    final id = comanda['id'];
    if (id == null) return;
    final r = await ApiClient.cambiarEstadoCocina(id as int, estado);
    if (!mounted) return;
    if (!r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    }
    _load();
  }

  // --- Agrupación por estado ---
  List<Map<String, dynamic>> get _pendiente =>
      _cola.where((c) => c['estado_cocina'] == 'recibida').toList();
  List<Map<String, dynamic>> get _preparando =>
      _cola.where((c) => c['estado_cocina'] == 'preparando').toList();
  List<Map<String, dynamic>> get _lista =>
      _cola.where((c) => c['estado_cocina'] == 'lista').toList();

  String _tituloComanda(Map<String, dynamic> c) {
    if (c['numero_mesa'] != null && (c['numero_mesa'] as String).isNotEmpty) {
      return 'Mesa ${c['numero_mesa']}';
    }
    if (c['cliente_nombre'] != null && (c['cliente_nombre'] as String).isNotEmpty) {
      return '${c['escenario'] == 'domicilio' ? 'Domicilio' : 'Para llevar'} · ${c['cliente_nombre']}';
    }
    return c['escenario'] ?? '-';
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'preparando':
        return AppPalette.darkSecondary; // dorado
      case 'lista':
        return AppPalette.darkPrimary; // turquesa
      default:
        return AppPalette.lightPrimary; // terracota
    }
  }

  String _estadoLabel(String estado) {
    switch (estado) {
      case 'preparando': return 'PREPARANDO';
      case 'lista': return 'LISTO';
      default: return 'EN ESPERA';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final esMovil = constraints.maxWidth < 640;
      if (esMovil) return _vistaMovil();
      return Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: constraints.maxWidth * 0.33, child: _franjaIzquierda()),
                const VerticalDivider(width: 1),
                Expanded(child: _panelDerecho()),
              ],
            ),
          ),
          _barraInferior(), // barra de listas (siempre presente)
        ],
      );
    });
  }

  // ---------- 1/3 izquierda: pendientes (terracota), todas botón ----------
  Widget _franjaIzquierda() {
    if (_pendiente.isEmpty) {
      return const Center(child: Text('Sin comandas en espera.'));
    }
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Text('En espera', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        for (final c in _pendiente) _tilePendiente(c),
      ],
    );
  }

  Widget _tilePendiente(Map<String, dynamic> c) {
    final color = AppPalette.lightPrimary; // terracota
    return InkWell(
      onTap: () => _tocarEstado(c, 'preparando'), // card = botón
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('#${c['id']} ${_tituloComanda(c)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            Text('${c['escenario'] ?? '-'}'.toUpperCase(),
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  // ---------- 2/3 derecho: swiper con la que se prepara (dorado) ----------
  Widget _panelDerecho() {
    if (_preparando.isEmpty) {
      return const Center(child: Text('Toca una comanda para prepararla.'));
    }
    return PageView.builder(
      controller: _pageController,
      itemCount: _preparando.length,
      // viewportFraction < 1 -> se asoman las vecinas en preparación.
      padEnds: true,
      allowImplicitScrolling: true,
      itemBuilder: (context, i) {
        final c = _preparando[i];
        final estado = c['estado_cocina'] ?? 'preparando';
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(child: _cardSwiper(c, estado)),
        );
      },
    );
  }

  Widget _cardSwiper(Map<String, dynamic> c, String estado) {
    final color = AppPalette.darkSecondary; // dorado
    return InkWell(
      onTap: () => _tocarEstado(c, 'lista'), // card = botón -> listo/baja
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14, height: 14,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text('#${c['id']} ${_tituloComanda(c)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 12),
            Text('${c['escenario'] ?? '-'}'.toUpperCase(),
                style: const TextStyle(fontSize: 12, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // ---------- Barra inferior: las ya preparadas (turquesa) ----------
  Widget _barraInferior() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(top: BorderSide(color: Color(0x22000000), width: 1)),
      ),
      child: _lista.isEmpty
          ? const Text('Sin comandas listas para retirar.',
              style: TextStyle(color: Colors.grey))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [for (final c in _lista) _chipListo(c)]),
            ),
    );
  }

  Widget _chipListo(Map<String, dynamic> c) {
    final color = AppPalette.darkPrimary; // turquesa
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _tocarEstado(c, 'retirada'), // card = botón -> retira
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Text('#${c['id']} ${_tituloComanda(c)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }

  // ---------- Móvil: lista simple, cards botón ----------
  Widget _vistaMovil() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [for (final c in _cola) _cardMovil(c)],
    );
  }

  Widget _cardMovil(Map<String, dynamic> c) {
    final estado = c['estado_cocina'] ?? 'recibida';
    final color = _colorEstado(estado);
    final String destino;
    if (estado == 'recibida') {
      destino = 'preparando';
    } else if (estado == 'preparando') {
      destino = 'lista';
    } else {
      destino = 'retirada';
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _tocarEstado(c, destino), // card = botón
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text('#${c['id']} ${_tituloComanda(c)}', style: const TextStyle(fontWeight: FontWeight.bold))),
              Text(_estadoLabel(estado), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}