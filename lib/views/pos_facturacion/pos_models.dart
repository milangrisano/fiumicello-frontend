/// POS invoicing — models (a product line and the screen enum).

/// A product line being composed (stage 1: comanda).
class Linea {
  final int idProducto;
  final String nombre;
  final String? tamanio;
  final double precio;
  int cantidad = 1;
  String nota = '';
  /// true si esta línea ya existe en la mesa/pedido (se cargó al editar);
  /// los nuevos productos van con false. Sirve para no re-enviar los ya
  /// existentes al agregar más a la misma mesa.
  bool yaEnMesa = false;

  Linea({
    required this.idProducto,
    required this.nombre,
    this.tamanio,
    required this.precio,
    this.cantidad = 1,
    this.nota = '',
    this.yaEnMesa = false,
  });

  double get subtotal => precio * cantidad;
}

/// The screens of the POS 3-stage flow + table/pending views.
class Pantalla {
  static const int inicio = 0;
  static const int comanda = 1;
  static const int asignacion = 2;
  static const int cobro = 3;
  static const int mesas = 4;
  static const int entregas = 5;
}