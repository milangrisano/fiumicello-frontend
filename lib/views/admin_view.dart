import 'package:flutter/material.dart';
import 'admin_tokens_view.dart';
import 'admin_roles_view.dart';
import 'admin_usuarios_view.dart';

/// SuperAdmin/Admin panel with tabs for the administration sections:
/// - Pendientes (approve registration) + Tokens (service accounts)
/// - Usuarios (list + assign roles)
/// - Roles y permisos (dynamic role config)
class AdminView extends StatelessWidget {
  const AdminView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(tabs: [
            Tab(text: 'Usuarios'),
            Tab(text: 'Tokens'),
            Tab(text: 'Roles'),
          ]),
          const Expanded(
            child: TabBarView(children: [
              UsuariosView(),
              AdminTokensView(),
              RolesPermisosView(),
            ]),
          ),
        ],
      ),
    );
  }
}