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

    // Construir URL de la documentación Swagger con token si está disponible
    final String docsUrl = token != null && token.isNotEmpty
        ? '$baseUrl/api/docs?token=$token'
        : '$baseUrl/api/docs';

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