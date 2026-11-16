import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fiumicello_frontend/core/data/api_client.dart';

/// Vista que embebe la documentación Swagger de la API dentro de esta pestaña
/// (iframe), en vez de abrir una ventana/pestaña nueva del navegador.
///
/// La URL lleva el JWT (?token=) para que el middleware del backend firme la
/// cookie `swagger_ok` en la primera carga del iframe; desde ahí los assets
/// (css/js) y el spec del mismo origen se sirven sin repetir el token.
class AdminDocsView extends StatefulWidget {
  const AdminDocsView({super.key});

  @override
  State<AdminDocsView> createState() => _AdminDocsViewState();
}

class _AdminDocsViewState extends State<AdminDocsView> {
  static const _viewType = 'fiumicello-swagger-docs';

  @override
  void initState() {
    super.initState();
    _ensureViewFactory();
  }

  /// Registra (una sola vez) el view factory que crea el iframe embebido.
  void _ensureViewFactory() {
    // Si el viewType ya está registrado no lo volvemos a registrar (lanzaría).
    if (_viewTypesRegistered.contains(_viewType)) return;
    _viewTypesRegistered.add(_viewType);
    try {
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) {
          final baseUrl = ApiClient.baseUrl;
          final token = ApiClient.token;
          // ApiClient.baseUrl YA incluye /api → el backend monta Swagger en
          // '/api/docs' → aquí solo agregamos '/docs' (NO '/api/docs' doble).
          final docsUrl = (token != null && token.isNotEmpty)
              ? '$baseUrl/docs?token=$token'
              : '$baseUrl/docs';

          final iframe = html.IFrameElement();
          iframe.src = docsUrl;
          iframe.style.border = 'none';
          iframe.style.width = '100%';
          iframe.style.height = '100%';
          iframe.style.display = 'block';
          iframe.allowFullscreen = true;
          return iframe;
        },
      );
    } catch (_) {
      // Si por alguna razón se registró dos veces, lo ignoramos.
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HtmlElementView(viewType: _viewType);
  }
}

/// Colección estática de viewTypes ya registrados (para no registrar dos veces).
final Set<String> _viewTypesRegistered = <String>{};