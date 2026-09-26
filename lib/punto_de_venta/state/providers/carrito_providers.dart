import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../inventario/data/models/producto_model.dart';
import '../../data/models/item_carrito_model.dart';

/// Notifier que gestiona el estado del "Ticket en Espera"
class CarritoNotifier extends Notifier<List<ItemCarrito>> {
  @override
  List<ItemCarrito> build() {
    return [];
  }

  /// Agrega un producto estándar al ticket o suma a su cantidad si ya existe
  void agregarProducto(Producto producto, [double cantidad = 1.0]) {
    final index = state.indexWhere(
      (item) => item.producto.id == producto.id && item.modoVenta == ModoVenta.normal,
    );

    if (index >= 0) {
      final itemExistente = state[index];
      final nuevaCantidad = itemExistente.cantidad + cantidad;

      state = [
        ...state.sublist(0, index),
        itemExistente.copyWith(cantidad: nuevaCantidad),
        ...state.sublist(index + 1),
      ];
    } else {
      state = [
        ...state,
        ItemCarrito(
          producto: producto,
          cantidad: cantidad,
          modoVenta: ModoVenta.normal,
        ),
      ];
    }
  }

  /// Agrega un producto fraccionable/pesable al ticket.
  /// Cada venta por peso es una línea independiente en el ticket porque
  /// cada porción tiene un peso diferente (ej. cada pollo pesa distinto).
  void agregarFraccionado(Producto producto, double peso, ModoVenta modo) {
    state = [
      ...state,
      ItemCarrito(
        producto: producto,
        cantidad: peso,
        modoVenta: modo,
      ),
    ];
  }

  /// Agrega unidades sueltas al ticket (ej. 3 cigarrillos individuales).
  /// Si ya hay unidades sueltas del mismo producto, acumula la cantidad.
  void agregarSuelto(Producto producto, double cantidadSuelta) {
    final index = state.indexWhere(
      (item) => item.producto.id == producto.id && item.modoVenta == ModoVenta.suelta,
    );

    if (index >= 0) {
      final itemExistente = state[index];
      final nuevaCantidadSuelta = itemExistente.cantidadSuelta + cantidadSuelta;
      // Recalcular la cantidad de empaque de venta que se descuenta del inventario
      final fraccionInventario = producto.unidadesEnEmpaqueVenta > 0
          ? nuevaCantidadSuelta / producto.unidadesEnEmpaqueVenta
          : nuevaCantidadSuelta;

      state = [
        ...state.sublist(0, index),
        itemExistente.copyWith(
          cantidad: fraccionInventario,
          cantidadSuelta: nuevaCantidadSuelta,
        ),
        ...state.sublist(index + 1),
      ];
    } else {
      final fraccionInventario = producto.unidadesEnEmpaqueVenta > 0
          ? cantidadSuelta / producto.unidadesEnEmpaqueVenta
          : cantidadSuelta;

      state = [
        ...state,
        ItemCarrito(
          producto: producto,
          cantidad: fraccionInventario,
          cantidadSuelta: cantidadSuelta,
          modoVenta: ModoVenta.suelta,
        ),
      ];
    }
  }

  /// Ajusta la cantidad exacta. Si es <= 0, remueve el item del carrito.
  void ajustarCantidad(String productoId, double nuevaCantidad) {
    if (nuevaCantidad <= 0) {
      state = state.where((item) => item.producto.id != productoId).toList();
    } else {
      state = state.map((item) {
        if (item.producto.id == productoId) {
          return item.copyWith(cantidad: nuevaCantidad);
        }
        return item;
      }).toList();
    }
  }

  /// Vacía el ticket por completo (Cancelación o Venta completada)
  void limpiarCarrito() {
    state = [];
  }
}

/// Proveedor del carrito reactivo
final carritoProvider = NotifierProvider<CarritoNotifier, List<ItemCarrito>>(
  CarritoNotifier.new,
);

/// Proveedor que calcula el monto total acumulado del ticket
final totalCarritoProvider = Provider<double>((ref) {
  final items = ref.watch(carritoProvider);
  final suma = items.fold<double>(0.0, (acc, item) => acc + item.subtotal);
  return (suma * 100).round() / 100.0;
});

/// Proveedor auxiliar para mostrar al usuario mayor el total de bultos/artículos
final totalArticulosProvider = Provider<double>((ref) {
  final items = ref.watch(carritoProvider);
  return items.fold<double>(0.0, (acc, item) => acc + item.cantidad);
});
