import '../../../inventario/data/models/producto_model.dart';

/// Modelo de Línea de Mercadería comprada (Ítem de Detalle de Compra)
class ItemCompraModel {
  final String? id;
  final String? compraId;
  final String productoId;
  final double cantidad;
  final double costoUnitario;
  final double subtotal;
  final double? nuevoPrecioVenta;

  // Datos para visualización enriquecida
  final String nombreProducto;
  final String? codigoBarras;
  final String tipoEmpaque;
  final double unidadesPorEmpaque;
  final double costoAnterior;
  final double precioVentaActual;

  const ItemCompraModel({
    this.id,
    this.compraId,
    required this.productoId,
    required this.cantidad,
    required this.costoUnitario,
    required this.subtotal,
    this.nuevoPrecioVenta,
    required this.nombreProducto,
    this.codigoBarras,
    this.tipoEmpaque = 'UNIDAD',
    this.unidadesPorEmpaque = 1.0,
    this.costoAnterior = 0.0,
    this.precioVentaActual = 0.0,
  });

  /// Crea un ítem de compra a partir de un Producto del catálogo
  factory ItemCompraModel.desdeProducto(Producto producto, {double cantidad = 1.0}) {
    final costo = producto.costoMayorista > 0 ? producto.costoMayorista : 0.0;
    return ItemCompraModel(
      productoId: producto.id,
      cantidad: cantidad,
      costoUnitario: costo,
      subtotal: costo * cantidad,
      nuevoPrecioVenta: null,
      nombreProducto: producto.nombre,
      codigoBarras: producto.codigoBarras,
      tipoEmpaque: producto.tipoEmpaque,
      unidadesPorEmpaque: producto.unidadesPorEmpaque,
      costoAnterior: costo,
      precioVentaActual: producto.precioVenta,
    );
  }

  /// Indica si el costo subió respecto al costo histórico registrado
  bool get costoSubio => costoAnterior > 0 && costoUnitario > costoAnterior;

  /// Indica si el costo bajó respecto al costo histórico registrado
  bool get costoBajo => costoAnterior > 0 && costoUnitario < costoAnterior;

  /// Variación de costo (positivo si subió, negativo si bajó)
  double get deltaCosto => costoUnitario - costoAnterior;

  /// Margen de ganancia porcentual con el precio de mostrador actual
  double get margenConPrecioActual {
    if (precioVentaActual <= 0) return 0.0;
    return ((precioVentaActual - costoUnitario) / precioVentaActual) * 100.0;
  }

  /// Margen si el usuario definió un nuevo precio de venta
  double get margenEfectivo {
    final pv = (nuevoPrecioVenta != null && nuevoPrecioVenta! > 0)
        ? nuevoPrecioVenta!
        : precioVentaActual;
    if (pv <= 0) return 0.0;
    return ((pv - costoUnitario) / pv) * 100.0;
  }

  /// Advierte si el margen es menor al 10% o negativo
  bool get margenPeligroso => margenEfectivo < 10.0;

  ItemCompraModel copyWith({
    String? id,
    String? compraId,
    String? productoId,
    double? cantidad,
    double? costoUnitario,
    double? subtotal,
    double? nuevoPrecioVenta,
    bool clearNuevoPrecio = false,
    String? nombreProducto,
    String? codigoBarras,
    String? tipoEmpaque,
    double? unidadesPorEmpaque,
    double? costoAnterior,
    double? precioVentaActual,
  }) {
    final cant = cantidad ?? this.cantidad;
    final costo = costoUnitario ?? this.costoUnitario;
    return ItemCompraModel(
      id: id ?? this.id,
      compraId: compraId ?? this.compraId,
      productoId: productoId ?? this.productoId,
      cantidad: cant,
      costoUnitario: costo,
      subtotal: subtotal ?? (cant * costo),
      nuevoPrecioVenta: clearNuevoPrecio ? null : (nuevoPrecioVenta ?? this.nuevoPrecioVenta),
      nombreProducto: nombreProducto ?? this.nombreProducto,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      tipoEmpaque: tipoEmpaque ?? this.tipoEmpaque,
      unidadesPorEmpaque: unidadesPorEmpaque ?? this.unidadesPorEmpaque,
      costoAnterior: costoAnterior ?? this.costoAnterior,
      precioVentaActual: precioVentaActual ?? this.precioVentaActual,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (compraId != null) 'compra_id': compraId,
      'producto_id': productoId,
      'cantidad': cantidad,
      'costo_unitario': costoUnitario,
      'subtotal': subtotal,
      if (nuevoPrecioVenta != null && nuevoPrecioVenta! > 0)
        'nuevo_precio_venta': nuevoPrecioVenta,
    };
  }

  factory ItemCompraModel.fromMap(Map<String, dynamic> map) {
    String nombre = 'Producto';
    String? barcode;
    String empaque = 'UNIDAD';
    double udsEmpaque = 1.0;
    double pVenta = 0.0;

    if (map['productos'] != null && map['productos'] is Map) {
      final p = map['productos'] as Map<String, dynamic>;
      nombre = p['nombre'] as String? ?? 'Producto';
      barcode = p['codigo_barras'] as String?;
      empaque = p['tipo_empaque'] as String? ?? 'UNIDAD';
      udsEmpaque = (p['unidades_por_empaque'] as num?)?.toDouble() ?? 1.0;
      pVenta = (p['precio_venta'] as num?)?.toDouble() ?? 0.0;
    }

    final cant = _toDouble(map['cantidad']);
    final costo = _toDouble(map['costo_unitario']);

    return ItemCompraModel(
      id: map['id'] as String?,
      compraId: map['compra_id'] as String?,
      productoId: map['producto_id'] as String,
      cantidad: cant,
      costoUnitario: costo,
      subtotal: _toDouble(map['subtotal']),
      nuevoPrecioVenta: map['nuevo_precio_venta'] != null
          ? _toDouble(map['nuevo_precio_venta'])
          : null,
      nombreProducto: nombre,
      codigoBarras: barcode,
      tipoEmpaque: empaque,
      unidadesPorEmpaque: udsEmpaque,
      costoAnterior: costo,
      precioVentaActual: pVenta,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
