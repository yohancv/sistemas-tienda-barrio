import 'producto_model.dart';

/// Modelo de datos que representa un producto sugerido a reponer en la lista de compras.
/// Soporta empaques mayoristas (cajas, paquetes, fardos) y unidades sueltas.
class ItemReposicion {
  final Producto producto;
  final double cantidadSugerida;
  final double cantidadAComprar;

  const ItemReposicion({
    required this.producto,
    required this.cantidadSugerida,
    required this.cantidadAComprar,
  });

  /// Costo mayorista unitario del producto
  double get costoMayorista => producto.costoMayorista;

  /// Si tiene empaque mayorista, el subtotal se calcula por empaques cerrados
  /// Si no, se calcula por unidades sueltas
  double get subtotalEstimado {
    if (producto.tieneEmpaqueMayorista && producto.costoPorEmpaque > 0) {
      return cantidadAComprar * producto.costoPorEmpaque;
    }
    return cantidadAComprar * producto.costoMayorista;
  }

  /// Indica si el producto se fracciona o si es por unidades enteras
  bool get esFraccionable => producto.esFraccionable;

  /// Indica si la reposición se mide en empaques mayoristas
  bool get esEmpaqueado => producto.tieneEmpaqueMayorista;

  /// Identificador único del producto
  String get id => producto.id;

  /// Nombre del producto
  String get nombre => producto.nombre;

  /// Stock actual en inventario
  double get stockActual => producto.stockActual;

  /// Stock mínimo configurado
  double get stockMinimo => producto.stockMinimo;

  /// Etiqueta legible de la unidad de compra (ej. "Caja de 12", "Kilo")
  String get etiquetaUnidadCompra => producto.etiquetaEmpaque;

  /// Costo por unidad de compra (empaque o unitario)
  double get costoPorUnidadCompra {
    if (producto.tieneEmpaqueMayorista && producto.costoPorEmpaque > 0) {
      return producto.costoPorEmpaque;
    }
    return producto.costoMayorista;
  }

  /// Equivalencia de unidades sueltas representadas por la cantidad a comprar
  double get equivalenciaUnidadesSueltas {
    if (producto.tieneEmpaqueMayorista) {
      return cantidadAComprar * producto.unidadesPorEmpaque;
    }
    return cantidadAComprar;
  }

  ItemReposicion copyWith({
    Producto? producto,
    double? cantidadSugerida,
    double? cantidadAComprar,
  }) {
    return ItemReposicion(
      producto: producto ?? this.producto,
      cantidadSugerida: cantidadSugerida ?? this.cantidadSugerida,
      cantidadAComprar: cantidadAComprar ?? this.cantidadAComprar,
    );
  }
}
