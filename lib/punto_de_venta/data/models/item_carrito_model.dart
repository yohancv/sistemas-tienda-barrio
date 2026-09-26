import '../../../inventario/data/models/producto_model.dart';

/// Modo de venta seleccionado por el usuario en el modal de selección
enum ModoVenta {
  /// Venta estándar por unidad entera (botella, cajetilla, paquete)
  normal,

  /// Venta suelta al detalle (cigarrillos individuales, pastillas sueltas)
  suelta,

  /// Venta fraccionada por peso de balanza (kilos, gramos, libras)
  porPeso,

  /// Venta fraccionada por monto de dinero (ej. "dame 10 Bs de coca")
  porDinero,
}

class ItemCarrito {
  final Producto producto;
  final double cantidad;
  final ModoVenta modoVenta;

  /// Para venta suelta: cuántas unidades sueltas pidió (ej. 3 cigarrillos)
  final double cantidadSuelta;

  const ItemCarrito({
    required this.producto,
    required this.cantidad,
    this.modoVenta = ModoVenta.normal,
    this.cantidadSuelta = 0.0,
  });

  /// Subtotal redondeado a 2 decimales para evitar desajustes de coma flotante.
  /// Calcula según el modo de venta:
  /// - Normal: cantidad * precioVenta
  /// - Suelta: cantidadSuelta * precioVentaSuelta
  /// - PorPeso: cantidad * precioVenta (donde cantidad son los kilos)
  /// - PorDinero: se ingresó directamente el monto, guardado en cantidad * precioVenta
  double get subtotal {
    double calculo;
    if (modoVenta == ModoVenta.suelta) {
      calculo = cantidadSuelta * producto.precioVentaSuelta;
    } else {
      calculo = cantidad * producto.precioVenta;
    }
    return (calculo * 100).round() / 100.0;
  }

  /// Cantidad que se descuenta del inventario según el modo de venta:
  /// - Normal: cantidad directa (1 botella = 1 del stock)
  /// - Suelta: fracción del empaque de venta (3 cigarrillos / 20 = 0.15 cajetillas)
  /// - PorPeso / PorDinero: el peso exacto en kg/lb
  double get descuentoInventario {
    if (modoVenta == ModoVenta.suelta && producto.unidadesEnEmpaqueVenta > 0) {
      return cantidadSuelta / producto.unidadesEnEmpaqueVenta;
    }
    return cantidad;
  }

  /// Etiqueta para mostrar en el ticket (ej. "3 cigarrillos", "1.85 kg", "1 ud")
  String get etiquetaCantidad {
    switch (modoVenta) {
      case ModoVenta.suelta:
        final uds = cantidadSuelta.truncateToDouble() == cantidadSuelta
            ? cantidadSuelta.toInt().toString()
            : cantidadSuelta.toStringAsFixed(1);
        return '$uds ${producto.nombreUnidadSuelta}${cantidadSuelta != 1 ? 's' : ''}';
      case ModoVenta.porPeso:
      case ModoVenta.porDinero:
        return '${cantidad.toStringAsFixed(producto.tipoUnidad == 'FRACCIONABLE' ? 3 : 2)} kg';
      case ModoVenta.normal:
        final uds = cantidad.truncateToDouble() == cantidad
            ? cantidad.toInt().toString()
            : cantidad.toStringAsFixed(2);
        return '$uds ud${cantidad != 1 ? 's' : ''}';
    }
  }

  ItemCarrito copyWith({
    Producto? producto,
    double? cantidad,
    ModoVenta? modoVenta,
    double? cantidadSuelta,
  }) {
    return ItemCarrito(
      producto: producto ?? this.producto,
      cantidad: cantidad ?? this.cantidad,
      modoVenta: modoVenta ?? this.modoVenta,
      cantidadSuelta: cantidadSuelta ?? this.cantidadSuelta,
    );
  }
}
