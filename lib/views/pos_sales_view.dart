import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/data/api_client.dart';
import '../core/app_version.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../navigation/app_titulo.dart';
import '../core/utils/formatters.dart';
import 'pos_facturacion/pos_models.dart';
import 'pos_facturacion/pos_utils.dart'
    show numVal, precioDe;
import 'pos_facturacion/widgets/comanda_view.dart';
import 'pos_facturacion/widgets/cierre_caja_view.dart';
import 'pos_facturacion/widgets/movimientos_caja_view.dart';
import 'pos_facturacion/widgets/pago_propina_view.dart';
import 'pos_facturacion/widgets/conteo_denominacion.dart';
import '../core/services/realtime_service.dart';
import 'cocina/cocina_view.dart';

/// POS invoicing — 3-stage flow.
class PosSalesView extends StatefulWidget {
  /// Callback para navegar a otra sección (p. ej. el Resumen de ventas).
  final ValueChanged<int>? onNavegar;
  const PosSalesView({super.key, this.onNavegar});

  @override
  State<PosSalesView> createState() => _PosSalesViewState();
}

class _PosSalesViewState extends State<PosSalesView> {
  // Total de efectivo calculado por el widget compartido ConteoDenominacion
  // (apertura de caja). Se actualiza en vivo vía callback.
  double _efectivoApertura = 0;

  Map<String, dynamic>? _carta;
  List<Map<String, dynamic>> _formas = [];
  final List<Linea> _comanda = [];
  String _escenario = 'mesa';
  String _numeroMesa = '';
  String _clienteNombre = '';
  String _direccion = '';
  String _telefono = '';
  int _pantalla = Pantalla.comanda;
  // Modo "agregar a mesa abierta": si no es null, la comanda se agrega a ese
  // pedido (mesa) al continuar, sin pasar por la etapa de asignación.
  int? _modoAgregarMesaId;

  List<Map<String, dynamic>> _mesasAbiertas = [];
  List<Map<String, dynamic>> _pendientes = [];
  // Pedidos de para llevar (abiertos + pagados pendientes de entrega).
  List<Map<String, dynamic>> _paraLlevar = [];
  // Pedidos de domicilio (abiertos + pagados pendientes de entrega).
  List<Map<String, dynamic>> _domicilios = [];

  // Orden de las pestañas de la barra del POS (ids 0..6) POR USUARIO. Se
  // persiste en SharedPreferences con clave por email para que cada empleado
  // tenga su propio orden al entrar.
  static const _posOrdenKey = 'pos_pestanas_orden_';
  List<int> _ordenPestanasPos = const [0, 1, 2, 3, 4, 5, 6];

  bool _loading = true;
  bool _cobrando = false;
  String? _error;
  String _busqueda = '';
  int? _categoriaSel;
  int? _cobroFormaPago;

  // Caja / turno activo
  Map<String, dynamic>? _turno;
  bool _cajaCargando = false;
  bool _dialogAperturaAbierto = false;
  // Lista de turnos (para consultar turnos anteriores) y el índice seleccionado.
  List<Map<String, dynamic>> _turnos = [];

  @override
  void initState() {
    super.initState();
    _load();
    // Restaura una comanda a medio armar si el usuario salió sin enviarla.
    _cargarComandaGuardada();
    _cargarOrdenPestanasPos(); // orden de pestañas por usuario
    // Tiempo real: refresca el turno de caja y las listas al abrir/cerrar turno.
    final rt = RealtimeService.instance;
    rt.conectar();
    rt.on('turno:abierto', (_) => _cargarTurno());
    rt.on('turno:cerrado', (_) => _cargarTurno());
    rt.on('comanda:nueva', (_) => _refreshVivos());
    rt.on('pedido:anulacion-solicitada', (d) =>
        _recibirSolicitudAnulacion(d['id'] as int? ?? 0, d));
    rt.on('pedido:anulada', (_) => _refreshVivos());
  }

  /// Al llegar una solicitud de anulación (la lanzó un cajero), si este usuario
  /// es superadmin/admin/encargado se le ofrece aprobarla con su contraseña.
  void _recibirSolicitudAnulacion(int pedidoId, Map<String, dynamic> d) {
    final puedeAprobar = ApiClient.hasPermiso('pedidos:anular') ||
        ['superadmin', 'admin', 'encargado'].contains(ApiClient.currentRol);
    if (!puedeAprobar) return;
    if (pedidoId <= 0) return;
    if (!mounted) return;
    final nombre = (d['cliente_nombre'] ?? d['numero_mesa'] ?? '').toString();
    _dialogAprobarAnulacion(pedidoId, nombre, d['total'], (d['motivo'] ?? '').toString());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final c = await ApiClient.obtenerCarta().timeout(const Duration(seconds: 15));
      final f = await ApiClient.listarFormasPago().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        if (c.ok && c.data != null) _carta = c.data;
        else _error = c.message;
        if (f.ok) _formas = f.list.cast<Map<String, dynamic>>();
        if (_cobroFormaPago == null && _formas.isNotEmpty) {
          _cobroFormaPago = _formas.first['id'] as int?;
        }
        _loading = false;
      });
      await _refreshVivos();
      await _cargarTurno();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _refreshVivos() async {
    final m = await ApiClient.listarPedidos(estado: 'abierta', escenario: 'mesa');
    final p = await ApiClient.listarPedidos(estado: 'pagada_pendiente');
    // Para llevar: abiertas + pagadas pendientes de entrega.
    final plA = await ApiClient.listarPedidos(estado: 'abierta', escenario: 'para_llevar');
    final plP = await ApiClient.listarPedidos(estado: 'pagada_pendiente', escenario: 'para_llevar');
    // Domicilios: abiertas + pagadas pendientes de entrega.
    final doA = await ApiClient.listarPedidos(estado: 'abierta', escenario: 'domicilio');
    final doP = await ApiClient.listarPedidos(estado: 'pagada_pendiente', escenario: 'domicilio');
    if (!mounted) return;
    setState(() {
      _mesasAbiertas = m.ok ? m.list.cast<Map<String, dynamic>>() : [];
      _pendientes = p.ok ? p.list.cast<Map<String, dynamic>>() : [];
      _paraLlevar = [
        ...(plA.ok ? plA.list.cast<Map<String, dynamic>>() : []),
        ...(plP.ok ? plP.list.cast<Map<String, dynamic>>() : []),
      ];
      _domicilios = [
        ...(doA.ok ? doA.list.cast<Map<String, dynamic>>() : []),
        ...(doP.ok ? doP.list.cast<Map<String, dynamic>>() : []),
      ];
    });
  }

  List<Map<String, dynamic>> get _categorias =>
      (_carta?['categorias'] as List? ?? []).cast<Map<String, dynamic>>();

  double get _totalComanda {
    double t = 0;
    for (final l in _comanda) t += l.subtotal;
    return t;
  }

  void _agregar(Map<String, dynamic> item, String? tamanio) {
    final precio = precioDe(item, tamanio);
    // Costo del catálogo (para guardarlo en la venta); se edita en el resumen.
    final costoCatalogo = double.tryParse((item['costo'] ?? '').toString()) ?? 0.0;
    setState(() {
      for (final l in _comanda) {
        if (l.idProducto == (item['id'] as int?) && l.tamanio == tamanio) {
          if (l.yaEnMesa) {
            // Producto ya estaba en la mesa: aumenta la cantidad visual Y el
            // delta a enviar (agregar), en la misma línea — no crea otra.
            l.cantidad++;
            l.agregar++;
          } else {
            l.cantidad++;
          }
          return;
        }
      }
      _comanda.add(Linea(
        idProducto: item['id'] as int,
        nombre: item['nombre'] ?? '',
        tamanio: tamanio,
        precio: precio,
        costoUnitario: costoCatalogo,
      ));
    });
    _guardarComanda();
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  List<Map<String, dynamic>> get _itemsComandaJson => [
        for (final l in _comanda)
          if (!l.yaEnMesa) // producto nuevo completo
            {
              'id_producto': l.idProducto,
              'tamanio': l.tamanio,
              'cantidad': l.cantidad,
              'nota': l.nota.isEmpty ? null : l.nota,
              'costo_unitario': l.costoUnitario,
            }
          else if (l.agregar > 0) // ya en mesa: solo el delta agregado
            {
              'id_producto': l.idProducto,
              'tamanio': l.tamanio,
              'cantidad': l.agregar,
              'nota': l.nota.isEmpty ? null : l.nota,
              'costo_unitario': l.costoUnitario,
            }
      ];

  Future<void> _siguienteEtapa() async {
    if (_comanda.isEmpty) {
      _snack('Agrega al menos un producto.');
      return;
    }
    // Gate de apertura de turno: para facturar hay que tener la caja/turno
    // abierto. Si no hay turno, se pide abrir la caja aquí, no al entrar.
    if (_turno == null) {
      await _dialogAbrirCaja();
      if (!mounted) return;
      if (_turno == null) {
        _snack('Debe abrir la caja para facturar.');
        return;
      }
    }
    // Modo "agregar a mesa abierta": añade la comanda a ese pedido y vuelve a
    // las mesas (sin pasar por la asignación, que ya se hizo la primera vez).
    if (_modoAgregarMesaId != null) {
      final nuevos = _comanda.where((l) => !l.yaEnMesa || l.agregar > 0).toList();
      if (nuevos.isEmpty) {
        _snack('Agrega al menos un producto nuevo.');
        return;
      }
      setState(() => _cobrando = true);
      final r = await ApiClient.agregarItemsPedido(_modoAgregarMesaId!, _itemsComandaJson);
      if (!mounted) return;
      setState(() => _cobrando = false);
      if (!r.ok) {
        _snack(r.message);
        return;
      }
      setState(() {
        _pantalla = Pantalla.mesas;
        _comanda.clear();
        _modoAgregarMesaId = null;
      });
      await _refreshVivos();
      return;
    }
    // Abre la ventana del escenario con los 2 botones: "Comandar y enviar a
    // cocina" (crea y va a cocina, sin cobrar) o "Pagar" (crea, va a cocina y
    // abre el pago con medio y propina).
    final accion = await _dialogEscenario();
    if (accion == null) return; // cancelado
    await _crearPedido(accion: accion);
  }

  /// Ventana del escenario elegido: muestra los chips Mesa / Para llevar /
  /// Domicilio (preseleccionado el actual de la comanda, pero CAMBIABLE ahí
  /// mismo) y el campo correspondiente. Ofrece 2 acciones: comandar (a cocina)
  /// o pagar. Retorna 'comandar'|'pagar' o null si se cancela.
  /// Al aceptar, persiste el escenario y los campos en el State del POS.
  Future<String?> _dialogEscenario() async {
    final sel = _EscenarioSel(_escenario);
    final mesaCtrl = TextEditingController(text: _numeroMesa);
    final nombreCtrl = TextEditingController(text: _clienteNombre);
    final direccionCtrl = TextEditingController(text: _direccion);
    final telefonoCtrl = TextEditingController(text: _telefono);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final chips = Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final o in const [
                ['mesa', 'Mesa', Icons.restaurant],
                ['para_llevar', 'Para llevar', Icons.takeout_dining],
                ['domicilio', 'Domicilio', Icons.local_shipping],
              ])
                ChoiceChip(
                  label: Text(o[1] as String),
                  avatar: Icon(o[2] as IconData, size: 18),
                  selected: sel.esc == o[0],
                  shape: const StadiumBorder(),
                  onSelected: (_) => setDlg(() => sel.esc = o[0] as String),
                ),
            ],
          );
          final contenido = sel.esc == 'mesa'
              ? TextField(
                  controller: mesaCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número de mesa',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                )
              : sel.esc == 'para_llevar'
                  ? TextField(
                      controller: nombreCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la persona',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: nombreCtrl,
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la persona',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: direccionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Dirección',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: telefonoCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                    );
          return AlertDialog(
            title: const Text('Comandar'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                chips,
                const SizedBox(height: 12),
                contenido,
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton.icon(
                icon: const Icon(Icons.kitchen_outlined),
                onPressed: () =>
                    Navigator.pop(ctx, {'esc': sel.esc, 'accion': 'comandar'}),
                label: const Text('Comandar'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.payments_outlined),
                onPressed: () =>
                    Navigator.pop(ctx, {'esc': sel.esc, 'accion': 'pagar'}),
                label: const Text('Pagar'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null) return null;
    // Persistir escenario elegido + campos en el State del POS.
    setState(() {
      _escenario = (result['esc'] ?? _escenario) as String;
      _numeroMesa = mesaCtrl.text.trim();
      _clienteNombre = nombreCtrl.text.trim();
      _direccion = direccionCtrl.text.trim();
      _telefono = telefonoCtrl.text.trim();
    });
    return result['accion'] as String?;
  }

  /// Selección de escenario (chip): solo marca la opción elegida. La ventana de
  /// datos (mesa/llevar/domicilio) se abre al presionar "Continuar", y ahí se
  /// elige entre "Comandar y enviar a cocina" o "Pagar".
  void _elegirEscenario(String escenario) {
    setState(() => _escenario = escenario);
  }

  /// Ventana flotante de un solo campo de texto.
  Future<String?> _dialogTexto({
    required String titulo,
    required String etiqueta,
    required IconData icono,
    String textoInicial = '',
    TextInputType? teclado,
  }) {
    final ctrl = TextEditingController(text: textoInicial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [Icon(icono), const SizedBox(width: 8), Text(titulo)]),
        content: TextField(
          controller: ctrl,
          keyboardType: teclado,
          autofocus: true,
          decoration: InputDecoration(
            labelText: etiqueta,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  /// Crea el pedido (SIEMPRE entra a cocina, se pague o no). Si `accion ==
  /// 'pagar'` abre la ventana de pago (medio + propina). Si es 'comandar'
  /// solo crea y envía a cocina, sin cobrar.
  Future<void> _crearPedido({String accion = 'comandar'}) async {
    if (_escenario == 'mesa' && _numeroMesa.trim().isEmpty) {
      _snack('Indique el número de mesa.');
      return;
    }
    if (_escenario == 'para_llevar' && _clienteNombre.trim().isEmpty) {
      _snack('Indique el nombre de la persona para llevar.');
      return;
    }
    if (_escenario == 'domicilio' && _clienteNombre.trim().isEmpty) {
      _snack('Indique el nombre para el domicilio.');
      return;
    }
    setState(() => _cobrando = true);
    final body = <String, dynamic>{
      'escenario': _escenario,
      'numero_mesa': _escenario == 'mesa' ? _numeroMesa.trim() : null,
      'cliente_nombre': _escenario == 'mesa' ? null
          : (_clienteNombre.trim().isEmpty ? null : _clienteNombre.trim()),
      'direccion': (_escenario == 'domicilio' && _direccion.isNotEmpty) ? _direccion : null,
      'telefono': (_escenario == 'domicilio' && _telefono.isNotEmpty) ? _telefono : null,
      'items': _itemsComandaJson,
    };
    final r = await ApiClient.crearPedido(body);
    if (!mounted) return;
    setState(() => _cobrando = false);
    if (!r.ok) {
      _snack(r.message);
      return;
    }
    final id = await _idDelPedido();

    if (accion == 'pagar') {
      // Pagar: crea (ya va a cocina) y abre la ventana de pago (medio + propina).
      if (id == null) {
        _snack('No se pudo crear el pedido.');
        return;
      }
      await _dialogPagarPedido(id);
      return;
    }

    // Comandar y enviar a cocina: sin cobrar.
    if (_escenario == 'mesa') {
      _snack('Mesa ${_numeroMesa.trim()} enviada a cocina.');
      setState(() {
        _pantalla = Pantalla.mesas;
        _comanda.clear();
        _numeroMesa = '';
      });
      await _borrarComandaGuardada();
      await _refreshVivos();
    } else {
      _snack('Comanda enviada a cocina.');
      _limpiarComanda();
    }
  }

  /// Limpia el estado de la comanda actual.
  void _limpiarComanda() {
    setState(() {
      _pantalla = Pantalla.comanda;
      _comanda.clear();
      _numeroMesa = '';
      _clienteNombre = '';
      _direccion = '';
      _telefono = '';
      _modoAgregarMesaId = null;
    });
    _borrarComandaGuardada();
  }

  // ---------- Persistencia de la comanda (SharedPreferences) ----------
  static const _comandaKey = 'comanda_pendiente';

  /// Guarda la comanda en disco para que sobreviva a salir/volver o reiniciar.
  Future<void> _guardarComanda() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_comanda.map((l) => {
      'id': l.idProducto,
      'nombre': l.nombre,
      'tamanio': l.tamanio,
      'precio': l.precio,
      'cantidad': l.cantidad,
      'nota': l.nota,
      'costo': l.costoUnitario,
    }).toList());
    await prefs.setString(_comandaKey, json);
  }

  /// Restaura una comanda guardada (si existe) al abrir el POS.
  Future<void> _cargarComandaGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_comandaKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List;
      if (decoded.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _comanda.clear();
        for (final it in decoded) {
          final m = Map<String, dynamic>.from(it as Map);
          _comanda.add(Linea(
            idProducto: (m['id'] as num).toInt(),
            nombre: m['nombre'] ?? '',
            tamanio: m['tamanio'] as String?,
            precio: (m['precio'] as num).toDouble(),
            cantidad: (m['cantidad'] as num).toInt(),
            nota: m['nota'] ?? '',
            costoUnitario: (m['costo'] as num?)?.toDouble() ?? 0,
          ));
        }
      });
    } catch (_) {
      // Si el JSON estuviera corrupto, lo limpiamos silenciosamente.
      await prefs.remove(_comandaKey);
    }
  }

  /// Elimina la comanda guardada del disco.
  Future<void> _borrarComandaGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_comandaKey);
  }

  /// Borra la comanda actual con confirmación (por si se tocó por error).
  Future<void> _borrarComanda() async {
    final ok = await _dialogConfirm('¿Borrar toda la comanda? Los productos seleccionados se eliminarán.');
    if (ok != true) return;
    setState(() {
      _comanda.clear();
      _numeroMesa = '';
      _clienteNombre = '';
      _direccion = '';
      _telefono = '';
    });
    await _borrarComandaGuardada();
    _snack('Comanda borrada.');
  }

  /// Ventana de pago: medio de pago + propina opcional. Cobra el pedido (que
  /// ya fue creado y entró a cocina) y, si hay propina, la registra.
  /// `montoMostrar` es el total que se exhibe (por defecto el de la comanda
  /// actual; para "pedir la cuenta" de una mesa se pasa el de esa mesa).
  Future<void> _dialogPagarPedido(int pedidoId, {double? montoMostrar}) async {
    int? formaSel = _cobroFormaPago;
    if (formaSel == null && _formas.isNotEmpty) {
      formaSel = _formas.first['id'] as int?;
    }
    final propinaCtrl = TextEditingController();
    final entregaCtrl = TextEditingController();
    final monto = montoMostrar ?? _totalComanda;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pagar'),
        content: StatefulBuilder(builder: (ctx, setStateDlg) {
          // ¿La forma de pago elegida es Efectivo? (por nombre, robusto).
          bool esEfectivo = false;
          for (final f in _formas) {
            if ((f['id'] as int?) == formaSel) {
              esEfectivo = (f['nombre'] ?? '').toString().toLowerCase() == 'efectivo';
              break;
            }
          }
          final propina = double.tryParse(propinaCtrl.text.replaceAll(',', '.')) ?? 0;
          final aPagar = monto + propina;
          final recibido = double.tryParse(entregaCtrl.text.replaceAll(',', '.')) ?? 0;
          final cambio = recibido - aPagar;
          final cobrable = !esEfectivo || recibido >= aPagar;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Total: ${money(monto)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: formaSel,
                decoration: const InputDecoration(labelText: 'Medio de pago', border: OutlineInputBorder(), isDense: true),
                items: [for (final f in _formas) DropdownMenuItem(value: f['id'] as int, child: Text(f['nombre'] ?? ''))],
                onChanged: (v) => setStateDlg(() => formaSel = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: propinaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Propina (opcional)', border: OutlineInputBorder(), isDense: true),
              ),
              // Solo en efectivo: cuánto entrega el cliente y el cambio a devolver.
              if (esEfectivo) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: entregaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setStateDlg(() {}),
                  decoration: const InputDecoration(labelText: 'Con cuánto paga el cliente', prefixText: '\$', border: OutlineInputBorder(), isDense: true),
                ),
                SizedBox(height: 4),
                Text('A pagar (total + propina): ${money(aPagar)}', style: const TextStyle(fontSize: 13)),
                if (recibido > 0 && cambio >= 0)
                  Text('Cambio a devolver: ${money(cambio)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary))
                else if (recibido > 0 && cambio < 0)
                  Text('Falta dinero: ${money(-cambio)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red)),
              ],
              const SizedBox(height: 12),
              Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: cobrable ? () => Navigator.pop(ctx, true) : null,
                  child: const Text('Cobrar'),
                ),
              ])),
            ],
          );
        }),
      ),
    );
    if (confirmado != true) {
      // Canceló el pago: la comanda ya se creó y está en cocina (pendiente de cobro).
      _snack('Comanda enviada a cocina (cobro pendiente).');
      _limpiarComanda();
      await _refreshVivos();
      return;
    }
    if (!mounted) return;
    // Cobrar el pedido con el medio elegido.
    setState(() => _cobrando = true);
    final r = await ApiClient.cobrarPedido(pedidoId, formaSel);
    // Registrar propina si se indicó y el cobro fue exitoso.
    final propina = double.tryParse(propinaCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    if (r.ok && propina > 0) {
      final hoy = DateTime.now().toIso8601String().split('T').first;
      await ApiClient.cajaPagarPropina(hoy, propina, 0, null, null, 'Propina de comanda');
    }
    if (!mounted) return;
    setState(() => _cobrando = false);
    if (!r.ok) {
      _snack(r.message);
      _limpiarComanda();
      await _refreshVivos();
      return;
    }
    _snack('Comanda cobrada.');
    _limpiarComanda();
    await _refreshVivos();
  }

  Future<int?> _idDelPedido() async {
    final p = await ApiClient.listarPedidos();
    if (p.ok && p.list.isNotEmpty) {
      final last = p.list.first as Map<String, dynamic>;
      return last['id'] as int?;
    }
    return null;
  }

  Future<void> _agregarAMesa(int pedidoId, Map<String, dynamic> item, String? tamanio) async {
    final nota = await _dialogNota('${item['nombre']} — Nota (opcional)');
    setState(() => _cobrando = true);
    final r = await ApiClient.agregarItemsPedido(pedidoId, [
          {
            'id_producto': item['id'] as int,
            'tamanio': tamanio,
            'cantidad': 1,
            'nota': (nota != null && nota.trim().isNotEmpty) ? nota : null,
          }
        ]);
    if (!mounted) return;
    setState(() => _cobrando = false);
    _snack(r.ok ? 'Producto agregado a la mesa.' : r.message);
    await _refreshVivos();
  }

  Future<void> _cargarTurno() async {
    final r = await ApiClient.cajaActiva();
    if (!mounted) return;
    setState(() => _turno = (r.ok && r.data != null && r.data!.isNotEmpty) ? r.data : null);
    // Cargar la lista de turnos (para consultar turnos anteriores). El más
    // reciente queda en el índice 0.
    final t = await ApiClient.cajaTurnos();
    if (!mounted) return;
    if (t.ok) {
      final lista = t.list.cast<Map<String, dynamic>>();
      // Si hay un turno abierto, lo ponemos primero (se mostrará por defecto).
      final abiertoIdx = lista.indexWhere((x) => x['estado'] == 'abierto');
      if (abiertoIdx > 0) {
        final abierto = lista.removeAt(abiertoIdx);
        lista.insert(0, abierto);
      }
      setState(() => _turnos = lista);
    }
  }

  /// Pestaña activa según la pantalla actual (ids de la barra de pestañas
  /// del POS: 0 Nueva comanda, 1 Mesas, 2 Domicilios, 3 Para llevar, 4 Cocina,
  /// 5 Movimientos, 6 Propinas). Devuelve el ID de pantalla, no la posición.
  int _pestanaActiva() {
    switch (_pantalla) {
      case Pantalla.mesas:
        return 1;
      case Pantalla.entregas:
        return 2;
      case Pantalla.paraLlevar:
        return 3;
      case Pantalla.cocina:
        return 4;
      case Pantalla.movimientos:
        return 5;
      case Pantalla.propinas:
        return 6;
      default:
        return 0; // comanda -> Nueva comanda
    }
  }

  /// Carga el orden de pestañas guardado del usuario actual (por email).
  Future<void> _cargarOrdenPestanasPos() async {
    final email = ApiClient.currentEmail ?? 'anon';
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('$_posOrdenKey$email');
    if (raw == null || raw.isEmpty) {
      // Sin preferencia guardada -> orden por defecto.
      if (mounted) setState(() => _ordenPestanasPos = const [0, 1, 2, 3, 4, 5, 6]);
      return;
    }
    // Parsea ids enteros válidos, sin repetir, completando los faltantes.
    final vistos = <int>{};
    final orden = <int>[];
    for (final s in raw) {
      final id = int.tryParse(s);
      if (id != null && id >= 0 && id <= 6 && vistos.add(id)) orden.add(id);
    }
    for (var i = 0; i <= 6; i++) {
      if (vistos.add(i)) orden.add(i);
    }
    if (mounted) setState(() => _ordenPestanasPos = orden);
  }

  Future<void> _guardarOrdenPestanasPos() async {
    final email = ApiClient.currentEmail ?? 'anon';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        '$_posOrdenKey$email', _ordenPestanasPos.map((e) => '$e').toList());
  }

  /// Barra de pestañas visible en TODAS las vistas del POS (Nueva comanda,
  /// Mesas, Domicilios, Para llevar, Cocina, Movimientos de caja, Pago de
  /// propinas) para moverse entre ellas o abrir esas vistas.
  /// Las pestañas son reordenables por arrastre y el orden se persiste por
  /// usuario. SIN records ni for-index: el SDK de Flutter es viejo.
  Widget _barraPestanas() {
    final labels = <String>[
      'Nueva comanda', 'Mesas abiertas', 'Domicilios', 'Para llevar', 'Cocina',
      'Movimientos de caja', 'Pago de propinas',
    ];
    final icons = <IconData>[
      Icons.menu_book,
      Icons.restaurant,
      Icons.local_shipping,
      Icons.takeout_dining,
      Icons.kitchen,
      Icons.swap_horiz,
      Icons.redeem,
    ];
    final scheme = Theme.of(context).colorScheme;
    final activa = _pestanaActiva();
    return Container(
      height: 48,
      color: scheme.surface,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      child: ReorderableListView(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        onReorder: _reordenarPestanasPos,
        children: [
          for (var pos = 0; pos < _ordenPestanasPos.length; pos++)
            _tabPestana(context, pos, _ordenPestanasPos[pos],
                labels[_ordenPestanasPos[pos]], icons[_ordenPestanasPos[pos]], activa),
        ],
      ),
    );
  }

  /// Reordena la lista de pestañas al soltar un arrastre y guarda el orden.
  void _reordenarPestanasPos(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _ordenPestanasPos.removeAt(oldIndex);
      _ordenPestanasPos.insert(newIndex, item);
      _guardarOrdenPestanasPos();
    });
  }

  Widget _tabPestana(BuildContext context, int pos, int id, String label, IconData icon, int activa) {
    final scheme = Theme.of(context).colorScheme;
    final isActiva = activa == id;
    final color = isActiva ? scheme.primary : scheme.onSurfaceVariant;
    return Padding(
      key: ValueKey('pestana_$id'),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ReorderableDelayedDragStartListener(
        index: pos, // índice real de posición en el ReorderableListView
        child: InkWell(
          onTap: () => _navegarPestana(id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isActiva ? scheme.primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActiva ? FontWeight.w700 : FontWeight.w500,
                      color: color)),
            ]),
          ),
        ),
      ),
    );
  }

  /// Envuelve la vista de cada pestaña con la barra superior.
  Widget _vistaConPestanas(Widget cuerpo) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _barraPestanas(),
      const Divider(height: 1),
      Expanded(child: cuerpo),
    ]);
  }

  /// Navega a la vista correspondiente al pulsar una pestaña (recibe el ID de
  /// pantalla, no la posición — el orden visual lo gestiona _ordenPestanasPos).
  void _navegarPestana(int id) {
    if (!mounted) return;
    switch (id) {
      case 0:
        setState(() { _pantalla = Pantalla.comanda; _modoAgregarMesaId = null; });
        return;
      case 1:
        setState(() => _pantalla = Pantalla.mesas);
        _refreshVivos();
        return;
      case 2:
        setState(() => _pantalla = Pantalla.entregas);
        _refreshVivos();
        return;
      case 3:
        setState(() => _pantalla = Pantalla.paraLlevar);
        _refreshVivos();
        return;
      case 4:
        setState(() => _pantalla = Pantalla.cocina);
        return;
      case 5: // Movimientos de caja (requiere turno abierto) — vista DENTRO del POS
        if (_turno == null) { _dialogAbrirCaja(); return; }
        setState(() => _pantalla = Pantalla.movimientos);
        return;
      case 6: // Pago de propinas — vista DENTRO del POS
        setState(() => _pantalla = Pantalla.propinas);
        return;
    }
  }

  /// Actualiza el título del AppBar según la pantalla del POS actual.
  void _pintarTitulo() {
    switch (_pantalla) {
      case Pantalla.comanda:
        AppTitulo.titulo.value = 'Nueva comanda';
        return;
      case Pantalla.mesas:
        AppTitulo.titulo.value = 'Mesas abiertas (${_mesasAbiertas.length})';
        return;
      case Pantalla.entregas:
        AppTitulo.titulo.value = 'Domicilios (${_domicilios.length})';
        return;
      case Pantalla.paraLlevar:
        AppTitulo.titulo.value = 'Para llevar (${_paraLlevar.length})';
        return;
      case Pantalla.cocina:
        AppTitulo.titulo.value = 'Cocina';
        return;
      case Pantalla.movimientos:
        AppTitulo.titulo.value = 'Movimientos de caja';
        return;
      case Pantalla.propinas:
        AppTitulo.titulo.value = 'Pago de propinas';
        return;
      default:
        AppTitulo.titulo.value = 'Nueva comanda';
    }
  }

  Future<bool> _abrirCaja(double efectivoInicial) async {
    setState(() => _cajaCargando = true);
    final r = await ApiClient.cajaAbrir(efectivoInicial);
    if (!mounted) return false;
    setState(() => _cajaCargando = false);
    if (r.ok) {
      _snack('Caja abierta.');
      await _cargarTurno();
      // Al abrir la caja se va a la pantalla de comanda (nueva, vacía).
      if (mounted) setState(() { _modoAgregarMesaId = null; _pantalla = Pantalla.comanda; });
      return true;
    } else {
      _snack(r.message);
      return false;
    }
  }

  /// Abre la caja como ventana emergente (dialog) en vez de una view completa.
  Future<void> _dialogAbrirCaja() async {
    if (_dialogAperturaAbierto) return;
    if (_turno != null) return;
    _dialogAperturaAbierto = true;
    _efectivoApertura = 0;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
            child: StatefulBuilder(
              builder: (ctx, setDlg) {
                return _pantallaAbrirCaja(
                  onAbrir: () async {
                    final ok = await _abrirCaja(_efectivoApertura);
                    if (ok && ctx.mounted) Navigator.of(ctx).pop();
                  },
                  onChange: (t) => _efectivoApertura = t,
                );
              },
            ),
          ),
        ),
      );
    } finally {
      _dialogAperturaAbierto = false;
    }
    // Tras cerrarse el dialog: si ya hay turno abierto, ir a comanda (nueva).
    if (mounted && _turno != null) setState(() { _modoAgregarMesaId = null; _pantalla = Pantalla.comanda; });
  }

  Future<void> _cerrarTurno() async {
    // Gate: no se puede cerrar la caja con mesas abiertas sin cobrar o pedidos
    // pendientes de entrega. Refresca los vivos para tener el estado real.
    await _refreshVivos();
    if (!mounted) return;
    final nMesas = _mesasAbiertas.length;
    final nPendientes = _pendientes.length;
    if (nMesas > 0 || nPendientes > 0) {
      var aviso = 'No se puede cerrar la caja:\n';
      if (nMesas > 0) {
        aviso += '• $nMesas mesas abiertas sin cobrar\n';
      }
      if (nPendientes > 0) {
        aviso += '• $nPendientes pedidos por entregar\n';
      }
      aviso += '\nCuadre y cobre las mesas/pedidos pendientes primero.';
      await _dialogAviso('Cobro pendiente', aviso);
      return;
    }
    final cerrado = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(child: CierreCajaView(turno: _turno!)),
    );
    if (cerrado == true) {
      await _cargarTurno();
      // Al cerrar la caja se vuelve a la comanda (nueva).
      if (mounted) setState(() { _modoAgregarMesaId = null; _pantalla = Pantalla.comanda; });
    }
  }

  /// Diálogo de aviso informativo (un botón "Entendido"), presentable y
  /// centrado con ancho acotado para que se vea bien en móvil y escritorio.
  Future<void> _dialogAviso(String titulo, String mensaje) async {
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_outlined, size: 30, color: scheme.primary),
                ),
                const SizedBox(height: 14),
                Text(titulo,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Entendido'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pantallaAbrirCaja({required Future<void> Function() onAbrir, required ValueChanged<double> onChange}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Abrir caja', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Cuente las cantidades de cada denominación. El total se calcula solo.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            ConteoDenominacion(
              onTotalChanged: (t) { onChange(t); setState(() {}); },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _cajaCargando ? null : onAbrir,
              child: _cajaCargando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Abrir caja y empezar a facturar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)));
    }
    _pintarTitulo();
    // Renderizado por pantalla del flujo POS. TODAS con la barra de pestañas
    // encima para navegar entre ellas (Nueva comanda / Mesas / Domicilios /
    // Para llevar / Cocina). Cocina no requiere caja abierta (preparación).
    // No hay pantalla "inicio" del POS: se entra directo a Nueva comanda y el
    // resto se maneja por las pestañas y el menú lateral.
    switch (_pantalla) {
      case Pantalla.comanda:
        return _vistaConPestanas(_vistaComanda());
      case Pantalla.mesas:
        return _vistaConPestanas(_vistaMesas());
      case Pantalla.entregas:
        return _vistaConPestanas(_vistaEntregas());
      case Pantalla.paraLlevar:
        return _vistaConPestanas(_vistaParaLlevar());
      case Pantalla.cocina:
        return _vistaConPestanas(CocinaView(onVolver: () => setState(() => _pantalla = Pantalla.comanda)));
      case Pantalla.movimientos:
        // Requiere turno abierto; si no, se pide abrir la caja y se queda en
        // Nueva comanda. Movimientos de caja se abre también desde la pestaña.
        if (_turno == null) { _dialogAbrirCaja(); return _vistaConPestanas(_vistaComanda()); }
        return _vistaConPestanas(MovimientosCajaView(turno: _turno!, embebido: true));
      case Pantalla.propinas:
        return _vistaConPestanas(PagoPropinaView(embebido: true));
      default:
        return _vistaConPestanas(_vistaComanda());
    }
  }

  Widget appIcon(IconData i, {double size = 28}) {
    return Icon(i, size: size, color: Theme.of(context).colorScheme.primary);
  }

  // ---------- Etapa 1: Comanda ----------
  Widget _vistaComanda() {
    return ComandaView(
      items: _comanda.toList(),
      total: _totalComanda,
      categorias: _categorias,
      busqueda: _busqueda,
      categoriaSel: _categoriaSel,
      error: _error,
      escenario: _escenario,
      mesas: _mesasAbiertas,
      mesaActiva: _modoAgregarMesaId,
      onAgregar: (it, tam) => _agregar(it, tam),
      onBuscar: (v) => setState(() => _busqueda = v),
      onCategoria: (id) => setState(() => _categoriaSel = id),
      onElegirEscenario: _elegirEscenario,
      onQuitar: _quitarLinea,
      onRestar: _restarLinea,
      onCambiarPrecio: (l, nuevo) => setState(() => l.precio = nuevo),
      onSumar: _sumarLinea,
      onContinuar: _siguienteEtapa,
      onBorrar: _borrarComanda,
      onVolver: () => setState(() => _pantalla = Pantalla.comanda),
      turnoAbierto: _turno != null,
      onCerrarTurno: () => _cerrarTurno(),
      onAgregarMesa: (m) async {
        // Opción C: volver a tocar el tab de la mesa activa = comanda nueva vacía;
        // tocar otra mesa = cargar sus productos en modo "agregar".
        if (_modoAgregarMesaId == (m['id'] as int?)) {
          _limpiarComanda();
        } else {
          await _refreshVivos();
          await _agregarProductoMesa(m);
        }
      },
    );
  }

  /// Borra por completo la línea de la comanda.
  void _quitarLinea(Linea l) {
    setState(() => _comanda.remove(l));
    _guardarComanda();
  }

  /// Disminuye en 1 la cantidad; si llega a 0 se borra la línea.
  void _restarLinea(Linea l) {
    setState(() {
      if (l.cantidad > 1) l.cantidad--;
      else _comanda.remove(l);
    });
    _guardarComanda();
  }

  void _sumarLinea(Linea l) {
    setState(() => l.cantidad++);
    _guardarComanda();
  }

  // ---------- Mesas abiertas ----------
  Widget _vistaMesas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_mesasAbiertas.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No hay mesas abiertas.', style: TextStyle(color: Colors.grey))),
        for (final m in _mesasAbiertas) _mesaCard(m),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: () { setState(() { _modoAgregarMesaId = null; _pantalla = Pantalla.comanda; }); }, icon: const Icon(Icons.menu_book), label: const Text('Nueva comanda')),
      ]),
    );
  }

  /// Agrupa los ítems de una mesa por producto+tamaño (suma cantidades), para
  /// no mostrar duplicados heredados en la BD como líneas separadas.
  List<Map<String, dynamic>> _itemsMesaAgrupados(List<Map<String, dynamic>> items) {
    final porClave = <String, Map<String, dynamic>>{};
    for (final it in items) {
      final idP = (it['id_producto'] ?? it['id']);
      final tam = it['tamanio'] as String?;
      final clave = '$idP|$tam';
      final cant = (it['cantidad'] as int?) ?? 1;
      if (porClave.containsKey(clave)) {
        final existente = porClave[clave]!;
        existente['cantidad'] = ((existente['cantidad'] as int?) ?? 0) + cant;
      } else {
        porClave[clave] = {
          'nombre': it['nombre'] ?? '',
          'tamanio': tam,
          'cantidad': cant,
          'nota': it['nota'] as String? ?? '',
        };
      }
    }
    return porClave.values.toList();
  }

  Widget _mesaCard(Map<String, dynamic> m) {
    final id = m['id'] as int;
    final items = (m['items'] as List? ?? []).cast<Map<String, dynamic>>();
    final total = numVal(m['total']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            appIcon(Icons.restaurant, size: 22),
            const SizedBox(width: 8),
            Flexible(child: Text('Mesa ${m['numero_mesa'] ?? m['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            const SizedBox(width: 8),
            Text(money(total), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ..._itemsMesaAgrupados(items).map((i) => Text(
          '• ${i['nombre']}${i['tamanio'] != null ? ' (${i['tamanio']})' : ''} ×${i['cantidad']}${i['nota'] != null ? ' — ${i['nota']}' : ''}',
          style: const TextStyle(fontSize: 13),
        )),
        const SizedBox(height: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [
          OutlinedButton(onPressed: () async { await _agregarProductoMesa(m); }, child: const Text('Agregar')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () async { await _dialogPagarPedido(id, montoMostrar: total); }, child: const Text('Pedir la cuenta')),
          const SizedBox(width: 8),
          // Anular mesa: el cajero pide aprobación; admin/encargado/superadmin
          // pueden aprobarla con su contraseña. Siempre se muestra el botón.
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async { await _anularMesa(id, 'Mesa ${m['numero_mesa'] ?? m['id']}', total); },
            child: const Text('Anular'),
          ),
        ]),
      ]),
    );
  }

  Future<void> _agregarProductoMesa(Map<String, dynamic> m) async {
    // Va a la comanda en modo "agregar a esta mesa": carga los productos que la
    // mesa YA tiene ordenados (para ver el contexto) y al continuar se añaden
    // los nuevos al pedido existente (sin pasar por la asignación).
    // AGRUPA por producto+tamaño: si la BD tiene el mismo ítem en varias líneas
    // (duplicados heredados), se suman en una sola línea con su cantidad total.
    setState(() {
      _comanda.clear();
      final porClave = <String, Linea>{};
      for (final it in (m['items'] as List? ?? []).cast<Map<String, dynamic>>()) {
        final idP = (it['id_producto'] ?? it['id']) as int;
        final tam = it['tamanio'] as String?;
        final clave = '$idP|$tam';
        final cant = (it['cantidad'] as int?) ?? 1;
        if (porClave.containsKey(clave)) {
          porClave[clave]!.cantidad += cant;
        } else {
          porClave[clave] = Linea(
            idProducto: idP,
            nombre: it['nombre'] ?? '',
            tamanio: tam,
            precio: numVal(it['precio_unitario'] ?? it['precio']),
            cantidad: cant,
            nota: it['nota'] as String? ?? '',
            yaEnMesa: true,
          );
        }
      }
      _comanda.addAll(porClave.values);
      _modoAgregarMesaId = m['id'] as int?;
      _pantalla = Pantalla.comanda;
    });
  }

  Future<Map<String, dynamic>?> _dialogElegirProducto(String titulo) async {
    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final it in _todosItems())
                Padding(padding: const EdgeInsets.only(right: 8), child: SizedBox(width: 150, child: _productoMini(it))),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _todosItems() =>
      _categorias.expand((c) => (c['items'] as List? ?? []).cast<Map<String, dynamic>>()).cast<Map<String, dynamic>>().toList();

  Widget _productoMini(Map<String, dynamic> it) {
    return FilledButton(
      onPressed: () => Navigator.pop(context, it),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(it['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          Text(money(it['precio_personal'] ?? it['precio']), style: const TextStyle(fontSize: 11)),
        ]),
      ),
    );
  }

  Future<String?> _dialogTamanio(Map<String, dynamic> it) async {
    return showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(it['nombre'] ?? ''),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: const Text('Personal'), subtitle: Text(money(it['precio_personal'])), onTap: () => Navigator.pop(context, 'personal')),
          ListTile(title: const Text('Mediana'), subtitle: Text(money(it['precio_mediana'])), onTap: () => Navigator.pop(context, 'mediana')),
          ListTile(title: const Text('Grande'), subtitle: Text(money(it['precio_grande'])), onTap: () => Navigator.pop(context, 'grande')),
        ]),
      ),
    );
  }

  // ---------- Domicilios (antes "Pedidos por entregar") ----------
  Widget _vistaEntregas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: () async { await _refreshVivos(); }),
          ]),
        const SizedBox(height: 8),
        if (_domicilios.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No hay domicilios.', style: TextStyle(color: Colors.grey))),
        for (final p in _domicilios) _pendienteCard(p),
      ]),
    );
  }

  // ---------- Para llevar (pestaña de la comanda) ----------
  // Fondo completo por estado de pago: TURQUESA = pagada (pagada_pendiente),
  // TERRACOTA = por pagar (abierta). Así se distingue de un vistazo.
  Widget _vistaParaLlevar() {
    // Sin fila de leyenda ni icono de actualizar: hay túnel de tiempo real
    // (comanda:nueva -> _refreshVivos) y el estado PAGADA/POR PAGAR ya lo marca
    // el badge de cada tarjeta.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_paraLlevar.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('No hay pedidos para llevar.', style: TextStyle(color: Colors.grey))),
        for (final p in _paraLlevar) _pendienteCard(p, paraLlevar: true),
      ]),
    );
  }

  /// Tarjeta de pedido (domicilio o para llevar). En para llevar el FONDO
  /// completo marca el estado: turquesa pagada / terracota por pagar. Botones
  /// contextuales: cobrar (si abierta) o marcar entregado (si pagada).
  Widget _pendienteCard(Map<String, dynamic> p, {bool paraLlevar = false}) {
    final esDomicilio = p['escenario'] == 'domicilio';
    final estado = (p['estado'] ?? '').toString();
    final pagada = estado == 'pagada_pendiente';
    final nombre = (p['cliente_nombre'] ?? p['numero_mesa'] ?? '').toString();
    final transcurrido = _tiempoTranscurrido((p['hora_pedido'] ?? '').toString());
    Color fondo; Color borde; Color texto;
    if (paraLlevar) {
      // Fondo completo por estado de pago.
      fondo = pagada ? const Color(0xFFD6F2EE) /* turquesa claro */ : const Color(0xFFF6E0CD) /* terracota claro */;
      borde = pagada ? const Color(0xFF26A69A) : const Color(0xFFD2691E);
      texto = Colors.black87;
    } else {
      fondo = esDomicilio ? Colors.orange.shade100 : Colors.green.shade100;
      borde = esDomicilio ? Colors.orange.shade400 : Colors.green.shade400;
      texto = Colors.black87;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fondo,
        border: Border.all(color: borde),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            appIcon(esDomicilio ? Icons.local_shipping : Icons.takeout_dining, size: 22),
            const SizedBox(width: 8),
            Flexible(child: Text(esDomicilio ? 'Domicilio' : 'Para llevar', style: TextStyle(fontWeight: FontWeight.bold, color: texto))),
            const SizedBox(width: 8),
            Text(transcurrido, style: TextStyle(fontWeight: FontWeight.bold, color: texto)),
            const SizedBox(width: 8),
            // Badge de estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: borde, borderRadius: BorderRadius.circular(10)),
              child: Text(pagada ? 'PAGADA' : 'POR PAGAR', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('Cliente: $nombre', style: TextStyle(fontWeight: FontWeight.w600, color: texto)),
        if (p['direccion'] != null) Text('Dirección: ${p['direccion']}', style: TextStyle(fontSize: 13, color: texto)),
        Text('Total: ${money(numVal(p['total']))}', style: TextStyle(fontWeight: FontWeight.w600, color: texto)),
        if (p['numero_factura'] != null) Text('Factura: ${p['numero_factura']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        // Botón contextual: cobrar si abierta (por pagar), entregar si pagada.
        if (!pagada)
          FilledButton.icon(
            onPressed: () async => _dialogPagarPedido(p['id'] as int, montoMostrar: numVal(p['total'])),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Cobrar'),
          )
        else
          FilledButton.icon(
            onPressed: () async {
              final ok = await _dialogConfirm('¿Marcar como entregado?');
              if (ok == true) {
                final r = await ApiClient.entregarPedido(p['id'] as int);
                _snack(r.message);
                await _refreshVivos();
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Marcar entregado'),
          ),
      ]),
    );
  }

  String _tiempoTranscurrido(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    final min = diff.inMinutes;
    if (min < 1) return 'ahora';
    return '${min.toString()} min';
  }

  // ---------- Anulación de mesa / pedido ----------
  bool get _puedeAprobarAnulacion =>
      ApiClient.hasPermiso('pedidos:anular') ||
      ['superadmin', 'admin', 'encargado'].contains(ApiClient.currentRol);

  /// Punto de entrada del botón "Anular" de una mesa abierta:
  /// - Superadmin/admin/encargado (permiso pedidos:anular): pedir motivo +
  ///   su contraseña y anular en el momento.
  /// - Cajero (sin permiso): pedir motivo y SOLICITAR aprobación; un
  ///   admin/encargado la recibe por tiempo real y la aprueba con su clave.
  Future<void> _anularMesa(int pedidoId, String nombre, double total) async {
    if (!_puedeAprobarAnulacion) {
      // Cajero: solo escribe el motivo y se envía la solicitud.
      final solicitud = await _dialogMotivo(nombre, total, aprobador: false);
      if (solicitud == null) return;
      final r = await ApiClient.solicitarAnulacionPedido(pedidoId, solicitud.motivo);
      _snack(r.ok ? 'Solicitud de anulación enviada para aprobación.' : r.message);
      return;
    }
    // Aprobador: motivo + contraseña para autorizar en el momento.
    final clave = await _dialogMotivo(nombre, total, aprobador: true);
    if (clave == null) return;
    final r = await ApiClient.anularPedido(pedidoId, clave.password);
    _snack(r.ok ? '$nombre anulada correctamente.' : r.message);
    if (r.ok) await _refreshVivos();
  }

  /// Diálogo para el cajero (solo motivo -> solicita) o para el aprobador
  /// (motivo + contraseña -> autoriza). Devuelve null si cancela.
  Future<_MotivoAnulacion?> _dialogMotivo(String nombre, double total,
      {required bool aprobador}) async {
    final motivoCtrl = TextEditingController();
    final claveCtrl = TextEditingController();
    // StatefulBuilder para que el botón se habilite/deshabilite en VIVO al
    // escribir (un showDialog estático evalúa el onPressed una sola vez y el
    // botón queda congelado en su estado inicial).
    return showDialog<_MotivoAnulacion>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final motivoOk = motivoCtrl.text.trim().isNotEmpty;
          final claveOk =
              !aprobador || claveCtrl.text.trim().isNotEmpty;
          final puedeEnviar = motivoOk && claveOk;
          return AlertDialog(
            title: Row(children: [
              Icon(aprobador ? Icons.verified_user : Icons.help_outline, size: 22),
              const SizedBox(width: 8),
              const Text('Anular mesa'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('$nombre — Total ${money(total)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: motivoCtrl,
                  autofocus: true,
                  maxLines: 3,
                  onChanged: (_) => setDlg(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Motivo de la anulación',
                    hintText: 'Explique por qué se anula la comanda / mesa…',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (aprobador) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: claveCtrl,
                    obscureText: true,
                    onChanged: (_) => setDlg(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Contraseña del aprobador',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(
                onPressed: puedeEnviar
                    ? () => Navigator.pop(ctx,
                        _MotivoAnulacion(motivoCtrl.text.trim(), aprobador ? claveCtrl.text : ''))
                    : null,
                child: Text(aprobador ? 'Aprobar y anular' : 'Solicitar aprobación'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Notificación por tiempo real al aprobador (superadmin/admin/encargado):
  /// un cajero pidió anular una mesa. Muestra el motivo y pide su contraseña.
  Future<void> _dialogAprobarAnulacion(
      int pedidoId, String nombre, dynamic total, String motivo) async {
    final claveCtrl = TextEditingController();
    final nombreShow = nombre.isEmpty ? 'Pedido #$pedidoId' : nombre;
    final aprobar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final puedeAprobar = claveCtrl.text.trim().isNotEmpty;
          return AlertDialog(
            title: const Row(children: [
              Icon(Icons.warning_amber_outlined, size: 22),
              SizedBox(width: 8),
              Text('Aprobación de anulación'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('$nombreShow — Total ${money(numVal(total))}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Motivo del cajero:'),
                Text(motivo.isEmpty ? '(sin motivo)' : motivo,
                    style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 12),
                // Un solo recuadro: el aprobador (quien recibe) digita su clave.
                TextField(
                  controller: claveCtrl,
                  obscureText: true,
                  autofocus: true,
                  onChanged: (_) => setDlg(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Tu contraseña para aprobar',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Rechazar')),
              FilledButton(
                onPressed: puedeAprobar ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Aprobar y anular'),
              ),
            ],
          );
        },
      ),
    );
    if (aprobar != true) return;
    final r = await ApiClient.anularPedido(pedidoId, claveCtrl.text);
    _snack(r.ok ? '$nombreShow anulada correctamente.' : r.message);
    if (r.ok) await _refreshVivos();
  }

  // ---------- Dialogs ----------
  Future<String?> _dialogNota(String titulo) async {
    final c = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(labelText: 'Nota (opcional)', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Aceptar')),
        ],
      ),
    );
  }

  Future<bool?> _dialogConfirm(String msg) async {
    return showDialog<bool?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
        ],
      ),
    );
  }

  Future<void> _gestionarFormas() async {
    final nombre = await _dialogNota('Nueva forma de pago');
    if (nombre != null && nombre.trim().isNotEmpty) {
      final r = await ApiClient.crearFormaPago(nombre.trim());
      _snack(r.message);
      await _load();
    }
  }
}

/// Resultado del diálogo de anulación: motivo + contraseña (del aprobador).
class _MotivoAnulacion {
  final String motivo;
  final String password;
  const _MotivoAnulacion(this.motivo, this.password);
}

/// Holder mutable del escenario elegido en el diálogo de comandar. Necesario
/// porque el builder es re-invocado por setDlg y no se puede reasignar la
/// variable local capturada directamente dentro de un cierre en este SDK.
class _EscenarioSel {
  String esc;
  _EscenarioSel(this.esc);
}