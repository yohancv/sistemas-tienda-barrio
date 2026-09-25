class CierreCaja {
  final String? id;
  final String tenantId;
  final double fondoFijo;
  final double? montoDeclarado;
  final double? montoEsperado;
  final double? descuadre;
  final String estado; // 'COMPLETADO' o 'POSPUESTO'
  final String? notas;
  final DateTime fechaCierre;

  const CierreCaja({
    this.id,
    required this.tenantId,
    this.fondoFijo = 0.0,
    this.montoDeclarado,
    this.montoEsperado,
    this.descuadre,
    required this.estado,
    this.notas,
    required this.fechaCierre,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'tenant_id': tenantId,
      'fondo_fijo': fondoFijo,
      'monto_declarado': montoDeclarado,
      'monto_esperado': montoEsperado,
      'descuadre': descuadre,
      'estado': estado,
      'notas': notas,
      'fecha_cierre': fechaCierre.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory CierreCaja.fromMap(Map<String, dynamic> map) {
    return CierreCaja(
      id: map['id'] as String?,
      tenantId: map['tenant_id'] as String,
      fondoFijo: _toDouble(map['fondo_fijo']),
      montoDeclarado: map['monto_declarado'] != null
          ? _toDouble(map['monto_declarado'])
          : null,
      montoEsperado: map['monto_esperado'] != null
          ? _toDouble(map['monto_esperado'])
          : null,
      descuadre:
          map['descuadre'] != null ? _toDouble(map['descuadre']) : null,
      estado: map['estado'] as String? ?? 'COMPLETADO',
      notas: map['notas'] as String?,
      fechaCierre: map['fecha_cierre'] != null
          ? DateTime.parse(map['fecha_cierre'] as String)
          : DateTime.now(),
    );
  }

  CierreCaja copyWith({
    String? id,
    String? tenantId,
    double? fondoFijo,
    double? montoDeclarado,
    double? montoEsperado,
    double? descuadre,
    String? estado,
    String? notas,
    DateTime? fechaCierre,
  }) {
    return CierreCaja(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      fondoFijo: fondoFijo ?? this.fondoFijo,
      montoDeclarado: montoDeclarado ?? this.montoDeclarado,
      montoEsperado: montoEsperado ?? this.montoEsperado,
      descuadre: descuadre ?? this.descuadre,
      estado: estado ?? this.estado,
      notas: notas ?? this.notas,
      fechaCierre: fechaCierre ?? this.fechaCierre,
    );
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}
