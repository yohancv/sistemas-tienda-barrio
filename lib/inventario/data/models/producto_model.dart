class Producto {
  final String id;
  final String tenantId;
  final String? codigoBarras;
  final String nombre;
  final String? descripcion;
  final String tipoUnidad; // 'UNIDAD' o 'FRACCIONABLE'
  final double stockActual;
  final double stockMinimo;
  final double costoMayorista;
  final double precioVenta;
  final bool estadoActivo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Producto({
    required this.id,
    required this.tenantId,
    this.codigoBarras,
    required this.nombre,
    this.descripcion,
    this.tipoUnidad = 'UNIDAD',
    this.stockActual = 0.0,
    this.stockMinimo = 0.0,
    this.costoMayorista = 0.0,
    this.precioVenta = 0.0,
    this.estadoActivo = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Determina si el producto se vende a granel/fraccionable
  bool get esFraccionable => tipoUnidad == 'FRACCIONABLE';

  Producto copyWith({
    String? id,
    String? tenantId,
    String? codigoBarras,
    String? nombre,
    String? descripcion,
    String? tipoUnidad,
    double? stockActual,
    double? stockMinimo,
    double? costoMayorista,
    double? precioVenta,
    bool? estadoActivo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Producto(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      tipoUnidad: tipoUnidad ?? this.tipoUnidad,
      stockActual: stockActual ?? this.stockActual,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      costoMayorista: costoMayorista ?? this.costoMayorista,
      precioVenta: precioVenta ?? this.precioVenta,
      estadoActivo: estadoActivo ?? this.estadoActivo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'codigo_barras': codigoBarras,
      'nombre': nombre,
      'descripcion': descripcion,
      'tipo_unidad': tipoUnidad,
      'stock_actual': stockActual,
      'stock_minimo': stockMinimo,
      'costo_mayorista': costoMayorista,
      'precio_venta': precioVenta,
      'estado_activo': estadoActivo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      codigoBarras: map['codigo_barras'] as String?,
      nombre: map['nombre'] as String? ?? '',
      descripcion: map['descripcion'] as String?,
      tipoUnidad: map['tipo_unidad'] as String? ?? 'UNIDAD',
      stockActual: _toDouble(map['stock_actual']),
      stockMinimo: _toDouble(map['stock_minimo']),
      costoMayorista: _toDouble(map['costo_mayorista']),
      precioVenta: _toDouble(map['precio_venta']),
      estadoActivo: map['estado_activo'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : DateTime.now(),
    );
  }

  /// Conversor seguro de valores numéricos de Supabase (PostgreSQL NUMERIC)
  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
