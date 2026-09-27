/// Modelo inmutable para los abonos realizados a la cuenta de fiados
class AbonoDeuda {
  final String id;
  final String tenantId;
  final String clienteId;
  final double monto;
  final String metodoPago;
  final String? notas;
  final DateTime fechaAbono;

  const AbonoDeuda({
    required this.id,
    required this.tenantId,
    required this.clienteId,
    required this.monto,
    this.metodoPago = 'EFECTIVO',
    this.notas,
    required this.fechaAbono,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'cliente_id': clienteId,
      'monto': monto,
      'metodo_pago': metodoPago,
      'notas': notas,
      'fecha_abono': fechaAbono.toIso8601String(),
    };
  }

  factory AbonoDeuda.fromMap(Map<String, dynamic> map) {
    return AbonoDeuda(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      clienteId: map['cliente_id'] as String,
      monto: _toDouble(map['monto']),
      metodoPago: map['metodo_pago'] as String? ?? 'EFECTIVO',
      notas: map['notas'] as String?,
      fechaAbono: map['fecha_abono'] != null
          ? DateTime.parse(map['fecha_abono'] as String)
          : DateTime.now(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
