/// Modelo inmutable de auditoría para movimientos de inventario:
/// Ventas, desempaques mayoristas, mermas por rotura o vencimiento, compras y ajustes de catálogo.
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
  final double? stockAnterior;
  final double? stockPosterior;
  final String? usuarioId;
  final DateTime createdAt;

  // Datos enriquecidos mediante JOIN con la tabla productos
  final String? nombreProducto;
  final String? codigoBarrasProducto;
  final String? categoriaProducto;

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
    this.stockAnterior,
    this.stockPosterior,
    this.usuarioId,
    required this.createdAt,
    this.nombreProducto,
    this.codigoBarrasProducto,
    this.categoriaProducto,
  });

  bool get esVenta => tipoMovimiento == 'VENTA';
  bool get esDesempaque => tipoMovimiento.startsWith('DESEMPAQUE');
  bool get esMerma => tipoMovimiento.startsWith('MERMA');
  bool get esAjuste => tipoMovimiento.startsWith('AJUSTE');
  bool get esEntradaCompra => tipoMovimiento == 'ENTRADA_COMPRA';

  bool get esEntrada =>
      tipoMovimiento == 'DESEMPAQUE_ENTRADA' ||
      tipoMovimiento == 'AJUSTE_POSITIVO' ||
      tipoMovimiento == 'ENTRADA_COMPRA';

  bool get esSalida =>
      tipoMovimiento == 'VENTA' ||
      esMerma ||
      tipoMovimiento == 'DESEMPAQUE_SALIDA' ||
      tipoMovimiento == 'AJUSTE_NEGATIVO';

  String get etiquetaTipo {
    switch (tipoMovimiento) {
      case 'VENTA':
        return '🛒 Venta mostrador';
      case 'ENTRADA_COMPRA':
        return '🚚 Compra Proveedor';
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
      case 'AJUSTE_MANUAL':
        return '⚙️ Ajuste Manual';
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
      'stock_anterior': ?stockAnterior,
      'stock_posterior': ?stockPosterior,
      'usuario_id': ?usuarioId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MovimientoInventario.fromMap(Map<String, dynamic> map) {
    String? nombre;
    String? codigoBarras;
    String? categoria;

    if (map['productos'] != null && map['productos'] is Map) {
      final prod = map['productos'] as Map<String, dynamic>;
      nombre = prod['nombre'] as String?;
      codigoBarras = prod['codigo_barras'] as String?;
      categoria = prod['categoria'] as String?;
    }

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
      stockAnterior: map['stock_anterior'] != null ? _toDouble(map['stock_anterior']) : null,
      stockPosterior: map['stock_posterior'] != null ? _toDouble(map['stock_posterior']) : null,
      usuarioId: map['usuario_id'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      nombreProducto: nombre,
      codigoBarrasProducto: codigoBarras,
      categoriaProducto: categoria,
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
