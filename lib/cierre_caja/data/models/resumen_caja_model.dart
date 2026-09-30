class ResumenCajaModel {
  final String turnoId;
  final String estado;
  final DateTime fechaApertura;
  final double montoInicial;
  final double totalVentasEfectivo;
  final double totalVentasQr;
  final double totalFiadosOtorgados;
  final double totalFiadosCobradosEfectivo;
  final double totalFiadosCobradosQr;
  final double totalEntradasManuales;
  final double totalSalidasManuales;
  final double montoEsperadoEfectivo;

  const ResumenCajaModel({
    required this.turnoId,
    required this.estado,
    required this.fechaApertura,
    required this.montoInicial,
    required this.totalVentasEfectivo,
    required this.totalVentasQr,
    required this.totalFiadosOtorgados,
    required this.totalFiadosCobradosEfectivo,
    required this.totalFiadosCobradosQr,
    required this.totalEntradasManuales,
    required this.totalSalidasManuales,
    required this.montoEsperadoEfectivo,
  });

  /// Total de ingresos brutos del día (Ventas efectivo + Ventas QR + Fiados cobrados en efectivo + Fiados cobrados en QR)
  double get totalIngresosDia =>
      totalVentasEfectivo +
      totalVentasQr +
      totalFiadosCobradosEfectivo +
      totalFiadosCobradosQr;

  factory ResumenCajaModel.fromMap(Map<String, dynamic> map) {
    return ResumenCajaModel(
      turnoId: map['turno_id'] as String? ?? '',
      estado: map['estado'] as String? ?? 'ABIERTA',
      fechaApertura: map['fecha_apertura'] != null
          ? DateTime.parse(map['fecha_apertura'] as String)
          : DateTime.now(),
      montoInicial: _toDouble(map['monto_inicial']),
      totalVentasEfectivo: _toDouble(map['total_ventas_efectivo']),
      totalVentasQr: _toDouble(map['total_ventas_qr']),
      totalFiadosOtorgados: _toDouble(map['total_fiados_otorgados']),
      totalFiadosCobradosEfectivo: _toDouble(map['total_fiados_cobrados_efectivo']),
      totalFiadosCobradosQr: _toDouble(map['total_fiados_cobrados_qr']),
      totalEntradasManuales: _toDouble(map['total_entradas_manuales']),
      totalSalidasManuales: _toDouble(map['total_salidas_manuales']),
      montoEsperadoEfectivo: _toDouble(map['monto_esperado_efectivo']),
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}
