import 'package:flutter/material.dart';
import 'admin_tokens_view.dart';
import 'admin_roles_view.dart';
import 'admin_usuarios_view.dart';
import 'admin_productos_view.dart';
import 'admin_pagos_view.dart';
import 'admin_docs_view.dart';
import 'package:fiumicello_frontend/core/data/api_client.dart';

/// SuperAdmin/Admin panel with tabs for the administration sections:
/// - Usuarios (list + assign roles)
/// - Tokens (service accounts)
/// - Roles y permisos (dynamic role config)
/// - Productos (menu items management)
/// - Métodos de pago (create/rename/activate/disable payment methods)
/// - Documentación API (solo visible si tiene permiso 'swagger:ver')
class AdminView extends StatelessWidget {
  const AdminView({super.key});
  @override
  Widget build(BuildContext context) {
    final bool mostarDocs = ApiClient.hasPermiso('swagger:ver');

    // Tabs base (siempre presentes)
    final List<Tab> tabs = const [
      Tab(text: 'Usuarios'),
      Tab(text: 'Tokens'),
      Tab(text: 'Roles'),
      Tab(text: 'Productos'),
      Tab(text: 'Pagos'),
    ];

    // Vistas base (siempre presentes)
    final List<Widget> vistas = const [
      UsuariosView(),
      AdminTokensView(),
      RolesPermisosView(),
      ProductsView(),
      PagosView(),
    ];

    // Determinar length y si agregar la tab de documentación
    final int tabLength = 5 + (mostarDocs ? 1 : 0);

    // Construir listas dinámicas: si tiene permiso, agregamos la tab al final
    final List<Tab> dynamicTabs = List.from(tabs);
    final List<Widget> dynamicViews = List.from(vistas);

    if (mostarDocs) {
      dynamicTabs.add(const Tab(text: 'Documentación API'));
      dynamicViews.add(const AdminDocsView());
    }

    return DefaultTabController(
      length: tabLength,
      child: Column(
        children: [
          TabBar(tabs: dynamicTabs),
          Expanded(
            child: TabBarView(children: dynamicViews),
          ),
        ],
      ),
    );
  }
}
