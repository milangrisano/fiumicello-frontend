import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized HTTP client for the whole app.
///
/// In production the frontend is served by Nginx, which proxies `/api` to the
/// backend service. In development it builds the URL from the current host.
///
/// Since the backend now requires JWT auth on protected routes, this client
/// stores the bearer token (persisted via shared_preferences) and attaches it
/// to every request.
class ApiClient {
  ApiClient._();

  static const String _apiBaseOverride =
      String.fromEnvironment('API_BASE', defaultValue: '');

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  static String? _token;
  static String? _username;

  static String get baseUrl {
    // Production: Nginx serves /api and proxies to the backend.
    if (_apiBaseOverride.isNotEmpty) {
      // Allow a relative override (e.g. "/api") resolved against the app origin.
      if (_apiBaseOverride.startsWith('/')) {
        try {
          return Uri.base.resolve(_apiBaseOverride).toString().replaceAll(RegExp(r'/+$'), '');
        } catch (_) {
          return _apiBaseOverride;
        }
      }
      return _apiBaseOverride;
    }
    // Development: use the same host where the app is opened.
    final host = Uri.base.host;
    if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
      return 'http://localhost:3000/api';
    }
    return 'http://$host:3000/api';
  }

  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  static String? get currentUsername => _username;

  /// Loads a previously persisted token/session from local storage.
  static Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _username = prefs.getString(_userKey);
  }

  /// Attempts a login against POST /auth/login. On success stores the token.
  static Future<bool> login(String username, String password) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      return false;
    }
    final body = Map<String, dynamic>.from(jsonDecode(res.body));
    final token = body['access_token'] as String?;
    if (token == null || token.isEmpty) return false;

    _token = token;
    _username = body['user']?['username'] ?? username;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, _username!);
    return true;
  }

  /// Clears the stored token (logout).
  static Future<void> logout() async {
    _token = null;
    _username = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  static Map<String, String> _headers() {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (_token != null && _token!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  /// Performs a GET request and returns the decoded JSON object.
  static Future<Map<String, dynamic>> getJson(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.get(uri, headers: _headers());
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body);
  }

  /// Convenience: returns the decoded body as a raw map (used by lists).
  static Future<Map<String, dynamic>> getList(String path) => getJson(path);
}