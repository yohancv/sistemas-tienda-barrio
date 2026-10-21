class OperadoraModel {
  final String id; // 'ENTEL', 'TIGO', 'VIVA'
  final String tenantId;
  final String nombre;
  final bool activa;
  final double saldoActual;
  final double saldoAlertaMinimo;
  final double comisionPorcentaje;
  final String colorHex;
  final DateTime updatedAt;

  const OperadoraModel({
    required this.id,
    required this.tenantId,
    required this.nombre,
    required this.activa,
    required this.saldoActual,
    this.saldoAlertaMinimo = 20.0,
    this.comisionPorcentaje = 10.0,
    required this.colorHex,
    required this.updatedAt,
  });

  bool get saldoBajo => activa && saldoActual <= saldoAlertaMinimo;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'nombre': nombre,
      'activa': activa ? 1 : 0,
      'saldo_actual': saldoActual,
      'saldo_alerta_minimo': saldoAlertaMinimo,
      'comision_porcentaje': comisionPorcentaje,
      'color_hex': colorHex,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory OperadoraModel.fromMap(Map<String, dynamic> map) {
    return OperadoraModel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      nombre: map['nombre'] as String,
      activa: (map['activa'] as num?) == 1,
      saldoActual: (map['saldo_actual'] as num?)?.toDouble() ?? 0.0,
      saldoAlertaMinimo: (map['saldo_alerta_minimo'] as num?)?.toDouble() ?? 20.0,
      comisionPorcentaje: (map['comision_porcentaje'] as num?)?.toDouble() ?? 10.0,
      colorHex: map['color_hex'] as String? ?? '#005CA9',
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  OperadoraModel copyWith({
    String? id,
    String? tenantId,
    String? nombre,
    bool? activa,
    double? saldoActual,
    double? saldoAlertaMinimo,
    double? comisionPorcentaje,
    String? colorHex,
    DateTime? updatedAt,
  }) {
    return OperadoraModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      nombre: nombre ?? this.nombre,
      activa: activa ?? this.activa,
      saldoActual: saldoActual ?? this.saldoActual,
      saldoAlertaMinimo: saldoAlertaMinimo ?? this.saldoAlertaMinimo,
      comisionPorcentaje: comisionPorcentaje ?? this.comisionPorcentaje,
      colorHex: colorHex ?? this.colorHex,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
