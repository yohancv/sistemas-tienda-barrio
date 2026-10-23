/// Modelo para representar las ventas y cobros del turno activo en la interfaz de Caja
class VentaTurnoModel {
  final String id;
  final String ticketCorto;
  final double totalVenta;
  final String metodoPago; // 'EFECTIVO', 'QR', 'MIXTO', 'CREDITO_FIADO'
  final double montoRecibido;
  final double cambioEntregado;
  final DateTime fechaVenta;
  final String? clienteNombre;
  final String itemsResumen;
  final double totalEfectivo;
  final double totalQr;

  const VentaTurnoModel({
    required this.id,
    required this.ticketCorto,
    required this.totalVenta,
    required this.metodoPago,
    required this.montoRecibido,
    required this.cambioEntregado,
    required this.fechaVenta,
    this.clienteNombre,
    required this.itemsResumen,
    this.totalEfectivo = 0.0,
    this.totalQr = 0.0,
  });

  bool get esQr => metodoPago == 'QR' || totalQr > 0;
  bool get esEfectivo => metodoPago == 'EFECTIVO' || totalEfectivo > 0;
  bool get esMixto => metodoPago == 'MIXTO';
  bool get esFiado => metodoPago == 'CREDITO_FIADO' || metodoPago == 'FIADO';
}
