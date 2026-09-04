import 'dart:convert';
import 'package:http/http.dart' as http;

/// Centralized HTTP client for the whole app.
///
/// The API base URL is built from the same host where the app is opened, so
/// it works when loading from `localhost`, from an IP, or from a mobile device
/// on the LAN (e.g. `192.168.0.201:3000/api`).
class ApiClient {
  ApiClient._();

  static String get baseUrl {
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