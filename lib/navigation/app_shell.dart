import 'package:flutter/material.dart';
import '../core/data/api_client.dart';
import '../responsive/responsive_layout.dart';

/// Top-level shell: keeps the active section index and hands it to the
/// responsive layout, which picks the correct shell for the screen width.
///
/// SEGURIDAD: la ruta `/app` está PROTEGIDA. Si no hay sesión válida (token
/// ausente o ya no válido contra el backend), redirige a `/login` y no expone
/// el diseño de las pantallas internas.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _verificando = true;

  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
    await ApiClient.restoreSession();
    // Valida el token contra el backend (misPermisos devuelve !ok si 401).
    await ApiClient.cargarPermisos();
    if (!mounted) return;
    if (!ApiClient.isLoggedIn) {
      // Sin token local: nunca mostrar el shell.
      _irA('/login');
      return;
    }
    // Token presente: comprobamos que siga siendo válido. Si los permisos no
    // cargan (token expirado/inválido) obligamos a reingresar.
    if (ApiClient.permisos.isEmpty && !ApiClient.isSuperadmin) {
      // Podría ser un usuario sin permisos asignados; igualmente no exponemos
      // secciones protegidas. Para estar seguros, validamos con una llamada.
      final r = await ApiClient.misPermisos();
      if (!mounted) return;
      if (!r.ok) {
        await ApiClient.logout();
        _irA('/login');
        return;
      }
    }
    setState(() => _verificando = false);
  }

  void _irA(String ruta) {
    // Espera un frame para que el Navigator esté listo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pushReplacementNamed(ruta);
    });
  }

  void _onSelect(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_verificando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ResponsiveLayout(selectedIndex: _selectedIndex, onSelect: _onSelect);
  }
}
