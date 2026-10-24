import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
                          Uri.base.resolve(item['archivo_url'] as String).toString(),
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
                        Uri.base.resolve(item['archivo_url'] as String).toString(),
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

  /// Escáner de documentos: toma la foto, la procesa en el backend (recorte +
  /// realce) y muestra la PREVISUALIZACIÓN con 3 opciones:
  ///   - Guardar  → confirma y crea el registro (backend detecta tipo con IA)
  ///   - Retomar  → vuelve a tomar la foto
  ///   - Mejorar  → ajuste manual de las 4 esquinas (endereza + recorta)
  Future<void> _cargarImagenOcr() async {
    _aviso('Abre la cámara para tomar la foto…');
    final XFile? archivo =
        await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2200, imageQuality: 85);
    if (archivo == null || !mounted) return;
    var bytes = await archivo.readAsBytes();
    var nombre = archivo.name;

    // Bucle: permite "Mejorar" (re-enviar con esquinas) sin volver a la cámara.
    List<num>? esquinas = null;
    while (mounted) {
      _aviso(esquinas == null ? 'Escaneando documento…' : 'Enderezando…');
      final (ok, msg, data) = await ApiClient.escanearPrevisualizar(bytes, nombre, esquinas: esquinas);
      if (!mounted) return;
      if (!ok) {
        _aviso('Error al escanear: $msg');
        return;
      }
      final d = data;
      if (d == null || d['id'] == null) {
        _aviso('No se pudo escanear la imagen.');
        return;
      }
      final id = d['id'].toString();
      final previewB64 = (d['preview_b64'] ?? '').toString();
      final bytesB64 = previewB64.startsWith('data:') ? previewB64.split(',').last : previewB64;
      final origW = (d['img_orig_w'] as num?) ?? 0;
      final origH = (d['img_orig_h'] as num?) ?? 0;

      final accion = await showDialog<String>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Theme.of(ctx).colorScheme.surfaceContainer,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Escaneo de documento',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (bytesB64.isNotEmpty)
                    Flexible(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(base64Decode(bytesB64), fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('No se pudo cargar la previsualización.'))),
                      ),
                    )
                  else
                    const Padding(padding: EdgeInsets.all(16), child: Text('Sin vista previa.')),
                  const SizedBox(height: 12),
                  Text('El documento se escaneó. Al guardar se detecta automáticamente'
                      ' si es factura o comprobante. Si el ángulo no quedó bien, usa'
                      ' "Mejorar" para ajustar las esquinas manualmente.',
                      style: Theme.of(ctx).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(ctx).pop('retomar'),
                          icon: const Icon(Icons.replay, size: 18),
                          label: const Text('Retomar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(ctx).pop('mejorar'),
                          icon: const Icon(Icons.crop_free, size: 18),
                          label: const Text('Mejorar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(ctx).pop('guardar'),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (!mounted) return;

      if (accion == 'retomar') {
        // Volver a tomar la foto desde cero.
        _aviso('Abre la cámara para tomar la foto…');
        final XFile? nuevo = await ImagePicker()
            .pickImage(source: ImageSource.camera, maxWidth: 2200, imageQuality: 85);
        if (nuevo == null || !mounted) return;
        bytes = await nuevo.readAsBytes();
        nombre = nuevo.name;
        esquinas = null;
      } else if (accion == 'mejorar') {
        // Ajuste manual de las 4 esquinas sobre la foto original.
        if (origW == 0 || origH == 0) {
          _aviso('No se pudo enderezar: faltan dimensiones.');
          continue;
        }
        final ajustadas = await _ajustarEsquinas(bytes, esquinas: esquinas, origW: origW, origH: origH);
        if (ajustadas == null || !mounted) {
          // El usuario canceló el ajuste.
          continue;
        }
        // Guardar la foto ORIGINAL en memoria con las esquinas nuevas.
        esquinas = ajustadas;
        // Reinicia el bucle → re-envía con esquinas → muestra el resultado.
      } else {
        // "guardar" (o cerró) → confirmar.
        if (accion != 'guardar') { if (!mounted) return; continue; }
        _aviso('Guardando…');
        final (ok2, msg2, data2) = await ApiClient.escanearConfirmar(id);
        if (!mounted) return;
        if (!ok2) {
          _aviso('Error al guardar: $msg2');
          return;
        }
        final tipo = (data2?['tipo'] ?? '').toString();
        final seGuardo = (data2?['detalle'] == true);
        _aviso(seGuardo ? '✓ Documento guardado ($tipo)' : 'El documento ya estaba registrado ($tipo).');
        await _cargar();
        return;
      }
    }
  }

  /// Diálogo de ajuste manual de las 4 esquinas sobre la foto original.
  /// Devuelve las 8 esquinas (x1,y1,...) en píxeles de la imagen ORIGINAL, o
  /// null si el usuario cancela.
  Future<List<num>?> _ajustarEsquinas(
      List<int> bytes,
      {List<num>? esquinas, required num origW, required num origH}) async {
    // Puntos normalizados 0-1 (TL,TR,BR,BL). Si hay esquinas previas, las
    // convertimos a normalizadas; si no, un rectángulo interior (10% margen).
    var x1 = 0.10, y1 = 0.10, x2 = 0.90, y2 = 0.10, x3 = 0.90, y3 = 0.90, x4 = 0.10, y4 = 0.90;
    if (esquinas != null && esquinas!.length == 8) {
      final e = esquinas!;
      x1 = (e[0] / origW).toDouble(); y1 = (e[1] / origH).toDouble();
      x2 = (e[2] / origW).toDouble(); y2 = (e[3] / origH).toDouble();
      x3 = (e[4] / origW).toDouble(); y3 = (e[5] / origH).toDouble();
      x4 = (e[6] / origW).toDouble(); y4 = (e[7] / origH).toDouble();
    }
    final result = await showDialog<List<num>?>(
      context: context,
      builder: (ctx) => _AjustarEsquinasView(
        imgBytes: Uint8List.fromList(bytes),
        initial: [x1, y1, x2, y2, x3, y3, x4, y4],
        onDone: (finalPts) => Navigator.of(ctx).pop(finalPts),
        onCancel: () => Navigator.of(ctx).pop(null),
      ),
    );
    if (result == null) return null;
    // Convertir de normalizadas (0-1) a píxeles de la imagen original.
    final px = <num>[...result];
    for (var i = 0; i < px.length; i++) {
      px[i] = (i % 2 == 0) ? (px[i] * origW).round() : (px[i] * origH).round();
    }
    return px;
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

/// Widget de ajuste manual de las 4 esquinas del documento sobre la foto.
/// Arrastra los 4 puntos turquesa hacia los límites del papel; al terminar
/// "Enderezar" devuelve las coordenadas normalizadas (0-1, TL,TR,BR,BL).
class _AjustarEsquinasView extends StatefulWidget {
  final Uint8List imgBytes;
  final List<double> initial;
  final void Function(List<double>) onDone;
  final void Function() onCancel;

  const _AjustarEsquinasView({
    super.key,
    required this.imgBytes,
    required this.initial,
    required this.onDone,
    required this.onCancel,
  });

  @override
  State<_AjustarEsquinasView> createState() => _AjustarEsquinasViewState();
}

class _AjustarEsquinasViewState extends State<_AjustarEsquinasView> {
  // Coordenadas normalizadas 0-1: [x1,y1, x2,y2, x3,y3, x4,y4] → TL,TR,BR,BL
  late final List<double> pts;

  @override
  void initState() {
    super.initState();
    pts = List<double>.of(widget.initial);
  }

  double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const tamHandle = 36.0;

    Widget handle(int i, double x, double y) => Positioned(
      left: x * 100,
      top: y * 100,
      width: 0,
      height: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          // details.delta = desplazamiento del puntero (px). Convertimos a
          // fracción del área (LayoutBuilder nos dio el tamaño en el build).
          final dims = _dimsW / _dimsH;
          if (i == 0) { pts[0] = _clamp01(pts[0] + (details.delta.dx / 400)); pts[1] = _clamp01(pts[1] + (details.delta.dy / 400)); }
          else if (i == 1) { pts[2] = _clamp01(pts[2] + (details.delta.dx / 400)); pts[3] = _clamp01(pts[3] + (details.delta.dy / 400)); }
          else if (i == 2) { pts[4] = _clamp01(pts[4] + (details.delta.dx / 400)); pts[5] = _clamp01(pts[5] + (details.delta.dy / 400)); }
          else { pts[6] = _clamp01(pts[6] + (details.delta.dx / 400)); pts[7] = _clamp01(pts[7] + (details.delta.dy / 400)); }
          if (mounted) setState(() {});
        },
        child: Center(
          child: Container(
            width: tamHandle,
            height: tamHandle,
            decoration: BoxDecoration(
              color: const Color(0xFF2FB9A6),
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(tamHandle / 2),
            ),
          ),
        ),
      ),
    );

    return Dialog(
      backgroundColor: cs.surfaceContainer,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ajustar esquinas',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Arrastra los 4 puntos hacia los límites del documento para'
                  ' enderezarlo y recortarlo. Al "Enderezar" se procesa la imagen.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      _dimsW = constraints.maxWidth;
                      _dimsH = constraints.maxHeight;
                      return Stack(
                        textDirection: TextDirection.ltr,
                        fit: StackFit.expand,
                        children: [
                          Image.memory(widget.imgBytes, fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Center(child: Text('No se pudo cargar la imagen.'))),
                          handle(0, pts[0], pts[1]),
                          handle(1, pts[2], pts[3]),
                          handle(2, pts[4], pts[5]),
                          handle(3, pts[6], pts[7]),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => widget.onDone(List<double>.of(pts)),
                      icon: const Icon(Icons.crop_free, size: 18),
                      label: const Text('Enderezar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  double _dimsW = 400, _dimsH = 400;
}