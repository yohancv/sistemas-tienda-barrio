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

  /// Venta directa por paquete/caja cerrado (ej. 1 caja de cerveza de 24 uds, paquete de velas, etc.)
  porEmpaqueMayorista,
}

class ItemCarrito {
  final String id;
  final Producto producto;
  final double cantidad;
  final ModoVenta modoVenta;

  /// Para venta suelta: cuántas unidades sueltas pidió (ej. 3 cigarrillos)
  final double cantidadSuelta;

  ItemCarrito({
    String? id,
    required this.producto,
    required this.cantidad,
    this.modoVenta = ModoVenta.normal,
    this.cantidadSuelta = 0.0,
  }) : id = id ??
            (modoVenta == ModoVenta.porPeso || modoVenta == ModoVenta.porDinero
                ? '${producto.id}_${modoVenta.name}_${DateTime.now().microsecondsSinceEpoch}'
                : '${producto.id}_${modoVenta.name}');

  /// Subtotal redondeado a 2 decimales para evitar desajustes de coma flotante.
  /// Calcula según el modo de venta:
  /// - Normal: cantidad * precioVenta
  /// - Suelta: cantidadSuelta * precioVentaSuelta
  /// - PorEmpaqueMayorista: cantidad (paquetes) * precioVentaEmpaqueEfectivo
  /// - PorPeso: cantidad * precioVenta (donde cantidad son los kilos)
  /// - PorDinero: se ingresó directamente el monto, guardado en cantidad * precioVenta
  double get subtotal {
    double calculo;
    if (modoVenta == ModoVenta.suelta) {
      calculo = cantidadSuelta * producto.precioVentaSuelta;
    } else if (modoVenta == ModoVenta.porEmpaqueMayorista) {
      calculo = cantidad * producto.precioVentaEmpaqueEfectivo;
    } else {
      calculo = cantidad * producto.precioVenta;
    }
    return (calculo * 100).round() / 100.0;
  }

  /// Cantidad que se descuenta del inventario según el modo de venta:
  /// - Normal: cantidad directa (1 botella = 1 del stock)
  /// - Suelta: fracción del empaque de venta (3 cigarrillos / 20 = 0.15 cajetillas)
  /// - PorEmpaqueMayorista: cantidad * unidadesPorEmpaque (1 paquete de 24 = 24 unidades del stock)
  /// - PorPeso / PorDinero: el peso exacto en kg/lb
  double get descuentoInventario {
    if (modoVenta == ModoVenta.suelta && producto.unidadesEnEmpaqueVenta > 0) {
      return cantidadSuelta / producto.unidadesEnEmpaqueVenta;
    } else if (modoVenta == ModoVenta.porEmpaqueMayorista) {
      return cantidad * (producto.unidadesPorEmpaque > 0 ? producto.unidadesPorEmpaque : 1.0);
    }
    return cantidad;
  }

  /// Etiqueta para mostrar en el ticket (ej. "3 cigarrillos", "1.85 kg", "1 ud", "1 Paquete (24 uds)")
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
      case ModoVenta.porEmpaqueMayorista:
        final cantInt = cantidad.toInt();
        final udsTotal = (cantidad * (producto.unidadesPorEmpaque > 0 ? producto.unidadesPorEmpaque : 1.0)).toInt();
        final nombre = cantInt == 1 ? producto.nombreEmpaqueLegible : producto.nombreEmpaquePlural;
        return '$cantInt $nombre ($udsTotal uds)';
      case ModoVenta.normal:
        final uds = cantidad.truncateToDouble() == cantidad
            ? cantidad.toInt().toString()
            : cantidad.toStringAsFixed(2);
        return '$uds ud${cantidad != 1 ? 's' : ''}';
    }
  }

  ItemCarrito copyWith({
    String? id,
    Producto? producto,
    double? cantidad,
    ModoVenta? modoVenta,
    double? cantidadSuelta,
  }) {
    return ItemCarrito(
      id: id ?? this.id,
      producto: producto ?? this.producto,
      cantidad: cantidad ?? this.cantidad,
      modoVenta: modoVenta ?? this.modoVenta,
      cantidadSuelta: cantidadSuelta ?? this.cantidadSuelta,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemCarrito &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          cantidad == other.cantidad &&
          cantidadSuelta == other.cantidadSuelta &&
          modoVenta == other.modoVenta;

  @override
  int get hashCode =>
      id.hashCode ^ cantidad.hashCode ^ cantidadSuelta.hashCode ^ modoVenta.hashCode;
}
