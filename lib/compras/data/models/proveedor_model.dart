/// Modelo de Proveedor / Empresa Distribuidora (ej. CBN, Embol, etc.)
class ProveedorModel {
  final String id;
  final String tenantId;
  final String nombreEmpresa;
  final String? nombreContacto;
  final String? telefono;
  final String? nitCi;
  final String? diasVisita; // ej. "Martes y Viernes"
  final bool activo;
  final DateTime createdAt;

  const ProveedorModel({
    required this.id,
    required this.tenantId,
    required this.nombreEmpresa,
    this.nombreContacto,
    this.telefono,
    this.nitCi,
    this.diasVisita,
    this.activo = true,
    required this.createdAt,
  });

  /// Retorna un texto formateado del contacto
  String get contactoLegible {
    if (nombreContacto != null && nombreContacto!.trim().isNotEmpty) {
      return nombreContacto!;
    }
    return 'Sin contacto registrado';
  }

  /// Indica si tiene días de visita configurados
  bool get tieneDiasVisita => diasVisita != null && diasVisita!.trim().isNotEmpty;

  ProveedorModel copyWith({
    String? id,
    String? tenantId,
    String? nombreEmpresa,
    String? nombreContacto,
    String? telefono,
    String? nitCi,
    String? diasVisita,
    bool? activo,
    DateTime? createdAt,
  }) {
    return ProveedorModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      nombreEmpresa: nombreEmpresa ?? this.nombreEmpresa,
      nombreContacto: nombreContacto ?? this.nombreContacto,
      telefono: telefono ?? this.telefono,
      nitCi: nitCi ?? this.nitCi,
      diasVisita: diasVisita ?? this.diasVisita,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'nombre_empresa': nombreEmpresa,
      'nombre_contacto': nombreContacto,
      'telefono': telefono,
      'nit_ci': nitCi,
      'dias_visita': diasVisita,
      'activo': activo,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ProveedorModel.fromMap(Map<String, dynamic> map) {
    return ProveedorModel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      nombreEmpresa: map['nombre_empresa'] as String? ?? 'Sin Empresa',
      nombreContacto: map['nombre_contacto'] as String?,
      telefono: map['telefono'] as String?,
      nitCi: map['nit_ci'] as String?,
      diasVisita: map['dias_visita'] as String?,
      activo: map['activo'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}
