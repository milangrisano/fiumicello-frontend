import 'package:socket_io_client/socket_io_client.dart' as io;
import '../data/api_client.dart';

/// Cliente de tiempo real (Socket.IO) del backend.
///
/// Conecta con el JWT en el handshake y emite callbacks para los eventos
/// del POS: comanda:nueva, cocina:estado, turno:abierto/cerrado.
/// Singleton simple. Las vistas se suscriben y refrescan al recibir eventos,
/// sin recarga manual.
class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  static const _eventos = [
    'comanda:nueva',
    'cocina:estado',
    'turno:abierto',
    'turno:cerrado',
  ];

  io.Socket? _socket;
  final Map<String, void Function(Map<String, dynamic>)> _oyentes = {};

  bool get conectado => _socket?.connected ?? false;

  /// Conecta al WebSocket si no hay conexión activa.
  void conectar() {
    if (_socket != null) return;
    final token = ApiClient.token;
    if (token == null || token.isEmpty) return;

    final url = ApiClient.socketUrl;
    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .setAuth({'token': token})
          .build(),
    );

    // Reenvía cada evento a los oyentes registrados (del tipo Map).
    for (final e in _eventos) {
      _socket!.on(e, (data) {
        final cb = _oyentes[e];
        if (cb != null && data is Map) {
          cb(Map<String, dynamic>.from(data));
        }
      });
    }
  }

  /// Registra un oyente para un evento ('comanda:nueva', etc.).
  void on(String evento, void Function(Map<String, dynamic>) cb) {
    _oyentes[evento] = cb;
  }

  /// Desconecta (p. ej. al logout).
  void desconectar() {
    _socket?.dispose();
    _socket = null;
    _oyentes.clear();
  }
}