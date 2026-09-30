/// Modelo de Cabecera de Compra / Nota de Entrega de Mercadería
class CompraModel {
  final String id;
  final String tenantId;
  final String? proveedorId;
  final String? numeroComprobante;
  final double totalCompra;
  final String metodoPago; // 'EFECTIVO_CAJA', 'EFECTIVO_EXTERNO_ATM', 'QR_BANCO', 'PAGO_MIXTO'
  final double montoPagadoCaja;
  final double montoPagadoExterno;
  final String? cajaTurnoId;
  final String? observaciones;
  final DateTime fechaCompra;
  final String? usuarioId;

  // Datos enriquecidos mediante JOIN con proveedores
  final String? nombreProveedor;
  final int? cantidadArticulos;

  const CompraModel({
    required this.id,
    required this.tenantId,
    this.proveedorId,
    this.numeroComprobante,
    required this.totalCompra,
    required this.metodoPago,
    this.montoPagadoCaja = 0.0,
    this.montoPagadoExterno = 0.0,
    this.cajaTurnoId,
    this.observaciones,
    required this.fechaCompra,
    this.usuarioId,
    this.nombreProveedor,
    this.cantidadArticulos,
  });

  /// Etiqueta visual amigable del método de pago
  String get etiquetaMetodoPago {
    switch (metodoPago) {
      case 'EFECTIVO_CAJA':
        return '💵 Efectivo de Caja';
      case 'EFECTIVO_EXTERNO_ATM':
        return '🏧 Dinero Propio / Cajero';
      case 'QR_BANCO':
        return '📱 QR / Banca Móvil';
      case 'PAGO_MIXTO':
        return '🔀 Pago Mixto (Caja + Billetera)';
      default:
        return metodoPago;
    }
  }

  bool get salioDeCaja => montoPagadoCaja > 0;

  CompraModel copyWith({
    String? id,
    String? tenantId,
    String? proveedorId,
    String? numeroComprobante,
    double? totalCompra,
    String? metodoPago,
    double? montoPagadoCaja,
    double? montoPagadoExterno,
    String? cajaTurnoId,
    String? observaciones,
    DateTime? fechaCompra,
    String? usuarioId,
    String? nombreProveedor,
    int? cantidadArticulos,
  }) {
    return CompraModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      proveedorId: proveedorId ?? this.proveedorId,
      numeroComprobante: numeroComprobante ?? this.numeroComprobante,
      totalCompra: totalCompra ?? this.totalCompra,
      metodoPago: metodoPago ?? this.metodoPago,
      montoPagadoCaja: montoPagadoCaja ?? this.montoPagadoCaja,
      montoPagadoExterno: montoPagadoExterno ?? this.montoPagadoExterno,
      cajaTurnoId: cajaTurnoId ?? this.cajaTurnoId,
      observaciones: observaciones ?? this.observaciones,
      fechaCompra: fechaCompra ?? this.fechaCompra,
      usuarioId: usuarioId ?? this.usuarioId,
      nombreProveedor: nombreProveedor ?? this.nombreProveedor,
      cantidadArticulos: cantidadArticulos ?? this.cantidadArticulos,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'proveedor_id': proveedorId,
      'numero_comprobante': numeroComprobante,
      'total_compra': totalCompra,
      'metodo_pago': metodoPago,
      'monto_pagado_caja': montoPagadoCaja,
      'monto_pagado_externo': montoPagadoExterno,
      'caja_turno_id': cajaTurnoId,
      'observaciones': observaciones,
      'fecha_compra': fechaCompra.toIso8601String(),
      'usuario_id': usuarioId,
    };
  }

  factory CompraModel.fromMap(Map<String, dynamic> map) {
    String? proveedor;
    if (map['proveedores'] != null && map['proveedores'] is Map) {
      proveedor = map['proveedores']['nombre_empresa'] as String?;
    }

    return CompraModel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      proveedorId: map['proveedor_id'] as String?,
      numeroComprobante: map['numero_comprobante'] as String?,
      totalCompra: _toDouble(map['total_compra']),
      metodoPago: map['metodo_pago'] as String? ?? 'EFECTIVO_EXTERNO_ATM',
      montoPagadoCaja: _toDouble(map['monto_pagado_caja']),
      montoPagadoExterno: _toDouble(map['monto_pagado_externo']),
      cajaTurnoId: map['caja_turno_id'] as String?,
      observaciones: map['observaciones'] as String?,
      fechaCompra: map['fecha_compra'] != null
          ? DateTime.parse(map['fecha_compra'] as String)
          : DateTime.now(),
      usuarioId: map['usuario_id'] as String?,
      nombreProveedor: proveedor,
      cantidadArticulos: map['detalle_compras'] != null && map['detalle_compras'] is List
          ? (map['detalle_compras'] as List).length
          : null,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
