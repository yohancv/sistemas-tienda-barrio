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
  final double? precioEmpaqueMayorista; // Precio de venta opcional si se vende el paquete entero

  // Campos de venta dual al detalle (cigarrillos sueltos, pastillas, etc.)
  final bool permiteVentaSuelta;
  final String nombreUnidadSuelta; // 'cigarrillo','pastilla','rollo'
  final double unidadesEnEmpaqueVenta; // ej. 20 cigarrillos por cajetilla
  final double precioVentaSuelta; // ej. Bs. 1.00 por cigarrillo

  // Enlace a producto hijo para desempaque automático (ej. Caja de Huari -> Botella de Huari)
  final String? productoHijoId;

  // Enlace a proveedor habitual ("CBN no vende aceite")
  final String? proveedorId;

  // Clasificación por categoría y subcategoría (jerarquía en 2 niveles)
  final String? categoria;
  final String? subcategoria;

  static const List<String> categoriasSugeridas = [
    'Cervezas y Licores',
    'Gaseosas, Jugos y Aguas',
    'Abarrotes y Alimentos',
    'Snacks y Golosinas',
    'Lácteos y Embutidos',
    'Limpieza y Hogar',
    'Cigarrillos y Tabaco',
    'Farmacia y Cuidado Personal',
    'Otros',
  ];

  /// Sugerencias inteligentes de subcategorías/presentaciones según la categoría principal
  static List<String> sugerenciasSubcategoriasPorCategoria(String? cat) {
    if (cat == null || cat.trim().isEmpty) return ['Grande', 'Mediano', 'Personal', 'Económico'];
    final c = cat.toLowerCase();
    if (c.contains('cerveza')) {
      return ['710cc', 'Lata 354cc', 'Botellín 330cc', 'Lata 473cc', 'Artesanal', 'Mini'];
    }
    if (c.contains('licor') || c.contains('vino') || c.contains('singani') || c.contains('ron') || c.contains('vodka') || c.contains('whisky')) {
      return ['Botella 750ml', 'Botella 1 Litro', 'Petaca / Chico', 'Caneca', 'Caja tetra'];
    }
    if (c.contains('gaseosa') || c.contains('soda') || c.contains('refresco') || c.contains('bebida')) {
      return ['2 Litros', '3 Litros', 'Retornable 2.5L', '500ml Personal', 'Mini 250ml', 'Lata 350ml'];
    }
    if (c.contains('jugo') || c.contains('agua')) {
      return ['1 Litro', '2 Litros', '500ml', 'Sachet / Bolsa', 'Con Pulpa', 'Sin Gas'];
    }
    if (c.contains('lácteo') || c.contains('lacteo') || c.contains('leche') || c.contains('yogurt')) {
      return ['Bolsa 1L', 'Cartón 1L', 'Yogurt Sachet', 'Yogurt Botella', 'Personal 200ml'];
    }
    if (c.contains('snack') || c.contains('golosina') || c.contains('dulce') || c.contains('galleta')) {
      return ['Familiar / Grande', 'Personal', 'Tira', 'Caja', 'Unidad'];
    }
    if (c.contains('abarrote') || c.contains('alimento') || c.contains('arroz') || c.contains('fideo')) {
      return ['1 Kilo', '1 Libra', 'Arroba', 'Fardo', 'Sachet'];
    }
    if (c.contains('limpieza') || c.contains('detergente')) {
      return ['Grande', 'Económico', 'Sachet', 'Botella 1L', 'Galón'];
    }
    return ['Grande', 'Mediano', 'Personal', 'Económico'];
  }

  static String emojiCategoria(String? cat) {
    if (cat == null || cat.trim().isEmpty) return '🏷️';
    final c = cat.toLowerCase();
    if (c.contains('cerveza')) return '🍺';
    if (c.contains('licor') || c.contains('vino') || c.contains('singani') || c.contains('ron') || c.contains('vodka') || c.contains('whisky') || c.contains('trago')) return '🍷';
    if (c.contains('gaseosa') || c.contains('soda') || c.contains('refresco') || c.contains('jugo') || c.contains('agua') || c.contains('bebida')) return '🥤';
    if (c.contains('abarrote') || c.contains('alimento') || c.contains('arroz') || c.contains('fideo') || c.contains('aceite') || c.contains('conserva')) return '🥫';
    if (c.contains('snack') || c.contains('golosina') || c.contains('dulce') || c.contains('chocolate') || c.contains('galleta') || c.contains('pipoca') || c.contains('caramelo')) return '🍫';
    if (c.contains('lácteo') || c.contains('lacteo') || c.contains('leche') || c.contains('queso') || c.contains('yogurt') || c.contains('embutido') || c.contains('salchicha')) return '🥛';
    if (c.contains('limpieza') || c.contains('detergente') || c.contains('jabon') || c.contains('lavavajilla') || c.contains('papel') || c.contains('hogar')) return '🧼';
    if (c.contains('cigar') || c.contains('tabaco') || c.contains('fósforo') || c.contains('fosforo')) return '🚬';
    if (c.contains('farmacia') || c.contains('salud') || c.contains('cuidado') || c.contains('pastilla')) return '💊';
    if (c.contains('pan') || c.contains('masita') || c.contains('panaderia') || c.contains('torta')) return '🥖';
    if (c.contains('helado')) return '🍦';
    if (c.contains('carne') || c.contains('pollo')) return '🍗';
    return '🏷️';
  }

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
    this.precioEmpaqueMayorista,
    this.permiteVentaSuelta = false,
    this.nombreUnidadSuelta = 'unidad',
    this.unidadesEnEmpaqueVenta = 1.0,
    this.precioVentaSuelta = 0.0,
    this.productoHijoId,
    this.proveedorId,
    this.categoria,
    this.subcategoria,
  });

  /// Determina si el producto se vende a granel/fraccionable
  bool get esFraccionable => tipoUnidad == 'FRACCIONABLE';

  /// Unidad de medida legible para mostrador y balanza ('lb', 'kg' o 'uds')
  String get unidadMedida => tipoEmpaque == 'LIBRA' ? 'lb' : (tipoUnidad == 'FRACCIONABLE' ? 'kg' : 'uds');

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
    double? precioEmpaqueMayorista,
    bool clearPrecioEmpaqueMayorista = false,
    bool? permiteVentaSuelta,
    String? nombreUnidadSuelta,
    double? unidadesEnEmpaqueVenta,
    double? precioVentaSuelta,
    String? productoHijoId,
    String? proveedorId,
    String? categoria,
    String? subcategoria,
    bool clearCategoria = false,
    bool clearSubcategoria = false,
    bool clearProveedor = false,
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
      precioEmpaqueMayorista: clearPrecioEmpaqueMayorista ? null : (precioEmpaqueMayorista ?? this.precioEmpaqueMayorista),
      permiteVentaSuelta: permiteVentaSuelta ?? this.permiteVentaSuelta,
      nombreUnidadSuelta: nombreUnidadSuelta ?? this.nombreUnidadSuelta,
      unidadesEnEmpaqueVenta: unidadesEnEmpaqueVenta ?? this.unidadesEnEmpaqueVenta,
      precioVentaSuelta: precioVentaSuelta ?? this.precioVentaSuelta,
      productoHijoId: productoHijoId ?? this.productoHijoId,
      proveedorId: clearProveedor ? null : (proveedorId ?? this.proveedorId),
      categoria: clearCategoria ? null : (categoria ?? this.categoria),
      subcategoria: clearSubcategoria ? null : (subcategoria ?? this.subcategoria),
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
      'precio_empaque_mayorista': precioEmpaqueMayorista,
      'permite_venta_suelta': permiteVentaSuelta,
      'nombre_unidad_suelta': nombreUnidadSuelta,
      'unidades_en_empaque_venta': unidadesEnEmpaqueVenta,
      'precio_venta_suelta': precioVentaSuelta,
      'producto_hijo_id': productoHijoId,
      'proveedor_id': proveedorId,
      'categoria': categoria,
      'subcategoria': subcategoria,
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
      precioEmpaqueMayorista: map['precio_empaque_mayorista'] != null
          ? _toDouble(map['precio_empaque_mayorista'])
          : null,
      permiteVentaSuelta: map['permite_venta_suelta'] as bool? ?? false,
      nombreUnidadSuelta: map['nombre_unidad_suelta'] as String? ?? 'unidad',
      unidadesEnEmpaqueVenta: map['unidades_en_empaque_venta'] != null
          ? _toDouble(map['unidades_en_empaque_venta'])
          : 1.0,
      precioVentaSuelta: _toDouble(map['precio_venta_suelta']),
      productoHijoId: map['producto_hijo_id'] as String?,
      proveedorId: map['proveedor_id'] as String?,
      categoria: map['categoria'] as String?,
      subcategoria: map['subcategoria'] as String?,
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
