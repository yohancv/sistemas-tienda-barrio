import '../../../../core/database/app_database.dart';
import '../models/categoria_model.dart';

class CategoriasRepository {
  final AppDatabase _db;

  CategoriasRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  /// Obtiene todas las categorías y subcategorías organizadas en árbol (Padre -> Subcategorías)
  Future<List<CategoriaModel>> obtenerArbolCategorias(String tenantId) async {
    final db = await _db.database;
    final rows = await db.query(
      'categorias',
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
      orderBy: 'orden ASC, nombre ASC',
    );

    final List<CategoriaModel> todas = rows
        .map((item) => CategoriaModel.fromMap(AppDatabase.aMapa(item)))
        .toList();

    // Separar principales y subcategorías
    final principales = todas.where((c) => c.esPrincipal).toList();
    final Map<String, List<CategoriaModel>> subPorPadre = {};

    for (final c in todas.where((c) => !c.esPrincipal)) {
      if (c.parentId != null) {
        subPorPadre.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }

    // Ensamblar árbol
    return principales.map((padre) {
      final subs = subPorPadre[padre.id] ?? [];
      return padre.copyWith(subcategorias: subs);
    }).toList();
  }

  /// Obtiene solo las categorías principales (Nivel 1)
  Future<List<CategoriaModel>> obtenerCategoriasPrincipales(String tenantId) async {
    final db = await _db.database;
    final rows = await db.query(
      'categorias',
      where: "tenant_id = ? AND (parent_id IS NULL OR parent_id = '')",
      whereArgs: [tenantId],
      orderBy: 'orden ASC, nombre ASC',
    );

    return rows
        .map((item) => CategoriaModel.fromMap(AppDatabase.aMapa(item)))
        .toList();
  }

  /// Obtiene las subcategorías de una categoría padre dada
  Future<List<CategoriaModel>> obtenerSubcategoriasDePadre(String tenantId, String parentId) async {
    final db = await _db.database;
    final rows = await db.query(
      'categorias',
      where: 'tenant_id = ? AND parent_id = ?',
      whereArgs: [tenantId, parentId],
      orderBy: 'orden ASC, nombre ASC',
    );

    return rows
        .map((item) => CategoriaModel.fromMap(AppDatabase.aMapa(item)))
        .toList();
  }

  /// Registra una nueva categoría o subcategoría
  Future<CategoriaModel> crearCategoria(CategoriaModel categoria) async {
    final db = await _db.database;
    final id = categoria.id.isNotEmpty ? categoria.id : AppDatabase.nuevoId();
    final ahora = AppDatabase.ahora();

    final row = AppDatabase.aFila({
      'id': id,
      'tenant_id': categoria.tenantId,
      'nombre': categoria.nombre,
      'parent_id': categoria.parentId,
      'icono': categoria.icono,
      'orden': categoria.orden,
      'created_at': ahora,
      'updated_at': ahora,
    });

    await db.insert('categorias', row);
    return categoria.copyWith(id: id);
  }

  /// Actualiza nombre, icono u orden de una categoría existente
  Future<CategoriaModel> actualizarCategoria(CategoriaModel categoria) async {
    final db = await _db.database;
    final ahora = AppDatabase.ahora();

    final row = AppDatabase.aFila({
      'nombre': categoria.nombre,
      'parent_id': categoria.parentId,
      'icono': categoria.icono,
      'orden': categoria.orden,
      'updated_at': ahora,
    });

    await db.update(
      'categorias',
      row,
      where: 'id = ? AND tenant_id = ?',
      whereArgs: [categoria.id, categoria.tenantId],
    );

    return categoria;
  }

  /// Elimina una categoría o subcategoría (cascade elimina subcategorías)
  Future<void> eliminarCategoria(String id, String tenantId) async {
    final db = await _db.database;
    await db.delete(
      'categorias',
      where: 'id = ? AND tenant_id = ?',
      whereArgs: [id, tenantId],
    );
  }
}
