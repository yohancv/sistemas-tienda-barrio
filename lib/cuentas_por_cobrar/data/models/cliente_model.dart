enum SemaforoCredito { alDia, deudaNormal, limiteAlcanzado }

class Cliente {
  final String id;
  final String tenantId;
  final String nombre;
  final String? telefono;
  final double limiteCredito;
  final double saldoActual;
  final String? notas;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Cliente({
    required this.id,
    required this.tenantId,
    required this.nombre,
    this.telefono,
    this.limiteCredito = 100.0,
    this.saldoActual = 0.0,
    this.notas,
    this.activo = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Indica si el cliente tiene saldo pendiente por pagar
  bool get tieneDeuda => saldoActual > 0.05;

  /// Monto restante que el cliente aún puede sacar fiado
  double get creditoDisponible {
    final disp = limiteCredito - saldoActual;
    return disp > 0 ? disp : 0.0;
  }

  /// Indica si el cliente alcanzó o sobrepasó su límite de crédito
  bool get limiteSuperado => saldoActual >= limiteCredito;

  /// Semáforo de solvencia para visualización rápida en el mostrador
  SemaforoCredito get semaforo {
    if (!tieneDeuda) return SemaforoCredito.alDia;
    if (saldoActual < limiteCredito) return SemaforoCredito.deudaNormal;
    return SemaforoCredito.limiteAlcanzado;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'nombre': nombre,
      'telefono': telefono,
      'limite_credito': limiteCredito,
      'saldo_actual': saldoActual,
      'notas': notas,
      'activo': activo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      nombre: map['nombre'] as String? ?? '',
      telefono: map['telefono'] as String?,
      limiteCredito: _toDouble(map['limite_credito']),
      saldoActual: _toDouble(map['saldo_actual']),
      notas: map['notas'] as String?,
      activo: map['activo'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Cliente copyWith({
    String? id,
    String? tenantId,
    String? nombre,
    String? telefono,
    double? limiteCredito,
    double? saldoActual,
    String? notas,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Cliente(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      limiteCredito: limiteCredito ?? this.limiteCredito,
      saldoActual: saldoActual ?? this.saldoActual,
      notas: notas ?? this.notas,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
