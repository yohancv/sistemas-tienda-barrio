class MovimientoCajaModel {
  final String id;
  final String tenantId;
  final String turnoId;
  final String tipo; // 'ENTRADA' o 'SALIDA'
  final double monto;
  final String motivo;
  final String origenDinero; // 'EFECTIVO_CAJA' o 'BANCO_QR'
  final String categoria; // 'GASTO_TIENDA', 'RETIRO_PERSONAL', 'MERCADERIA_FUTURA', 'AHORRO', 'PAGO_AYUDANTE', 'CAMBIO_SENCILLO', 'OTRO'
  final DateTime createdAt;

  const MovimientoCajaModel({
    required this.id,
    required this.tenantId,
    required this.turnoId,
    required this.tipo,
    required this.monto,
    required this.motivo,
    this.origenDinero = 'EFECTIVO_CAJA',
    this.categoria = 'GASTO_TIENDA',
    required this.createdAt,
  });

  bool get esEntrada => tipo == 'ENTRADA';
  bool get esSalida => tipo == 'SALIDA';

  bool get esOrigenEfectivo => origenDinero == 'EFECTIVO_CAJA';
  bool get esOrigenBancoQr => origenDinero == 'BANCO_QR';

  String get etiquetaOrigen => esOrigenBancoQr ? '📱 QR / Banco' : '💵 Cajón Físico';

  String get etiquetaCategoria {
    switch (categoria) {
      case 'MERCADERIA_FUTURA':
        return '📦 Mercadería Futura';
      case 'RETIRO_PERSONAL':
        return '💰 Retiro Personal';
      case 'AHORRO':
        return '🏦 Ahorro';
      case 'PAGO_AYUDANTE':
        return '🧑‍🤝‍🧑 Pago a Ayudante';
      case 'CAMBIO_SENCILLO':
        return '💵 Sencillo para Cajón';
      case 'GASTO_TIENDA':
        return '🧹 Gasto Tienda';
      case 'OTRO':
      default:
        return '📝 Otro Concepto';
    }
  }

  factory MovimientoCajaModel.fromMap(Map<String, dynamic> map) {
    return MovimientoCajaModel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      turnoId: map['turno_id'] as String,
      tipo: map['tipo'] as String,
      monto: _toDouble(map['monto']),
      motivo: map['motivo'] as String? ?? '',
      origenDinero: map['origen_dinero'] as String? ?? 'EFECTIVO_CAJA',
      categoria: map['categoria'] as String? ?? 'GASTO_TIENDA',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'turno_id': turnoId,
      'tipo': tipo,
      'monto': monto,
      'motivo': motivo,
      'origen_dinero': origenDinero,
      'categoria': categoria,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}
