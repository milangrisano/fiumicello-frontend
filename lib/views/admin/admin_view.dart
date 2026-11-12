import 'package:flutter/material.dart';
import 'admin_tokens_view.dart';
import 'admin_roles_view.dart';
import 'admin_usuarios_view.dart';
import 'admin_productos_view.dart';
import 'admin_pagos_view.dart';

/// SuperAdmin/Admin panel with tabs for the administration sections:
/// - Usuarios (list + assign roles)
/// - Tokens (service accounts)
/// - Roles y permisos (dynamic role config)
/// - Productos (menu items management)
/// - Métodos de pago (create/rename/activate/disable payment methods)
class AdminView extends StatelessWidget {
  const AdminView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const TabBar(tabs: [
            Tab(text: 'Usuarios'),
            Tab(text: 'Tokens'),
            Tab(text: 'Roles'),
            Tab(text: 'Productos'),
            Tab(text: 'Pagos'),
          ]),
          const Expanded(
            child: TabBarView(children: [
              UsuariosView(),
              AdminTokensView(),
              RolesPermisosView(),
              ProductsView(),
              PagosView(),
            ]),
          ),
        ],
      ),
    );
  }
}