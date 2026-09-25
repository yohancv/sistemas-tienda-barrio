/// Modelo de Cabecera de Venta (Inmutable)
class Venta {
  final String? id;
  final String tenantId;
  final String? clienteId;
  final double totalVenta;
  final String metodoPago; // 'EFECTIVO', 'QR', 'MIXTO', 'CREDITO_FIADO'
  final double montoRecibido;
  final double cambioEntregado;
  final DateTime fechaVenta;

  const Venta({
    this.id,
    required this.tenantId,
    this.clienteId,
    required this.totalVenta,
    required this.metodoPago,
    this.montoRecibido = 0.0,
    this.cambioEntregado = 0.0,
    required this.fechaVenta,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'tenant_id': tenantId,
      'cliente_id': clienteId,
      'total_venta': totalVenta,
      'metodo_pago': metodoPago,
      'monto_recibido': montoRecibido,
      'cambio_entregado': cambioEntregado,
      'fecha_venta': fechaVenta.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Venta.fromMap(Map<String, dynamic> map) {
    return Venta(
      id: map['id'] as String?,
      tenantId: map['tenant_id'] as String,
      clienteId: map['cliente_id'] as String?,
      totalVenta: _toDouble(map['total_venta']),
      metodoPago: map['metodo_pago'] as String? ?? 'EFECTIVO',
      montoRecibido: _toDouble(map['monto_recibido']),
      cambioEntregado: _toDouble(map['cambio_entregado']),
      fechaVenta: map['fecha_venta'] != null
          ? DateTime.parse(map['fecha_venta'] as String)
          : DateTime.now(),
    );
  }

  Venta copyWith({
    String? id,
    String? tenantId,
    String? clienteId,
    double? totalVenta,
    String? metodoPago,
    double? montoRecibido,
    double? cambioEntregado,
    DateTime? fechaVenta,
  }) {
    return Venta(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      clienteId: clienteId ?? this.clienteId,
      totalVenta: totalVenta ?? this.totalVenta,
      metodoPago: metodoPago ?? this.metodoPago,
      montoRecibido: montoRecibido ?? this.montoRecibido,
      cambioEntregado: cambioEntregado ?? this.cambioEntregado,
      fechaVenta: fechaVenta ?? this.fechaVenta,
    );
  }
}

/// Modelo de Detalle de Venta (Línea de producto vendida)
class DetalleVenta {
  final String? id;
  final String? ventaId;
  final String productoId;
  final double cantidad;
  final double precioUnitario;
  final double costoUnitario; // Congelado para cálculo de Utilidad Neta real
  final double subtotal;

  const DetalleVenta({
    this.id,
    this.ventaId,
    required this.productoId,
    required this.cantidad,
    required this.precioUnitario,
    this.costoUnitario = 0.0,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'producto_id': productoId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'costo_unitario': costoUnitario,
      'subtotal': subtotal,
    };
    if (id != null) map['id'] = id;
    if (ventaId != null) map['venta_id'] = ventaId;
    return map;
  }

  factory DetalleVenta.fromMap(Map<String, dynamic> map) {
    return DetalleVenta(
      id: map['id'] as String?,
      ventaId: map['venta_id'] as String?,
      productoId: map['producto_id'] as String,
      cantidad: _toDouble(map['cantidad']),
      precioUnitario: _toDouble(map['precio_unitario']),
      costoUnitario: _toDouble(map['costo_unitario']),
      subtotal: _toDouble(map['subtotal']),
    );
  }

  DetalleVenta copyWith({
    String? id,
    String? ventaId,
    String? productoId,
    double? cantidad,
    double? precioUnitario,
    double? costoUnitario,
    double? subtotal,
  }) {
    return DetalleVenta(
      id: id ?? this.id,
      ventaId: ventaId ?? this.ventaId,
      productoId: productoId ?? this.productoId,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      costoUnitario: costoUnitario ?? this.costoUnitario,
      subtotal: subtotal ?? this.subtotal,
    );
  }
}

/// Modelo de Desglose de Pagos (Efectivo, QR, Cashback negativo)
class PagoVenta {
  final String? id;
  final String? ventaId;
  final String tenantId;
  final String metodo; // 'EFECTIVO', 'QR', 'TARJETA', 'FIADO'
  final double monto;
  final DateTime createdAt;

  const PagoVenta({
    this.id,
    this.ventaId,
    required this.tenantId,
    required this.metodo,
    required this.monto,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'tenant_id': tenantId,
      'metodo': metodo,
      'monto': monto,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    if (ventaId != null) map['venta_id'] = ventaId;
    return map;
  }

  factory PagoVenta.fromMap(Map<String, dynamic> map) {
    return PagoVenta(
      id: map['id'] as String?,
      ventaId: map['venta_id'] as String?,
      tenantId: map['tenant_id'] as String,
      metodo: map['metodo'] as String? ?? 'EFECTIVO',
      monto: _toDouble(map['monto']),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  PagoVenta copyWith({
    String? id,
    String? ventaId,
    String? tenantId,
    String? metodo,
    double? monto,
    DateTime? createdAt,
  }) {
    return PagoVenta(
      id: id ?? this.id,
      ventaId: ventaId ?? this.ventaId,
      tenantId: tenantId ?? this.tenantId,
      metodo: metodo ?? this.metodo,
      monto: monto ?? this.monto,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Conversor seguro contra tipos numéricos mixtos de PostgreSQL
double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}
