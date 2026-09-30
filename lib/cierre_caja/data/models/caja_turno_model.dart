import 'dart:convert';

class CajaTurnoModel {
  final String id;
  final String tenantId;
  final String? usuarioId;
  final DateTime fechaApertura;
  final double montoInicial;
  final DateTime? fechaCierre;
  final double totalVentasEfectivo;
  final double totalVentasQr;
  final double totalFiadosOtorgados;
  final double totalFiadosCobradosEfectivo;
  final double totalFiadosCobradosQr;
  final double totalSalidasManuales;
  final double totalEntradasManuales;
  final double montoEsperadoEfectivo;
  final double? montoRealContado;
  final double? diferencia;
  final Map<String, int>? desgloseEfectivo;
  final String? observacionesCierre;
  final String estado; // 'ABIERTA', 'CERRADA'
  final DateTime? createdAt;

  const CajaTurnoModel({
    required this.id,
    required this.tenantId,
    this.usuarioId,
    required this.fechaApertura,
    required this.montoInicial,
    this.fechaCierre,
    this.totalVentasEfectivo = 0.0,
    this.totalVentasQr = 0.0,
    this.totalFiadosOtorgados = 0.0,
    this.totalFiadosCobradosEfectivo = 0.0,
    this.totalFiadosCobradosQr = 0.0,
    this.totalSalidasManuales = 0.0,
    this.totalEntradasManuales = 0.0,
    this.montoEsperadoEfectivo = 0.0,
    this.montoRealContado,
    this.diferencia,
    this.desgloseEfectivo,
    this.observacionesCierre,
    this.estado = 'ABIERTA',
    this.createdAt,
  });

  bool get estaAbierta => estado == 'ABIERTA';

  factory CajaTurnoModel.fromMap(Map<String, dynamic> map) {
    Map<String, int>? desglose;
    if (map['desglose_efectivo'] != null) {
      try {
        final dynamic raw = map['desglose_efectivo'];
        final Map<String, dynamic> decoded =
            raw is String ? jsonDecode(raw) : Map<String, dynamic>.from(raw as Map);
        desglose = decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }

    return CajaTurnoModel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      usuarioId: map['usuario_id'] as String?,
      fechaApertura: DateTime.parse(map['fecha_apertura'] as String),
      montoInicial: _toDouble(map['monto_inicial']),
      fechaCierre: map['fecha_cierre'] != null
          ? DateTime.parse(map['fecha_cierre'] as String)
          : null,
      totalVentasEfectivo: _toDouble(map['total_ventas_efectivo']),
      totalVentasQr: _toDouble(map['total_ventas_qr']),
      totalFiadosOtorgados: _toDouble(map['total_fiados_otorgados']),
      totalFiadosCobradosEfectivo: _toDouble(map['total_fiados_cobrados_efectivo']),
      totalFiadosCobradosQr: _toDouble(map['total_fiados_cobrados_qr']),
      totalSalidasManuales: _toDouble(map['total_salidas_manuales']),
      totalEntradasManuales: _toDouble(map['total_entradas_manuales']),
      montoEsperadoEfectivo: _toDouble(map['monto_esperado_efectivo']),
      montoRealContado: map['monto_real_contado'] != null
          ? _toDouble(map['monto_real_contado'])
          : null,
      diferencia: map['diferencia'] != null ? _toDouble(map['diferencia']) : null,
      desgloseEfectivo: desglose,
      observacionesCierre: map['observaciones_cierre'] as String?,
      estado: map['estado'] as String? ?? 'ABIERTA',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      if (usuarioId != null) 'usuario_id': usuarioId,
      'fecha_apertura': fechaApertura.toIso8601String(),
      'monto_inicial': montoInicial,
      if (fechaCierre != null) 'fecha_cierre': fechaCierre!.toIso8601String(),
      'total_ventas_efectivo': totalVentasEfectivo,
      'total_ventas_qr': totalVentasQr,
      'total_fiados_otorgados': totalFiadosOtorgados,
      'total_fiados_cobrados_efectivo': totalFiadosCobradosEfectivo,
      'total_fiados_cobrados_qr': totalFiadosCobradosQr,
      'total_salidas_manuales': totalSalidasManuales,
      'total_entradas_manuales': totalEntradasManuales,
      'monto_esperado_efectivo': montoEsperadoEfectivo,
      if (montoRealContado != null) 'monto_real_contado': montoRealContado,
      if (diferencia != null) 'diferencia': diferencia,
      if (desgloseEfectivo != null) 'desglose_efectivo': desgloseEfectivo,
      if (observacionesCierre != null) 'observaciones_cierre': observacionesCierre,
      'estado': estado,
    };
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}
