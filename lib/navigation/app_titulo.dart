import 'package:flutter/foundation.dart';

/// Título dinámico del AppBar global. Las secciones/vistas lo actualizan para
/// que la barra de título muestre el nombre de la pantalla actual (p. ej.
/// "Nueva comanda") y no un texto fijo como "Fiumicello · Gestión".
class AppTitulo {
  static final ValueNotifier<String> titulo = ValueNotifier<String>('Fiumicello · Gestión');
}