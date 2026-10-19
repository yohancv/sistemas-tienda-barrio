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
  final double totalRetirosQr;
  final double totalSalidasTienda;
  final double totalSalidasPersonal;
  final double totalMercaderiaFutura;
  final double saldoNetoQr;
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
    this.totalRetirosQr = 0.0,
    this.totalSalidasTienda = 0.0,
    this.totalSalidasPersonal = 0.0,
    this.totalMercaderiaFutura = 0.0,
    this.saldoNetoQr = 0.0,
    required this.montoEsperadoEfectivo,
  });

  /// Total de ingresos brutos cobrados en el turno (Ventas efectivo + Ventas QR + Abonos de fiados)
  double get totalIngresosDia =>
      totalVentasEfectivo +
      totalVentasQr +
      totalFiadosCobradosEfectivo +
      totalFiadosCobradosQr;

  /// Total de dinero real disponible sumando cajón físico y banco QR
  double get totalDineroDisponible =>
      montoEsperadoEfectivo + saldoNetoQr;

  /// Total de dinero que ha salido en el turno (Caja física + Cajero QR)
  double get totalSalidasGlobales =>
      totalSalidasManuales + totalRetirosQr;

  /// Margen neto operativo del turno (Ingresos del día - Gastos operativos de la tienda)
  /// Sin contar retiros personales ni apartados de ahorro.
  double get balanceOperativoTienda =>
      totalIngresosDia - totalSalidasTienda;

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
      totalRetirosQr: _toDouble(map['total_retiros_qr']),
      totalSalidasTienda: _toDouble(map['total_salidas_tienda']),
      totalSalidasPersonal: _toDouble(map['total_salidas_personal']),
      totalMercaderiaFutura: _toDouble(map['total_mercaderia_futura']),
      saldoNetoQr: _toDouble(map['saldo_neto_qr']),
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
