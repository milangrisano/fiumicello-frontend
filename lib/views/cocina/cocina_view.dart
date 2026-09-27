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

  @override
  void initState() {
    super.initState();
    _load();
    final rt = RealtimeService.instance;
    rt.conectar();
    rt.on('comanda:nueva', (_) => _load());
    rt.on('cocina:estado', (_) => _load());
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

  /// Borde de las cards de cocina: crema (lightCard) en dark, negro volcánico
  /// (lightOnSurface) en light.
  Color _bordeCard(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppPalette.lightCard  // crema
        : AppPalette.lightOnSurface; // negro volcánico
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
        for (var i = 0; i < _pendiente.length; i++)
          _tilePendiente(_pendiente[i], esPrimera: i == 0),
      ],
    );
  }

  Widget _tilePendiente(Map<String, dynamic> c, {bool esPrimera = false}) {
    final color = AppPalette.lightPrimary; // terracota
    final items = (c['items'] as List? ?? []).cast<Map<String, dynamic>>();
    return InkWell(
      onTap: () => _tocarEstado(c, 'preparando'), // card = botón
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _bordeCard(context), width: 2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('#${c['id']} ${_tituloComanda(c)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            Text('${c['escenario'] ?? '-'}'.toUpperCase(),
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
            // Solo la primera (próxima a preparar) muestra el contenido.
            if (esPrimera)
              for (final it in items)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('${it['cantidad'] ?? 1} × ${it['nombre'] ?? '-'}${(it['tamanio'] != null && (it['tamanio'] as String).isNotEmpty) ? ' (${it['tamanio']})' : ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
            if (esPrimera)
              Text('TOCAR PARA PREPARAR', style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  // ---------- 2/3 derecho: columna con todas las que se preparan (dorado) ----------
  Widget _panelDerecho() {
    if (_preparando.isEmpty) {
      return const Center(child: Text('Toca una comanda para prepararla.'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('PREPARANDO', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        for (final c in _preparando) _cardPreparando(c),
      ],
    );
  }

  /// Card de la comanda en preparación: contenido completo (ítems), dorada.
  Widget _cardPreparando(Map<String, dynamic> c) {
    final items = (c['items'] as List? ?? []).cast<Map<String, dynamic>>();
    return InkWell(
      onTap: () => _tocarEstado(c, 'lista'), // card = botón -> baja a listas
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppPalette.darkSecondary, // dorado
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _bordeCard(context), width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#${c['id']} · ${_tituloComanda(c)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            for (final it in items)
              Row(
                children: [
                  Text('${it['cantidad'] ?? 1} × ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  Expanded(
                    child: Text('${it['nombre'] ?? '-'}${(it['tamanio'] != null && (it['tamanio'] as String).isNotEmpty) ? ' (${it['tamanio']})' : ''}',
                        style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            if (items.any((it) => it['nota'] != null && (it['nota'] as String).isNotEmpty))
              for (final it in items)
                if (it['nota'] != null && (it['nota'] as String).isNotEmpty)
                  Text('   nota: ${it['nota']}',
                      style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 12)),
            const SizedBox(height: 6),
            Text('TOCAR PARA MARCAR LISTO', style: const TextStyle(fontSize: 11, color: Colors.white70)),
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
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _bordeCard(context), width: 2)),
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