import '../../../inventario/data/models/producto_model.dart';

class ItemCarrito {
  final Producto producto;
  final double cantidad;

  const ItemCarrito({
    required this.producto,
    required this.cantidad,
  });

  /// Subtotal redondeado a 2 decimales para evitar desajustes de coma flotante
  double get subtotal {
    final calculo = cantidad * producto.precioVenta;
    return (calculo * 100).round() / 100.0;
  }

  ItemCarrito copyWith({
    Producto? producto,
    double? cantidad,
  }) {
    return ItemCarrito(
      producto: producto ?? this.producto,
      cantidad: cantidad ?? this.cantidad,
    );
  }
}
