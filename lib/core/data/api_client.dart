import 'dart:convert';
import 'package:http/http.dart' as http;

/// Centralized HTTP client for the whole app.
///
/// In production the frontend is served by Nginx, which proxies `/api` to the
/// backend service. In development it builds the URL from the current host.
class ApiClient {
  ApiClient._();

  static const String _apiBaseOverride =
      String.fromEnvironment('API_BASE', defaultValue: '');

  static String get baseUrl {
    // Production: Nginx serves /api and proxies to the backend.
    if (_apiBaseOverride.isNotEmpty) {
      return _apiBaseOverride;
    }
    // Development: use the same host where the app is opened.
    final host = Uri.base.host;
    if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
      return 'http://localhost:3000/api';
    }
    return 'http://$host:3000/api';
  }

  /// Performs a GET request and returns the decoded JSON object.
  static Future<Map<String, dynamic>> getJson(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.get(uri);
    final body = jsonDecode(res.body);
    return Map<String, dynamic>.from(body);
  }

  /// Convenience: returns the decoded body as a raw map (used by lists).
  static Future<Map<String, dynamic>> getList(String path) => getJson(path);
}