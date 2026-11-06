import 'package:flutter/material.dart';
import '../core/data/api_client.dart';

/// Menú desplegable que se abre al pulsar el gorro de Fiumicello.
///
/// Muestra los datos del usuario logueado (email + rol) y una única acción:
/// navegar a la vista de cambio de contraseña. El gorro YA NO navega a la
/// carta (Enrique: quitar la navegación a Carta y hacerlo abrir el perfil).
class PerfilMenu extends StatelessWidget {
  const PerfilMenu({super.key});

  /// Imagen del gorro según tema (claro/oscuro).
  Widget _gorro(BuildContext context, {double height = 34}) {
    return Image.asset(
      Theme.of(context).brightness == Brightness.dark
          ? 'assets/gorro_fiumicello_blanco.png'
          : 'assets/gorro_fiumicello.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.restaurant_menu, size: height),
    );
  }

  void _irCambiarContrasena(BuildContext context) {
    // Ruta registrada en app.dart; se abre sobre el shell (volver regresa al app).
    Navigator.of(context).pushNamed('/cambiar-contrasena');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final email = ApiClient.currentEmail ?? '—';
    final rol = ApiClient.currentRol ?? '—';
    return PopupMenuButton<String>(
      tooltip: 'Mi perfil',
      onSelected: (v) {
        if (v == 'cambiar') _irCambiarContrasena(context);
      },
      itemBuilder: (ctx) => [
        // Cabecera: datos del logueado (no accionable).
        PopupMenuItem<String>(
          enabled: false,
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.person, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(email,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Rol: $rol',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'cambiar',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.password),
            title: Text('Cambiar contraseña'),
            dense: true,
          ),
        ),
      ],
      child: Tooltip(
        message: 'Mi perfil',
        child: Container(
          padding: const EdgeInsets.all(4),
          child: _gorro(context),
        ),
      ),
    );
  }
}