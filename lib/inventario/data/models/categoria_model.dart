/// Modelo de datos que representa una Categoría o Subcategoría de productos.
/// Soporta relaciones jerárquicas padre-hijo (árbol de 2 niveles).
class CategoriaModel {
  final String id;
  final String tenantId;
  final String nombre;
  final String? parentId;
  final String? icono;
  final int orden;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<CategoriaModel> subcategorias;

  const CategoriaModel({
    required this.id,
    required this.tenantId,
    required this.nombre,
    this.parentId,
    this.icono,
    this.orden = 0,
    this.createdAt,
    this.updatedAt,
    this.subcategorias = const [],
  });

  /// Indica si es una categoría principal (nivel 1)
  bool get esPrincipal => parentId == null || parentId!.trim().isEmpty;

  /// Retorna el icono/emoji configurado o un ícono por defecto
  String get iconoOEmoji {
    if (icono != null && icono!.trim().isNotEmpty) {
      return icono!;
    }
    return esPrincipal ? '📁' : '↳';
  }

  /// Retorna el nombre formateado con su icono (ej. '🍺 Cervezas')
  String get nombreConIcono => '$iconoOEmoji $nombre';

  CategoriaModel copyWith({
    String? id,
    String? tenantId,
    String? nombre,
    String? parentId,
    String? icono,
    int? orden,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<CategoriaModel>? subcategorias,
  }) {
    return CategoriaModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      nombre: nombre ?? this.nombre,
      parentId: parentId ?? this.parentId,
      icono: icono ?? this.icono,
      orden: orden ?? this.orden,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subcategorias: subcategorias ?? this.subcategorias,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'tenant_id': tenantId,
      'nombre': nombre,
      'parent_id': parentId,
      'icono': icono,
      'orden': orden,
    };
  }

  factory CategoriaModel.fromMap(Map<String, dynamic> map, {List<CategoriaModel> subcategorias = const []}) {
    return CategoriaModel(
      id: map['id']?.toString() ?? '',
      tenantId: map['tenant_id']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      parentId: map['parent_id']?.toString(),
      icono: map['icono']?.toString(),
      orden: (map['orden'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      subcategorias: subcategorias,
    );
  }
}
