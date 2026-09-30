class MovimientoCajaModel {
  final String id;
  final String tenantId;
  final String turnoId;
  final String tipo; // 'ENTRADA' o 'SALIDA'
  final double monto;
  final String motivo;
  final DateTime createdAt;

  const MovimientoCajaModel({
    required this.id,
    required this.tenantId,
    required this.turnoId,
    required this.tipo,
    required this.monto,
    required this.motivo,
    required this.createdAt,
  });

  bool get esEntrada => tipo == 'ENTRADA';
  bool get esSalida => tipo == 'SALIDA';

  factory MovimientoCajaModel.fromMap(Map<String, dynamic> map) {
    return MovimientoCajaModel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      turnoId: map['turno_id'] as String,
      tipo: map['tipo'] as String,
      monto: _toDouble(map['monto']),
      motivo: map['motivo'] as String? ?? '',
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
