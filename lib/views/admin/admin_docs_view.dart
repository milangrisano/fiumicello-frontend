import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:fiumicello_frontend/core/data/api_client.dart';

/// Vista que embebe la documentación Swagger de la API dentro de esta pestaña
/// (iframe), en vez de abrir una ventana/pestaña nueva del navegador.
///
/// La URL lleva el JWT (?token=) para que el middleware del backend firme la
/// cookie `swagger_ok` en la primera carga del iframe; desde ahí los assets
/// (css/js) y el spec del mismo origen se sirven sin repetir el token.
class AdminDocsView extends StatelessWidget {
  const AdminDocsView({super.key});

  @override
  Widget build(BuildContext context) {
    final baseUrl = ApiClient.baseUrl;
    final token = ApiClient.token;
    // ApiClient.baseUrl YA incluye /api → el backend monta Swagger en
    // '/api/docs' → aquí solo agregamos '/docs' (NO '/api/docs' doble).
    final docsUrl = (token != null && token.isNotEmpty)
        ? '$baseUrl/docs?token=$token'
        : '$baseUrl/docs';

    // Mismo patrón que PdfViewer (invoices_view): iframe embebido que ocupa
    // todo el espacio de la pestaña, renderizado por el navegador en el mismo
    // origen, así los assets css/js del Swagger se cargan con la cookie firmada.
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (Object element) {
        final iframe = element as web.HTMLIFrameElement;
        iframe.src = docsUrl;
        iframe.style.border = 'none';
        iframe.style.width = '100%';
        iframe.style.height = '100%';
        iframe.style.display = 'block';
        iframe.allowFullscreen = true;
      },
    );
  }
}