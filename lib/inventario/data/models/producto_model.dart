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

  // Campos de empaque mayorista de compra
  final String tipoEmpaque; // 'UNIDAD','CAJA','PAQUETE','FARDO','BOLSA','TIRA','KILO','LIBRA'
  final double unidadesPorEmpaque;
  final double costoPorEmpaque;

  // Campos de venta dual al detalle (cigarrillos sueltos, pastillas, etc.)
  final bool permiteVentaSuelta;
  final String nombreUnidadSuelta; // 'cigarrillo','pastilla','rollo'
  final double unidadesEnEmpaqueVenta; // ej. 20 cigarrillos por cajetilla
  final double precioVentaSuelta; // ej. Bs. 1.00 por cigarrillo

  // Enlace a producto hijo para desempaque automático (ej. Caja de Huari -> Botella de Huari)
  final String? productoHijoId;

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
    this.tipoEmpaque = 'UNIDAD',
    this.unidadesPorEmpaque = 1.0,
    this.costoPorEmpaque = 0.0,
    this.permiteVentaSuelta = false,
    this.nombreUnidadSuelta = 'unidad',
    this.unidadesEnEmpaqueVenta = 1.0,
    this.precioVentaSuelta = 0.0,
    this.productoHijoId,
  });

  /// Determina si el producto se vende a granel/fraccionable
  bool get esFraccionable => tipoUnidad == 'FRACCIONABLE';

  /// Determina si el producto ha alcanzado o superado su nivel crítico de reposición
  bool get esStockBajo => stockActual <= stockMinimo;

  /// Calcula cuántas unidades faltan para alcanzar el stock mínimo configurado
  double get unidadesFaltantes {
    final faltante = stockMinimo - stockActual;
    return faltante > 0 ? faltante : 0.0;
  }

  /// Indica si el producto se compra al proveedor en empaques cerrados (caja, paquete, fardo, etc.)
  bool get tieneEmpaqueMayorista => tipoEmpaque != 'UNIDAD' && unidadesPorEmpaque > 1;

  /// Calcula cuántos empaques mayoristas se necesitan para cubrir las unidades faltantes
  double get empaquesFaltantes {
    if (!tieneEmpaqueMayorista || unidadesPorEmpaque <= 0) return unidadesFaltantes;
    return (unidadesFaltantes / unidadesPorEmpaque).ceilToDouble();
  }

  /// Costo unitario derivado del empaque cerrado (costo_empaque / unidades_por_empaque)
  double get costoUnitarioDesdeEmpaque {
    if (unidadesPorEmpaque <= 0) return costoMayorista;
    return costoPorEmpaque > 0
        ? costoPorEmpaque / unidadesPorEmpaque
        : costoMayorista;
  }

  /// Etiqueta legible del empaque (ej. "Caja de 12", "Paquete de 6")
  String get etiquetaEmpaque {
    if (!tieneEmpaqueMayorista) return 'Unidad';
    final uds = unidadesPorEmpaque.truncateToDouble() == unidadesPorEmpaque
        ? unidadesPorEmpaque.toInt().toString()
        : unidadesPorEmpaque.toStringAsFixed(1);
    return '${_nombreEmpaque(tipoEmpaque)} de $uds';
  }

  /// Nombre legible del tipo de empaque
  static String _nombreEmpaque(String tipo) {
    switch (tipo) {
      case 'CAJA':
        return 'Caja';
      case 'PAQUETE':
        return 'Paquete';
      case 'FARDO':
        return 'Fardo';
      case 'BOLSA':
        return 'Bolsa';
      case 'TIRA':
        return 'Tira';
      case 'KILO':
        return 'Kilo';
      case 'LIBRA':
        return 'Libra';
      default:
        return 'Unidad';
    }
  }

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
    String? tipoEmpaque,
    double? unidadesPorEmpaque,
    double? costoPorEmpaque,
    bool? permiteVentaSuelta,
    String? nombreUnidadSuelta,
    double? unidadesEnEmpaqueVenta,
    double? precioVentaSuelta,
    String? productoHijoId,
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
      tipoEmpaque: tipoEmpaque ?? this.tipoEmpaque,
      unidadesPorEmpaque: unidadesPorEmpaque ?? this.unidadesPorEmpaque,
      costoPorEmpaque: costoPorEmpaque ?? this.costoPorEmpaque,
      permiteVentaSuelta: permiteVentaSuelta ?? this.permiteVentaSuelta,
      nombreUnidadSuelta: nombreUnidadSuelta ?? this.nombreUnidadSuelta,
      unidadesEnEmpaqueVenta: unidadesEnEmpaqueVenta ?? this.unidadesEnEmpaqueVenta,
      precioVentaSuelta: precioVentaSuelta ?? this.precioVentaSuelta,
      productoHijoId: productoHijoId ?? this.productoHijoId,
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
      'tipo_empaque': tipoEmpaque,
      'unidades_por_empaque': unidadesPorEmpaque,
      'costo_por_empaque': costoPorEmpaque,
      'permite_venta_suelta': permiteVentaSuelta,
      'nombre_unidad_suelta': nombreUnidadSuelta,
      'unidades_en_empaque_venta': unidadesEnEmpaqueVenta,
      'precio_venta_suelta': precioVentaSuelta,
      'producto_hijo_id': productoHijoId,
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
      tipoEmpaque: map['tipo_empaque'] as String? ?? 'UNIDAD',
      unidadesPorEmpaque: map['unidades_por_empaque'] != null
          ? _toDouble(map['unidades_por_empaque'])
          : 1.0,
      costoPorEmpaque: _toDouble(map['costo_por_empaque']),
      permiteVentaSuelta: map['permite_venta_suelta'] as bool? ?? false,
      nombreUnidadSuelta: map['nombre_unidad_suelta'] as String? ?? 'unidad',
      unidadesEnEmpaqueVenta: map['unidades_en_empaque_venta'] != null
          ? _toDouble(map['unidades_en_empaque_venta'])
          : 1.0,
      precioVentaSuelta: _toDouble(map['precio_venta_suelta']),
      productoHijoId: map['producto_hijo_id'] as String?,
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
