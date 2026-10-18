import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../../core/data/api_client.dart';
import '../../core/utils/formatters.dart';

/// Module 3 — Resumen contable (haber/deber).
///
/// Muestra el cruce ventas (ingresos) vs gastos (facturas) y los movimientos
/// de dinero (comprobantes de pago) para un período seleccionable (chips
/// semana/mes/año + rango libre por calendario). Calcula la utilidad
/// = ventas − facturas.
///
/// Concilación factura↔comprobante: facturas con comprobante vinculado se
/// marcan como conciliadas; las demás quedan con un botón para asignar
/// manualmente el comprobante (trasabilidad del pago de cada factura).
class SummariesView extends StatefulWidget {
  const SummariesView({super.key});

  @override
  State<SummariesView> createState() => _SummariesViewState();
}

class _SummariesViewState extends State<SummariesView> {
  String _periodo = 'mes';
  String? _referencia;
  DateTimeRange? _rango;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  // Selectores colapsables
  final Set<String> _abiertos = {};

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _elegirRango() async {
    final hoy = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: hoy,
      initialDateRange:
          _rango ?? DateTimeRange(start: DateTime(hoy.year, hoy.month - 1, 1), end: hoy),
      helpText: 'Elegir período',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      saveText: 'Aplicar',
    );
    if (picked == null || !mounted) return;
    setState(() => _rango = picked);
    await _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    final r = _rango != null
        ? await ApiClient.obtenerContable(
            periodo: 'rango', desde: _fmt(_rango!.start), hasta: _fmt(_rango!.end))
        : await ApiClient.obtenerContable(periodo: _periodo, referencia: _referencia);
    if (!mounted) return;
    final (ok, data, msg) = r;
    setState(() {
      _loading = false;
      if (ok) { _data = data; _error = null; } else { _data = null; _error = msg; }
    });
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0.0;
    return 0.0;
  }

  List<dynamic> _list(dynamic v) => v is List ? v as List : [];

  Future<void> _asignarComprobante(Map<String, dynamic> factura) async {
    final comprobantes = _list(_data?['comprobantes_detalle']);
    final pendientes =
        comprobantes.where((c) => !((c as Map?)?['conciliado'] == true)).toList();
    if (pendientes.isEmpty) {
      _aviso('No hay comprobantes sin asignar en este período.');
      return;
    }
    final elegido = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Vincular comprobante a la factura',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            for (final c in pendientes)
              ListTile(
                title: Text('${(c as Map)['referencia'] ?? 'Comp. ${c['id']}'}'),
                subtitle: Text('${c['fecha'] ?? ''} · ${money(_num(c['monto']))}'),
                trailing: const Icon(Icons.link),
                onTap: () => Navigator.of(ctx).pop(c['id'] as int),
              ),
          ],
        ),
      ),
    );
    if (elegido == null || !mounted) return;
    final (ok, msg) = await ApiClient.asignarComprobante(factura['id'] as int, elegido);
    if (!mounted) return;
    _aviso(ok ? '✓ $msg' : 'Error: $msg');
    if (ok) await _cargar();
  }

  void _aviso(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Guarda la clasificación manual de un comprobante y refresca.
  Future<void> _clasificar(
      Map<String, dynamic> item, String? tipo, BuildContext dlgCtx) async {
    final (ok, msg) =
        await ApiClient.clasificarComprobante(item['id'] as int, tipo);
    if (!mounted) return;
    _aviso(ok ? '✓ $msg' : 'Error: $msg');
    if (ok) {
      Navigator.of(dlgCtx).pop();
      await _cargar();
    }
  }

  /// Muestra una ventana emergente con los datos completos de una fila
  /// (factura o comprobante) cuando la tabla no alcanza a mostrarlos todos.
  void _verDetalle(Map<String, dynamic> item, String titulo,
      {bool esComprobante = false}) {
    final amarillo = Theme.of(context).colorScheme.onSurface;
    final labels = <String, String>{
      'fecha': 'Fecha',
      'numero_factura': 'N° Factura',
      'proveedor': 'Proveedor',
      'beneficiario': 'Beneficiario',
      'referencia': 'Referencia',
      'concepto': 'Concepto',
      'metodo_pago': 'Método de pago',
      'metodo_pago_ultimos4': 'Últimos 4 dígitos del pago',
      'moneda': 'Moneda',
      'estado': 'Estado',
    };
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _grisRoca, width: 1.5),
        ),
        title: Text(titulo,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Imagen del comprobante/factura si está guardada.
              if (item['archivo_url'] != null) ...[
                InkWell(
                  onTap: () => showDialog<void>(
                    context: ctx,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.black,
                      child: InteractiveViewer(
                        child: Image.network(
                          '${item['archivo_url']}',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No se pudo cargar la imagen.',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
                      child: Image.network(
                        '${item['archivo_url']}',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              for (final e in labels.entries)
                if (item[e.key] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: '${e.value}:  ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        TextSpan(
                          text: '${item[e.key]}' == 'null'
                              ? '—'
                              : '${item[e.key]}',
                          style: TextStyle(color: amarillo, fontSize: 13),
                        ),
                      ]),
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: RichText(
                  text: TextSpan(children: [
                    const TextSpan(
                      text: 'Monto:  ',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    TextSpan(
                      text: money(_num(item['monto'])),
                      style: TextStyle(color: amarillo, fontSize: 14),
                    ),
                  ]),
                ),
              ),
              if (esComprobante) ...[
                const Divider(height: 20),
                Text('Clasificación',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13, color: amarillo)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  ChoiceChip(
                    label: const Text('Transferencia'),
                    selected: item['tipo'] == 'transferencia',
                    onSelected: (_) =>
                        _clasificar(item, 'transferencia', ctx),
                  ),
                  ChoiceChip(
                    label: const Text('Proveedor'),
                    selected: item['tipo'] == 'proveedor',
                    onSelected: (_) => _clasificar(item, 'proveedor', ctx),
                  ),
                  if (item['tipo_manual'] != null)
                    ActionChip(
                      label: const Text('Automático'),
                      onPressed: () => _clasificar(item, null, ctx),
                    ),
                ]),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _toggle(String key) => setState(() {
        if (_abiertos.contains(key)) {
          _abiertos.remove(key);
        } else {
          _abiertos.add(key);
        }
      });

  /// Carga una imagen de factura/comprobante desde el dispositivo, la sube al
      /// backend (que corre OCR) y muestra el texto extraído para que la persona
      /// lo revise/corrija. herb puede seguir haciendo esto por su cuenta; este
      /// botón permite hacerlo desde la interfaz sin depender de herb.
      Future<void> _cargarImagenOcr() async {
        // Elegir a qué carpeta va (replica la estructura de Lenovo).
        final tipo = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _grisRoca, width: 1.5),
            ),
            title: const Text('¿Qué vas a cargar?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: const Text('Factura'),
                  onTap: () => Navigator.of(ctx).pop('factura'),
                ),
                ListTile(
                  leading: const Icon(Icons.payments),
                  title: const Text('Comprobante de pago'),
                  onTap: () => Navigator.of(ctx).pop('comprobante_pago'),
                ),
                ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: const Text('Comprobante de transferencia'),
                  onTap: () => Navigator.of(ctx).pop('comprobante_transferencia'),
                ),
              ],
            ),
          ),
        );
        if (tipo == null || !mounted) return;

        const xTipo = XTypeGroup(
          label: 'Imágenes',
          extensions: ['png', 'jpg', 'jpeg', 'webp'],
        );
        final XFile? archivo = await openFile(acceptedTypeGroups: [xTipo]);
        if (archivo == null) return;
        final bytes = await archivo.readAsBytes();
        _aviso('Procesando imagen (OCR)…');
        final (ok, msg, data) =
            await ApiClient.subirImagenOcr(bytes, archivo.name, tipo: tipo);
        if (!mounted) return;
        if (!ok) {
          _aviso('Error OCR: $msg');
          return;
        }
        if (!mounted) return;
        final texto = (data?['texto'] as String?) ?? '';
        final archivoOk = (data?['archivo'] as String?) ?? '';
        // Abrir el formulario de alta con el texto OCR cargado.
        await _crearDesdeOcr(tipo, texto, archivoOk);
      }

  /// Abre un formulario para crear la factura/comprobante desde el texto OCR.
  /// Pre-rellena los campos detectados (proveedor/beneficiario, fecha, total,
  /// referencia/numero) y crea el registro vía la API vinculando el archivo.
  Future<void> _crearDesdeOcr(
      String tipo, String texto, String archivo) async {
    // Detección básica de campos desde el texto OCR (mejorable, editable).
    final esFactura = tipo == 'factura';
    final proveedor = _detectarProveedor(texto);
    final fecha = _detectarFecha(texto);
    final total = _detectarTotal(texto);
    final referencia =
        esFactura ? _detectarNumero(texto) : _detectarReferencia(texto);

    final controlProveedor = TextEditingController(text: proveedor);
    final controlFecha = TextEditingController(text: fecha);
    final controlTotal = TextEditingController(text: total);
    final controlReferencia = TextEditingController(text: referencia);

    final guardador = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _grisRoca, width: 1.5),
        ),
        title: Text(esFactura ? 'Crear factura' : 'Crear comprobante'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  texto.isEmpty ? '(sin texto detectado)' : texto,
                  style: const TextStyle(fontSize: 11, height: 1.3),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controlProveedor,
                decoration: InputDecoration(
                  labelText: esFactura ? 'Proveedor' : 'Beneficiario / emisor',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controlFecha,
                decoration: const InputDecoration(
                  labelText: 'Fecha (YYYY-MM-DD)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controlTotal,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Total',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controlReferencia,
                decoration: InputDecoration(
                  labelText: esFactura ? 'N° factura' : 'Referencia',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (guardador != true || !mounted) return;

    final payload = <String, dynamic>{
      if (esFactura) 'proveedor': controlProveedor.text.trim() else 'beneficiario_emisor': controlProveedor.text.trim(),
      'fecha': controlFecha.text.trim(),
      'total_con_impuestos': double.tryParse(controlTotal.text.trim().replaceAll(',', '.')) ?? 0,
      if (esFactura) 'numero_factura': controlReferencia.text.trim() else 'referencia': controlReferencia.text.trim(),
      'archivo': archivo,
    };
    _aviso('Guardando…');
    final res = esFactura
        ? await ApiClient.crearFactura(payload)
        : await ApiClient.crearComprobante(payload);
    if (!mounted) return;
    _aviso(res.ok ? '✓ ${esFactura ? 'Factura' : 'Comprobante'} guardado' : 'Error: ${res.message}');
    if (res.ok) await _cargar();
  }

  // ---- Detección simple de campos desde el texto OCR ----

  String _detectarProveedor(String t) {
    // Antes de un total/fecha suele ir el emisor; tomamos una línea con
    // mayúsculas larga. Fallback vacío.
    final lineas =
        t.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    for (final l in lineas) {
      if (RegExp(r'[A-ZÁÉÍÓÚÑ]{4,}').hasMatch(l) &&
          !l.contains('BANCOLOMBIA') &&
          !l.contains('Nequi')) {
        return l;
      }
    }
    return '';
  }

  String _detectarFecha(String t) {
    final m = RegExp(r'(\d{2}[/-]\d{2}[/-]\d{2,4})').firstMatch(t);
    return m?.group(1)?.replaceAll('/', '-') ?? '';
  }

  String _detectarTotal(String t) {
    final m = RegExp(r'VALOR\s*(?:CONSIGNACION|CONSIGNADO|TOTAL)?[\s:]*\$?\s?([\d.,]+)')
        .firstMatch(t);
    if (m != null) return m.group(1) ?? '';
    final m2 = RegExp(r'\$[\s]?([\d.,]+)').firstMatch(t);
    return m2?.group(1) ?? '';
  }

  String _detectarNumero(String t) {
    final m = RegExp(r'(\w{1,3}[- ]?\d{3,})').firstMatch(t);
    return m?.group(1) ?? '';
  }

  String _detectarReferencia(String t) {
    final m = RegExp(r'(?:TRANS[.]?|CONSIGNACION|REF|REFERENCIA)[\s:]*([A-Z0-9_-]+)')
        .firstMatch(t);
    return m?.group(1) ?? '';
  }

  // Cabecera de tabla (PC/tablet).
  Widget _th(ColorScheme cs, String t, {bool alinear = false}) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          t,
          textAlign: alinear ? TextAlign.right : TextAlign.left,
          style: TextStyle(
              fontWeight: FontWeight.w700, color: cs.onSurface, fontSize: 12),
        ),
      );

  // Celda de tabla (PC/tablet).
  Widget _td(ColorScheme cs, String t,
          {bool negrita = false, bool alinear = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          t,
          textAlign: alinear ? TextAlign.right : TextAlign.left,
          style: TextStyle(
              fontSize: 12,
              color: color ?? cs.onSurface,
              fontWeight: negrita ? FontWeight.w600 : FontWeight.normal),
        ),
      );

  // Gris roca para bordes de las cards.
  static const Color _grisRoca = Color(0xFF7D7D7D);

  // Tarjeta KPI genérica: fondo de color, textos/iconos en amarillo pálido y
  // borde gris roca.
  Widget _kpiCard(String etiqueta, double valor, IconData icon,
      {required Color fondo}) {
    final amarillo = Theme.of(context).colorScheme.onSurface; // amarillo pálido
    return Material(
      color: fondo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _grisRoca, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: amarillo),
              const SizedBox(height: 6),
              Text(money(valor),
                  style: TextStyle(
                      color: amarillo, fontWeight: FontWeight.bold, fontSize: 15),
                  textAlign: TextAlign.center),
              const SizedBox(height: 2),
              Text(etiqueta,
                  style: TextStyle(color: amarillo, fontSize: 11),
                  textAlign: TextAlign.center),
            ]),
      ),
    );
  }

  // Panel colapsable: total + detalle (método de clase). Borde gris roca.
  Widget _panel(String titulo, String resumen, IconData icon, List<Widget> filas) {
    final cs = Theme.of(context).colorScheme;
    final amarillo = cs.onSurface; // amarillo pálido
    final abierto = _abiertos.contains(titulo);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _grisRoca, width: 1.5),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: cs.primary),
        title: Text(titulo,
            style: TextStyle(color: amarillo, fontWeight: FontWeight.w600)),
        subtitle: Text(resumen, style: TextStyle(color: amarillo, fontSize: 12)),
        initiallyExpanded: abierto,
        onExpansionChanged: (_) => _toggle(titulo),
        children: filas,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borde = 20.0;
    final gap = 16.0;

    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final p in ['semana', 'mes', 'año'])
          ChoiceChip(
            label: Text(p),
            selected: _rango == null && _periodo == p,
            shape: const StadiumBorder(),
            onSelected: (_) => setState(() {
              _periodo = p;
              _rango = null;
              _referencia = null;
              _cargar();
            }),
          ),
        IconButton(
          icon: const Icon(Icons.calendar_month),
          tooltip: 'Elegir período (rango)',
          onPressed: _elegirRango,
        ),
        // Cargar imagen de factura/comprobante con OCR (sin depender de herb).
        TextButton.icon(
          onPressed: _cargarImagenOcr,
          icon: const Icon(Icons.add_a_photo, size: 18),
          label: const Text('Cargar imagen (OCR)'),
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: _grisRoca, width: 1),
            ),
          ),
        ),
      ],
    );

    final contenido = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Padding(
                padding: EdgeInsets.all(borde),
                child: Text('Error: $_error',
                    style: const TextStyle(color: Colors.red)))
            : _data == null
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Sin datos aún.',
                        style: TextStyle(color: Colors.grey)))
                : _buildResumen(context, gap);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(borde, 8, borde, 16),
      // En pantallas grandes (PC/tablet) limitamos el ancho del contenido para
      // que la tarjeta de utilidad no se estire y se vea vacía; se centra.
      child: LayoutBuilder(builder: (ctx, c) {
        final maxContenido = c.maxWidth >= 720 ? 900.0 : double.infinity;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContenido),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Resumen contable',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Periodo: ${(_data?['etiqueta'] ?? '')}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                SizedBox(height: gap),
                chips,
                SizedBox(height: gap),
                contenido,
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildResumen(BuildContext context, double gap) {
    final cs = Theme.of(context).colorScheme;
    final ventas = _num(_data?['ventas']?['monto']);
    final facturas = _num(_data?['facturas']?['monto']);
    final comprobantes = _num(_data?['comprobantes']?['monto']);
    final utilidad = _num(_data?['utilidad']);
    final nVentas = _num(_data?['ventas']?['count']).toInt();
    final nFacturas = _num(_data?['facturas']?['count']).toInt();
    final nComprobantes = _num(_data?['comprobantes']?['count']).toInt();

    final facturasDetalle = _list(_data?['facturas_detalle']);
    final comprobantesDetalle = _list(_data?['comprobantes_detalle']);

    final amarilloTxt = cs.onSurface; // amarillo pálido para celdas
    const turquesa = Color(0xFF2FB9A6);

    // ── Tablas: miden el ancho disponible y deciden lista (móvil) vs tabla
    //    (PC/tablet) que ocupa todo el ancho de pantalla.

    // Lista (móvil): cards apiladas de facturas.
    Widget _listaFacturas() => Column(
          children: [
            for (final f in facturasDetalle)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                  onTap: () => _verDetalle(f, 'Detalle factura'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text('${f['proveedor'] ?? '—'}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: amarilloTxt)),
                        ),
                        Text(money(_num(f['monto'])),
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: amarilloTxt)),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                          'N° ${f['numero_factura'] ?? '—'} · ${f['fecha'] ?? ''}'
                          ' · ${f['metodo_pago_ultimos4'] != null ? 'Últ.4 ${f['metodo_pago_ultimos4']}' : ''}',
                          style: TextStyle(
                              fontSize: 11, color: amarilloTxt.withValues(alpha: 0.85))),
                      if (f['conciliada'] == true)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('Conciliada',
                              style:
                                  TextStyle(color: Colors.green, fontSize: 11)),
                        )
                      else
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _asignarComprobante(f),
                            icon: const Icon(Icons.link, size: 14),
                            label: const Text('Asignar',
                                style: TextStyle(fontSize: 11)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );

    // Tabla (PC/tablet): ocupa el ancho disponible, cabecera y filas completas.
    Widget _tablaFacturas() => Table(
          border: TableBorder.all(color: cs.outlineVariant, width: 1),
          columnWidths: const {
            0: FlexColumnWidth(2.8),
            1: FlexColumnWidth(1.4),
            2: FlexColumnWidth(1.4),
            3: FlexColumnWidth(1.3),
            4: FlexColumnWidth(1.0),
            5: FlexColumnWidth(1.6),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(color: cs.surfaceContainerHighest),
              children: [
                _th(cs, 'Proveedor'),
                _th(cs, 'N° Factura'),
                _th(cs, 'Fecha'),
                _th(cs, 'Monto', alinear: true),
                _th(cs, 'Últ. 4'),
                _th(cs, 'Estado'),
              ],
            ),
            for (final f in facturasDetalle)
              TableRow(
                children: [
                  _td(cs, '${f['proveedor'] ?? '—'}', negrita: true),
                  _td(cs, '${f['numero_factura'] ?? ''}'),
                  _td(cs, '${f['fecha'] ?? ''}'),
                  _td(cs, money(_num(f['monto'])), alinear: true, negrita: true),
                  _td(cs, '${f['metodo_pago_ultimos4'] ?? '—'}'),
                  (f['conciliada'] == true)
                      ? _td(cs, 'Conciliada', color: Colors.green)
                      : Padding(
                          padding: const EdgeInsets.all(4),
                          child: TextButton.icon(
                            onPressed: () => _asignarComprobante(f),
                            icon: const Icon(Icons.link, size: 14),
                            label: const Text('Asignar',
                                style: TextStyle(fontSize: 11)),
                          ),
                        ),
                ],
              ),
          ],
        );

    // Facturas: miden el ancho; <640 => lista, sino tabla a todo el ancho.
    final tablaFacturas = facturasDetalle.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Sin facturas en el período.',
                style: TextStyle(color: Colors.grey)))
        : LayoutBuilder(builder: (ctx, c) {
            return c.maxWidth < 640 ? _listaFacturas() : _tablaFacturas();
          });

    // ── Comprobantes: 2 bloques titulados (Pagos a proveedores primero,
    //    Transferencias después). Cada bloque en lista (móvil) o tabla (PC/tablet).

    final comprobantesProveedores = comprobantesDetalle
        .where((c) => c['tipo'] != 'transferencia')
        .toList();
    final comprobantesTransferencias = comprobantesDetalle
        .where((c) => c['tipo'] == 'transferencia')
        .toList();

    double suma(List<dynamic> l) =>
        l.fold(0.0, (s, c) => s + _num((c as Map)['monto']));

    // Lista (móvil): cards apiladas de un bloque de comprobantes.
    Widget _listaComprobantes(List<dynamic> lista) => Column(
          children: [
            for (final c in lista)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                  onTap: () =>
                      _verDetalle(c, 'Detalle comprobante', esComprobante: true),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text('${c['referencia'] ?? 'Comp. ${c['id']}'}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: amarilloTxt)),
                        ),
                        Text(money(_num(c['monto'])),
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: amarilloTxt)),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                          '${c['fecha'] ?? ''}'
                          '${c['metodo_pago_ultimos4'] != null ? ' · Últ.4 ${c['metodo_pago_ultimos4']}' : ''}'
                          ' · ${c['conciliado'] == true ? 'Conciliado' : 'Pendiente'}',
                          style: TextStyle(
                              fontSize: 11, color: amarilloTxt.withValues(alpha: 0.85))),
                    ],
                  ),
                ),
              ),
          ],
        );

    // Tabla (PC/tablet) de un bloque de comprobantes (se pasa el título del bloque).
    Widget _tablaComprobantes(List<dynamic> lista) => Table(
          border: TableBorder.all(color: cs.outlineVariant, width: 1),
          columnWidths: const {
            0: FlexColumnWidth(2.6),
            1: FlexColumnWidth(1.4),
            2: FlexColumnWidth(1.3),
            3: FlexColumnWidth(1.0),
            4: FlexColumnWidth(1.4),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(color: cs.surfaceContainerHighest),
              children: [
                _th(cs, 'Referencia'),
                _th(cs, 'Fecha'),
                _th(cs, 'Monto', alinear: true),
                _th(cs, 'Últ. 4'),
                _th(cs, 'Estado'),
              ],
            ),
            for (final c in lista)
              TableRow(
                children: [
                  _td(cs, '${c['referencia'] ?? 'Comp. ${c['id']}'}', negrita: true),
                  _td(cs, '${c['fecha'] ?? ''}'),
                  _td(cs, money(_num(c['monto'])), alinear: true, negrita: true),
                  _td(cs, '${c['metodo_pago_ultimos4'] ?? '—'}'),
                  (c['conciliado'] == true)
                      ? _td(cs, 'Conciliado', color: Colors.green)
                      : _td(cs, 'Pendiente', color: Colors.grey),
                ],
              ),
          ],
        );

    // Título de bloque (Pagos a proveedores / Transferencias) con subtotal.
    Widget _bloqueTitulo(String titulo, String subtotal) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: Row(children: [
            Expanded(
              child: Text(titulo,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: amarilloTxt)),
            ),
            Text(subtotal,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: amarilloTxt)),
          ]),
        );

    // Comprobantes: miden el ancho; <640 => lista, sino tabla a todo el ancho.
    // Ambos bloques se renderizan (móvil: lista apilada; PC/tablet: tablas).
    final tablaComprobantes = comprobantesDetalle.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Sin comprobantes en el período.',
                style: TextStyle(color: Colors.grey)))
        : LayoutBuilder(builder: (ctx, c) {
            final esMovil = c.maxWidth < 640;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (comprobantesProveedores.isNotEmpty) ...[
                  _bloqueTitulo('Pagos a proveedores',
                      '${comprobantesProveedores.length} · ${money(suma(comprobantesProveedores))}'),
                  esMovil
                      ? _listaComprobantes(comprobantesProveedores)
                      : _tablaComprobantes(comprobantesProveedores),
                ],
                if (comprobantesTransferencias.isNotEmpty) ...[
                  _bloqueTitulo('Transferencias a otras cuentas',
                      '${comprobantesTransferencias.length} · ${money(suma(comprobantesTransferencias))}'),
                  esMovil
                      ? _listaComprobantes(comprobantesTransferencias)
                      : _tablaComprobantes(comprobantesTransferencias),
                ],
              ],
            );
          });

    // 4 tarjetas: Utilidad, Ventas, Gastos, Comprobantes.
    // Grid: móvil (ancho < 700) => 2x2; PC/tablet => 4x1.
    final amarillo = cs.onSurface; // amarillo pálido
    final cardUtilidad = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            utilidad >= 0 ? turquesa : Colors.redAccent,
            utilidad >= 0
                ? turquesa.withValues(alpha: 0.75)
                : Colors.redAccent.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _grisRoca, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.savings, size: 28, color: amarillo),
          const SizedBox(height: 6),
          Text(money(utilidad),
              style: TextStyle(
                  color: amarillo, fontWeight: FontWeight.bold, fontSize: 15),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('Utilidad',
              style: TextStyle(color: amarillo, fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );

    final cards = [
      cardUtilidad,
      _kpiCard('Ventas ($nVentas)', ventas, Icons.receipt_long,
          fondo: const Color(0xFF2FB9A6)), // turquesa
      _kpiCard('Gastos ($nFacturas)', facturas, Icons.receipt,
          fondo: const Color(0xFFC65D3B)), // terracota
      _kpiCard('Comprobantes ($nComprobantes)', comprobantes,
          Icons.account_balance_wallet,
          fondo: const Color(0xFFC65D3B)), // terracota
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (ctx, c) {
        if (c.maxWidth >= 700) {
          // PC/tablet: 4 en una sola fila, misma altura (stretch + IntrinsicHeight).
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  Expanded(child: cards[i]),
                  if (i < cards.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          );
        }
        // Móvil: grid 2x2, cada fila con altura uniforme.
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
            ]),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 10),
              Expanded(child: cards[3]),
            ]),
          ),
        ]);
      }),
      SizedBox(height: gap),
      Divider(color: cs.outlineVariant),
      const SizedBox(height: 4),
      _panel('Gastos (facturas de compra)',
          '${facturasDetalle.length} en el período · ${money(facturas)}',
          Icons.receipt_long, [tablaFacturas]),
      SizedBox(height: gap),
      _panel('Movimientos de dinero (comprobantes)',
          'Transferencias ${money(_num(_data?['comprobantes_transferencias']?['monto']))}'
          ' (${_num(_data?['comprobantes_transferencias']?['count']).toInt()}) · '
          'Proveedores ${money(_num(_data?['comprobantes_proveedores']?['monto']))}'
          ' (${_num(_data?['comprobantes_proveedores']?['count']).toInt()}) · '
          'Total ${money(comprobantes)}',
          Icons.account_balance_wallet, [tablaComprobantes]),
    ]);
  }
}