enum TipoRecarga {
  credito,
  paqueteInternet,
}

enum MetodoPagoRecarga {
  efectivo,
  qr,
}

class RecargaModel {
  final String id;
  final String tenantId;
  final String operadoraId; // 'ENTEL', 'TIGO', 'VIVA'
  final String operadoraNombre;
  final TipoRecarga tipo;
  final double monto;
  final double costoSaldo;
  final double gananciaNeta;
  final double porcentajeComision;
  final MetodoPagoRecarga metodoPago;
  final String? numeroTelefono;
  final String? cajaTurnoId;
  final DateTime createdAt;

  const RecargaModel({
    required this.id,
    required this.tenantId,
    required this.operadoraId,
    required this.operadoraNombre,
    required this.tipo,
    required this.monto,
    required this.costoSaldo,
    required this.gananciaNeta,
    required this.porcentajeComision,
    required this.metodoPago,
    this.numeroTelefono,
    this.cajaTurnoId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'operadora_id': operadoraId,
      'tipo': tipo == TipoRecarga.credito ? 'CREDITO' : 'PAQUETE_INTERNET',
      'monto': monto,
      'costo_saldo': costoSaldo,
      'ganancia_neta': gananciaNeta,
      'porcentaje_comision': porcentajeComision,
      'metodo_pago': metodoPago == MetodoPagoRecarga.efectivo ? 'EFECTIVO' : 'QR',
      'numero_telefono': numeroTelefono,
      'caja_turno_id': cajaTurnoId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory RecargaModel.fromMap(Map<String, dynamic> map, {String? operadoraNombre}) {
    final tipoStr = map['tipo'] as String? ?? 'CREDITO';
    final metodoStr = map['metodo_pago'] as String? ?? 'EFECTIVO';
    final opId = map['operadora_id'] as String? ?? 'ENTEL';

    String defaultNombre = opId;
    if (opId == 'ENTEL') defaultNombre = 'Entel';
    if (opId == 'TIGO') defaultNombre = 'Tigo';
    if (opId == 'VIVA') defaultNombre = 'Viva';

    return RecargaModel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      operadoraId: opId,
      operadoraNombre: operadoraNombre ?? map['operadora_nombre'] as String? ?? defaultNombre,
      tipo: tipoStr == 'PAQUETE_INTERNET' ? TipoRecarga.paqueteInternet : TipoRecarga.credito,
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      costoSaldo: (map['costo_saldo'] as num?)?.toDouble() ?? 0.0,
      gananciaNeta: (map['ganancia_neta'] as num?)?.toDouble() ?? 0.0,
      porcentajeComision: (map['porcentaje_comision'] as num?)?.toDouble() ?? 10.0,
      metodoPago: metodoStr == 'QR' ? MetodoPagoRecarga.qr : MetodoPagoRecarga.efectivo,
      numeroTelefono: map['numero_telefono'] as String?,
      cajaTurnoId: map['caja_turno_id'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class BolsaRecargaModel {
  final String id;
  final String tenantId;
  final String operadoraId;
  final double saldoCargado;
  final double dineroPagado;
  final String origenPago; // 'EFECTIVO_CAJA' o 'BANCO_QR_EXTERNO'
  final String? cajaTurnoId;
  final String? observaciones;
  final DateTime createdAt;

  const BolsaRecargaModel({
    required this.id,
    required this.tenantId,
    required this.operadoraId,
    required this.saldoCargado,
    required this.dineroPagado,
    required this.origenPago,
    this.cajaTurnoId,
    this.observaciones,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'operadora_id': operadoraId,
      'saldo_cargado': saldoCargado,
      'dinero_pagado': dineroPagado,
      'origen_pago': origenPago,
      'caja_turno_id': cajaTurnoId,
      'observaciones': observaciones,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BolsaRecargaModel.fromMap(Map<String, dynamic> map) {
    return BolsaRecargaModel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      operadoraId: map['operadora_id'] as String,
      saldoCargado: (map['saldo_cargado'] as num?)?.toDouble() ?? 0.0,
      dineroPagado: (map['dinero_pagado'] as num?)?.toDouble() ?? 0.0,
      origenPago: map['origen_pago'] as String? ?? 'EFECTIVO_CAJA',
      cajaTurnoId: map['caja_turno_id'] as String?,
      observaciones: map['observaciones'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
