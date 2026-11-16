import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:fiumicello_frontend/core/data/api_client.dart';

/// StatelessWidget that provides a button to open the API Swagger documentation
/// in a new browser tab. The URL includes the JWT token for authentication.
class AdminDocsView extends StatelessWidget {
  const AdminDocsView({super.key});

  @override
  Widget build(BuildContext context) {
    final baseUrl = ApiClient.baseUrl;
    final token = ApiClient.token;

    // ApiClient.baseUrl YA incluye el prefijo /api (API_BASE o http://host:3000/api),
    // y el backend monta Swagger en '/api/docs' — concatenar '/api/docs' otra vez
    // duplicaba el prefijo y daba 404 'Cannot GET /api/api/docs'.
    final String docsUrl = token != null && token.isNotEmpty
        ? '$baseUrl/docs?token=$token'
        : '$baseUrl/docs';

    return Center(
      child: ElevatedButton(
        onPressed: () {
          // Abrir la documentación Swagger en una pestaña nueva del navegador
          // Usa window.open desde dart:html (robusto en Flutter Web)
          html.window.open(docsUrl, '_blank');
        },
        child: const Text('Abrir documentación API'),
      ),
    );
  }
}