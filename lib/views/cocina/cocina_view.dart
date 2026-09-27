import 'package:flutter/material.dart';
import '../../core/data/api_client.dart';
import '../../core/services/realtime_service.dart';
import '../../core/theme/app_themes.dart';

/// Pantalla de cocina en tiempo real.
///
/// Layout (ancho > 640):
///   - Franja izquierda (1/3): tiles de comandas recién generadas. Arriba la
///     próxima a preparar; debajo, las que están en cola.
///   - Panel derecho (2/3): swiper centrado en la comanda que se está
///     preparando. Se asoma a la izquierda la pendiente de preparar y a la
///     derecha la lista por recoger. Ribbon inferior con la que espera ser
///     retirada.
///   Colores de paleta: terracota pendiente, dorado preparando, turquesa lista.
class CocinaView extends StatefulWidget {
  const CocinaView({super.key});

  @override
  State<CocinaView> createState() => _CocinaViewState();
}

class _CocinaViewState extends State<CocinaView> {
  List<Map<String, dynamic>> _cola = [];
  bool _loading = true;
  String? _error;
  int _swiperIndex = 0;
  final PageController _pageController = PageController();

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
      if (_swiperIndex >= (_preparando.length + _pendiente.length) &&
          _preparando.isNotEmpty) {
        _swiperIndex = 0;
      }
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

  bool get _esCocinero =>
      ApiClient.isSuperadmin || ApiClient.hasPermiso('cocina:actualizar');

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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    }
    if (_cola.isEmpty) {
      return const Center(child: Text('No hay comandas en cocina.'));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final esMovil = constraints.maxWidth < 640;
      if (esMovil) return _vistaMovil();
      // Desktop/tablet: 1/3 izquierda + 2/3 derecha con swiper y ribbon.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: constraints.maxWidth * 0.33, child: _franjaIzquierda()),
          const VerticalDivider(width: 1),
          Expanded(child: _panelDerecho(constraints)),
        ],
      );
    });
  }

  // ---------- 1/3 izquierda: comandas recién generadas / en cola ----------
  Widget _franjaIzquierda() {
    final pend = _pendiente;
    final preparandose = _preparando;
    final cola = pend.isNotEmpty
        ? (preparandose.isNotEmpty ? [...preparandose, ...pend] : pend)
        : preparandose;
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Text('En cocina', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        for (final c in cola) _tileCola(c),
      ],
    );
  }

  Widget _tileCola(Map<String, dynamic> c) {
    final estado = c['estado_cocina'] ?? 'recibida';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _colorEstado(estado).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: _colorEstado(estado), width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${c['id']} ${_tituloComanda(c)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(estado, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          _cambiarBtnCola(c, estado),
        ],
      ),
    );
  }

  Widget _cambiarBtnCola(Map<String, dynamic> c, String estado) {
    if (!_esCocinero) return const SizedBox.shrink();
    if (estado == 'recibida') {
      return IconButton(
        icon: const Icon(Icons.play_circle_outline),
        tooltip: 'Empezar a preparar',
        onPressed: () => _cambiarEstado(c, 'preparando'),
      );
    }
    if (estado == 'preparando') {
      return IconButton(
        icon: const Icon(Icons.check_circle_outline, color: AppPalette.lightSecondary),
        tooltip: 'Marcar listo',
        onPressed: () => _cambiarEstado(c, 'lista'),
      );
    }
    return const SizedBox.shrink();
  }

  // ---------- 2/3 derecho: swiper + ribbon ----------
  Widget _panelDerecho(BoxConstraints constraints) {
    return Column(
      children: [
        Expanded(child: _swiper()),
        _ribbonRetirada(),
      ],
    );
  }

  Widget _swiper() {
    // Páginas: pendientes de preparar (terracota) + la que se prepara (dorado).
    final paginas = [..._pendiente, ..._preparando];
    if (paginas.isEmpty) {
      // Nada por preparar: mostrar las listas (esperando retirar) si hay.
      if (_lista.isNotEmpty) {
        return Center(child: _cardComanda(_lista.first, 'lista'));
      }
      return const Center(child: Text('No hay comandas por preparar.'));
    }
    // Centrar el actual: el paso se siente por las comandas que se asoman.
    return PageView.builder(
      controller: _pageController,
      itemCount: paginas.length,
      itemBuilder: (context, i) {
        final c = paginas[i];
        final estado = c['estado_cocina'] ?? 'recibida';
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Center(child: _cardComanda(c, estado)),
        );
      },
    );
  }

  Widget _cardComanda(Map<String, dynamic> c, String estado) {
    final color = _colorEstado(estado);
    // Acción por estado:
    //   recibida (terracota) -> Preparar  (cocinero)
    //   preparando (dorado) -> Listo      (cocinero)
    //   lista (turquesa)  -> Entregar    (mesero)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(20),
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14, height: 14,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('#${c['id']} ${_tituloComanda(c)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 14),
          Text('${c['escenario'] ?? '-'}',
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _btnAccion(estado, c),
        ],
      ),
    );
  }

  Widget _btnAccion(String estado, Map<String, dynamic> c) {
    if (_esCocinero && estado == 'recibida') {
      return FilledButton(onPressed: () => _cambiarEstado(c, 'preparando'), child: const Text('Preparar'));
    }
    if (_esCocinero && estado == 'preparando') {
      return FilledButton(onPressed: () => _cambiarEstado(c, 'lista'), child: const Text('Marcar listo'));
    }
    if (estado == 'lista') {
      return FilledButton(
        onPressed: () => _cambiarEstado(c, 'retirada'),
        child: const Text('Entregar a mesa'),
      );
    }
    return const SizedBox.shrink();
  }

  /// Ribbon inferior: card de la comanda que espera ser retirada (lista).
  Widget _ribbonRetirada() {
    if (_lista.isEmpty) return const SizedBox.shrink();
    final c = _lista.first;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.darkPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('#${c['id']} ${_tituloComanda(c)} — ${c['estado'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            onPressed: () => _cambiarEstado(c, 'retirada'),
            child: const Text('Retirada'),
          ),
        ],
      ),
    );
  }

  // ---------- Móvil: lista simple ----------
  Widget _vistaMovil() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [for (final c in _cola) _cardMovil(c)],
    );
  }

  Widget _cardMovil(Map<String, dynamic> c) {
    final estado = c['estado_cocina'] ?? 'recibida';
    final color = _colorEstado(estado);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('#${c['id']} ${_tituloComanda(c)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(estado, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            _btnAccion(estado, c),
          ],
        ),
      ),
    );
  }
}