import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Simple result wrapper (avoids Dart 'records' — the dev SDK is older).
class PostResult {
  final bool ok;
  final String message;
  PostResult(this.ok, this.message);
}

class ListResult {
  final bool ok;
  final List<dynamic> list;
  final String message;
  ListResult(this.ok, this.list, this.message);
}

class TokenResult {
  final bool ok;
  final Map<String, dynamic>? data;
  final String message;
  TokenResult(this.ok, this.data, this.message);
}

/// Centralized HTTP client for the whole app.
class ApiClient {
  ApiClient._();

  static const String _apiBaseOverride =
      String.fromEnvironment('API_BASE', defaultValue: '');

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  static String? _token;
  static Map<String, dynamic>? _user;
  static Set<String> _permisos = {};

  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  static String? get currentEmail => _user?['email'] as String?;
  static String? get currentRol => _user?['rol'] as String?;
  static bool get isSuperadmin => currentRol == 'superadmin';
  static bool get isAdmin => currentRol == 'admin';
  static Set<String> get permisos => _permisos;
  static bool hasPermiso(String p) => isSuperadmin || _permisos.contains(p);

  /// Loads the current user's permissions from the backend (if logged in).
  static Future<void> cargarPermisos() async {
    if (!isLoggedIn) return;
    final r = await misPermisos();
    if (r.ok) {
      _permisos = (r.data?['permisos'] as List? ?? <String>[]).cast<String>().toSet();
    }
  }

  static String get baseUrl {
    if (_apiBaseOverride.isNotEmpty) {
      if (_apiBaseOverride.startsWith('/')) {
        try {
          return Uri.base.resolve(_apiBaseOverride).toString().replaceAll(RegExp(r'/+$'), '');
        } catch (_) {
          return _apiBaseOverride;
        }
      }
      return _apiBaseOverride;
    }
    final host = Uri.base.host;
    if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
      return 'http://localhost:3000/api';
    }
    return 'http://$host:3000/api';
  }

  static Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final u = prefs.getString(_userKey);
    if (u != null && u.isNotEmpty) {
      try {
        _user = Map<String, dynamic>.from(jsonDecode(u));
      } catch (_) {
        _user = null;
      }
    }
    await cargarPermisos();
  }

  static Future<bool> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode != 200) return false;
    final body = Map<String, dynamic>.from(jsonDecode(res.body));
    final token = body['access_token'] as String?;
    if (token == null || token.isEmpty) return false;
    _token = token;
    _user = Map<String, dynamic>.from(body['user']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(_user!));
    await cargarPermisos(); // load role permissions for the dynamic menu
    return true;
  }

  static Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  static Future<PostResult> register(String email) =>
      _post('/auth/register', {'email': email});

  static Future<PostResult> verify(email, code, password) =>
      _post('/auth/verify', {'email': email, 'code': code, 'password': password});

  static Future<PostResult> verifyCode(String email, String code) =>
      _post('/auth/verify-code', {'email': email, 'code': code});

  static Future<PostResult> forgotPassword(String email) =>
      _post('/auth/forgot-password', {'email': email});

  static Future<PostResult> resetPassword(email, token, password) =>
      _post('/auth/reset-password', {'email': email, 'token': token, 'password': password});

  static Future<ListResult> listServicios() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/auth/servicios'), headers: _headers());
      if (res.statusCode == 200) return ListResult(true, jsonDecode(res.body) as List, '');
      return ListResult(false, const [], _msg(res.body));
    } catch (e) {
      return ListResult(false, const [], '$e');
    }
  }

  static Future<TokenResult> generarServicio(String nombre) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/servicios'),
        headers: _headers(),
        body: jsonEncode({'nombre': nombre}),
      );
      if (res.statusCode == 201) {
        return TokenResult(true, Map<String, dynamic>.from(jsonDecode(res.body)), '');
      }
      return TokenResult(false, null, _msg(res.body));
    } catch (e) {
      return TokenResult(false, null, '$e');
    }
  }

  static Future<PostResult> revocarServicio(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/auth/servicios/$id'),
        headers: _headers(),
      );
      return PostResult(res.statusCode == 200, _msg(res.body));
    } catch (e) {
      return PostResult(false, '$e');
    }
  }

  static Future<ListResult> listPendientes() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/auth/usuarios/pendientes'),
        headers: _headers(),
      );
      if (res.statusCode == 200) return ListResult(true, jsonDecode(res.body) as List, '');
      return ListResult(false, const [], _msg(res.body));
    } catch (e) {
      return ListResult(false, const [], '$e');
    }
  }

  static Future<PostResult> aprobar(int id) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/usuarios/$id/aprobar'),
        headers: _headers(),
      );
      return PostResult(res.statusCode == 200, _msg(res.body));
    } catch (e) {
      return PostResult(false, '$e');
    }
  }

  // ---- Users ----
  static Future<ListResult> listUsuarios() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/auth/usuarios'),
        headers: _headers(),
      );
      if (res.statusCode == 200) return ListResult(true, jsonDecode(res.body) as List, '');
      return ListResult(false, const [], _msg(res.body));
    } catch (e) {
      return ListResult(false, const [], '$e');
    }
  }

  static Future<PostResult> asignarRolUsuario(int id, String rol) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/usuarios/$id/rol'),
        headers: _headers(),
        body: jsonEncode({'rol': rol}),
      );
      return PostResult(res.statusCode == 200, _msg(res.body));
    } catch (e) {
      return PostResult(false, '$e');
    }
  }

  // ---- Permissions & Roles ----
  static Future<TokenResult> misPermisos() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/auth/mis-permisos'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        return TokenResult(true, Map<String, dynamic>.from(jsonDecode(res.body)), '');
      }
      return TokenResult(false, null, _msg(res.body));
    } catch (e) {
      return TokenResult(false, null, '$e');
    }
  }

  static Future<ListResult> listRoles() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/auth/roles'),
        headers: _headers(),
      );
      if (res.statusCode == 200) return ListResult(true, jsonDecode(res.body) as List, '');
      return ListResult(false, const [], _msg(res.body));
    } catch (e) {
      return ListResult(false, const [], '$e');
    }
  }

  static Future<ListResult> catalogoPermisos() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/auth/roles/catalogo'),
        headers: _headers(),
      );
      if (res.statusCode == 200) return ListResult(true, jsonDecode(res.body) as List, '');
      return ListResult(false, const [], _msg(res.body));
    } catch (e) {
      return ListResult(false, const [], '$e');
    }
  }

  static Future<PostResult> crearRol(String nombre, String descripcion, List<String> permisos) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/roles'),
        headers: _headers(),
        body: jsonEncode({'nombre': nombre, 'descripcion': descripcion, 'permisos': permisos}),
      );
      return PostResult(res.statusCode == 200 || res.statusCode == 201, _msg(res.body));
    } catch (e) {
      return PostResult(false, '$e');
    }
  }

  static Future<PostResult> actualizarRol(
      String nombreOriginal, String nombreNuevo, String descripcion, List<String> permisos) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/auth/roles/$nombreOriginal'),
        headers: _headers(),
        body: jsonEncode({'nombre': nombreNuevo, 'descripcion': descripcion, 'permisos': permisos}),
      );
      return PostResult(res.statusCode == 200, _msg(res.body));
    } catch (e) {
      return PostResult(false, '$e');
    }
  }

  static Future<PostResult> eliminarRol(String nombre) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/auth/roles/$nombre'),
        headers: _headers(),
      );
      return PostResult(res.statusCode == 200, _msg(res.body));
    } catch (e) {
      return PostResult(false, '$e');
    }
  }

  // ---- Carta (menu) ----
  /// Public menu — works without a token.
  static Future<TokenResult> obtenerCarta() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/carta'));
      if (res.statusCode == 200) {
        return TokenResult(true, Map<String, dynamic>.from(jsonDecode(res.body)), '');
      }
      return TokenResult(false, null, _msg(res.body));
    } catch (e) {
      return TokenResult(false, null, '$e');
    }
  }

  /// Admin: all products (active + disabled) for the products page.
  static Future<TokenResult> obtenerCartaAdmin() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/carta/administracion'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        return TokenResult(true, Map<String, dynamic>.from(jsonDecode(res.body)), '');
      }
      return TokenResult(false, null, _msg(res.body));
    } catch (e) {
      return TokenResult(false, null, '$e');
    }
  }

  static Future<PostResult> toggleProductoActivo(int id) async {
    return _postAuth('/carta/items/$id/toggle', const {});
  }

  static Future<PostResult> crearCategoria(String nombre, {int orden = 0}) async {
    return _postAuth('/carta/categorias', {'nombre': nombre, 'orden': orden});
  }

  static Future<PostResult> actualizarCategoria(int id, String nombre, {int? orden}) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/carta/categorias/$id'),
        headers: _headers(),
        body: jsonEncode({'nombre': nombre, 'orden': orden ?? 0}),
      );
      return PostResult(res.statusCode == 200, _msg(res.body));
    } catch (e) {
      return PostResult(false, '$e');
    }
  }

  static Future<PostResult> eliminarCategoria(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/carta/categorias/$id'),
        headers: _headers(),
      );
      return PostResult(res.statusCode == 200, _msg(res.body));
    } catch (e) {
      return PostResult(false, '$e');
    }
  }

  static Future<PostResult> crearItemCarta(Map<String, dynamic> item) async {
    return _postAuth('/carta/items', item);
  }

  static Future<PostResult> actualizarItemCarta(int id, Map<String, dynamic> item) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/carta/items/$id'),
        headers: _headers(),
        body: jsonEncode(item),
      );
      return PostResult(res.statusCode == 200, _msg(res.body));
    } catch (e) {
      return PostResult(false, '$e');
    }
  }

  static Future<PostResult> eliminarItemCarta(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/carta/items/$id'),
        headers: _headers(),
      );
      return PostResult(res.statusCode == 200, _msg(res.body));
    } catch (e) {
      return PostResult(false, '$e');
    }
  }

  // ---- Ventas (POS) ----
  static Future<PostResult> crearVenta(Map<String, dynamic> venta) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/ventas'),
        headers: _headers(),
        body: jsonEncode(venta),
      );
      return PostResult(res.statusCode == 200 || res.statusCode == 201, _msg(res.body));
    } catch (e) {
      return PostResult(false, '$e');
    }
  }

  static Future<ListResult> listarVentas() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/ventas?limit=100'),
        headers: _headers(),
      );
      if (res.statusCode == 200) return ListResult(true, jsonDecode(res.body) as List, '');
      return ListResult(false, const [], _msg(res.body));
    } catch (e) {
      return ListResult(false, const [], '$e');
    }
  }

  /// Resumen contable agregado (totales, ítems, KPIs) para un período.
  /// Devuelve (ok, data o null, mensaje).
  static Future<(bool, Map<String, dynamic>?, String)> obtenerResumen(
      String periodo, String? referencia) async {
    try {
      var uri = '$baseUrl/resumenes?periodo=$periodo';
      if (referencia != null && referencia.isNotEmpty) {
        uri += '&referencia=$referencia';
      }
      final res = await http.get(Uri.parse(uri), headers: _headers());
      if (res.statusCode == 200) {
        return (true, Map<String, dynamic>.from(jsonDecode(res.body)), '');
      }
      return (false, null, _msg(res.body));
    } catch (e) {
      return (false, null, '$e');
    }
  }

  static Future<ListResult> listarFormasPago() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/ventas/formas-pago'),
        headers: _headers(),
      );
      if (res.statusCode == 200) return ListResult(true, jsonDecode(res.body) as List, '');
      return ListResult(false, const [], _msg(res.body));
    } catch (e) {
      return ListResult(false, const [], '$e');
    }
  }

  static Future<PostResult> crearFormaPago(String nombre) async {
    return _postAuth('/ventas/formas-pago', {'nombre': nombre});
  }

  static Future<PostResult> actualizarFormaPago(int id, String nombre, {bool? activo}) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/ventas/formas-pago/$id'),
        headers: _headers(),
        body: jsonEncode({'nombre': nombre, 'activo': activo}),
      );
      return PostResult(res.statusCode == 200, _msg(res.body));
    } catch (e) {
      return PostResult(false, '$e');
    }
  }

  static Future<PostResult> eliminarFormaPago(int id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/ventas/formas-pago/$id'),
        headers: _headers(),
      );
      return PostResult(res.statusCode == 200, _msg(res.body));
    } catch (e) {
      return PostResult(false, '$e');
    }
  }

  // ---- Pedidos (POS orders) ----
  static Future<PostResult> crearPedido(Map<String, dynamic> pedido) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/pedidos'),
          headers: _headers(), body: jsonEncode(pedido));
      return PostResult(res.statusCode == 200 || res.statusCode == 201, _msg(res.body));
    } catch (e) {
      return PostResult(false, '$e');
    }
  }

  static Future<ListResult> listarPedidos(
      {String? estado, String? escenario}) async {
    try {
      final q = <String>[];
      if (estado != null) q.add('estado=$estado');
      if (escenario != null) q.add('escenario=$escenario');
      final qs = q.isEmpty ? '' : '?${q.join('&')}';
      final res = await http.get(Uri.parse('$baseUrl/pedidos$qs'), headers: _headers());
      if (res.statusCode == 200) return ListResult(true, jsonDecode(res.body) as List, '');
      return ListResult(false, const [], _msg(res.body));
    } catch (e) {
      return ListResult(false, const [], '$e');
    }
  }

  static Future<TokenResult> obtenerPedido(int id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/pedidos/$id'), headers: _headers());
      if (res.statusCode == 200) {
        return TokenResult(true, Map<String, dynamic>.from(jsonDecode(res.body)), '');
      }
      return TokenResult(false, null, _msg(res.body));
    } catch (e) {
      return TokenResult(false, null, '$e');
    }
  }

  static Future<PostResult> agregarItemsPedido(int id, List<Map<String, dynamic>> items) async {
    return _postAuth('/pedidos/$id/items', {'items': items});
  }

  static Future<PostResult> cobrarPedido(int id, int? idFormaPago) async {
    return _postAuth('/pedidos/$id/cobrar', {'id_forma_pago': idFormaPago});
  }

  static Future<PostResult> entregarPedido(int id) async {
    return _postAuth('/pedidos/$id/entregar', const {});
  }

  /// Authenticated POST (requires bearer token).
  static Future<PostResult> _postAuth(String path, Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers(),
        body: jsonEncode(body),
      );
      return PostResult(res.statusCode == 200 || res.statusCode == 201, _msg(res.body));
    } catch (e) {
      return PostResult(false, '$e');
    }
  }

  static Future<Map<String, dynamic>> getJson(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers());
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  static Future<Map<String, dynamic>> getList(String path) => getJson(path);

  static Map<String, String> _headers() {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (_token != null && _token!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  static Future<PostResult> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        return PostResult(true, _msg(res.body));
      }
      return PostResult(false, _msg(res.body));
    } catch (e) {
      return PostResult(false, '$e');
    }
  }

  static String _msg(String body) {
    if (body.isEmpty) return 'Error.';
    try {
      final d = jsonDecode(body);
      if (d is Map && d['message'] != null) return d['message'].toString();
      return body;
    } catch (_) {
      return body;
    }
  }
}