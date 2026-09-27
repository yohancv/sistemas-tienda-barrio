/// Modelo inmutable de auditoría para movimientos de inventario:
/// Desempaques mayoristas, mermas por rotura o vencimiento y ajustes.
class MovimientoInventario {
  final String id;
  final String tenantId;
  final String productoId;
  final String tipoMovimiento;
  final double cantidad;
  final double costoUnitario;
  final double costoTotal;
  final String? motivo;
  final String? referenciaId;
  final DateTime createdAt;

  const MovimientoInventario({
    required this.id,
    required this.tenantId,
    required this.productoId,
    required this.tipoMovimiento,
    required this.cantidad,
    required this.costoUnitario,
    required this.costoTotal,
    this.motivo,
    this.referenciaId,
    required this.createdAt,
  });

  bool get esDesempaque => tipoMovimiento.startsWith('DESEMPAQUE');
  bool get esMerma => tipoMovimiento.startsWith('MERMA');
  bool get esEntrada => tipoMovimiento == 'DESEMPAQUE_ENTRADA' || tipoMovimiento == 'AJUSTE_POSITIVO';

  String get etiquetaTipo {
    switch (tipoMovimiento) {
      case 'DESEMPAQUE_SALIDA':
        return '📦 Desempaque (Cajas)';
      case 'DESEMPAQUE_ENTRADA':
        return '🍺 Entrada por Desempaque';
      case 'MERMA_ROTURA':
        return '💥 Rotura / Accidente';
      case 'MERMA_VENCIMIENTO':
        return '⏳ Vencimiento';
      case 'MERMA_DETERIORO':
        return '📦 Deterioro de Empaque';
      case 'AJUSTE_POSITIVO':
        return '➕ Ajuste Sobrante';
      case 'AJUSTE_NEGATIVO':
        return '➖ Ajuste Faltante';
      default:
        return tipoMovimiento;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'producto_id': productoId,
      'tipo_movimiento': tipoMovimiento,
      'cantidad': cantidad,
      'costo_unitario': costoUnitario,
      'costo_total': costoTotal,
      'motivo': motivo,
      'referencia_id': referenciaId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MovimientoInventario.fromMap(Map<String, dynamic> map) {
    return MovimientoInventario(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      productoId: map['producto_id'] as String,
      tipoMovimiento: map['tipo_movimiento'] as String? ?? 'AJUSTE_MANUAL',
      cantidad: _toDouble(map['cantidad']),
      costoUnitario: _toDouble(map['costo_unitario']),
      costoTotal: _toDouble(map['costo_total']),
      motivo: map['motivo'] as String?,
      referenciaId: map['referencia_id'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
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
