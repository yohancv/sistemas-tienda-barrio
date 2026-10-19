import '../../../../core/database/app_database.dart';
import '../models/producto_model.dart';

class InventarioRepository {
  final AppDatabase _db;

  InventarioRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  /// Obtiene todos los productos activos de una tienda específica (Aislamiento Multi-Tenant)
  Future<List<Producto>> obtenerProductosActivos(String tenantId) async {
    final db = await _db.database;
    final rows = await db.query(
      'productos',
      where: 'tenant_id = ? AND estado_activo = 1',
      whereArgs: [tenantId],
      orderBy: 'nombre ASC',
    );

    return rows
        .map((item) => Producto.fromMap(AppDatabase.aMapa(item)))
        .toList();
  }

  /// Busca productos activos por coincidencia en nombre, código de barras, categoría o subcategoría
  Future<List<Producto>> buscarProducto(String tenantId, String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return obtenerProductosActivos(tenantId);
    }

    final db = await _db.database;
    final wildcard = '%$cleanQuery%';
    final rows = await db.query(
      'productos',
      where: 'tenant_id = ? AND estado_activo = 1 AND ('
          'nombre LIKE ? OR '
          'codigo_barras LIKE ? OR '
          'categoria LIKE ? OR '
          'subcategoria LIKE ?)',
      whereArgs: [tenantId, wildcard, wildcard, wildcard, wildcard],
      orderBy: 'nombre ASC',
    );

    return rows
        .map((item) => Producto.fromMap(AppDatabase.aMapa(item)))
        .toList();
  }

  /// Crea un nuevo producto en SQLite local
  Future<Producto> crearProducto(Producto producto) async {
    final db = await _db.database;
    final id = producto.id.isNotEmpty ? producto.id : AppDatabase.nuevoId();
    final ahora = AppDatabase.ahora();

    final nuevoProd = producto.copyWith(
      id: id,
      createdAt: producto.createdAt,
      updatedAt: DateTime.parse(ahora),
    );

    final fila = AppDatabase.aFila(nuevoProd.toMap());
    await db.insert('productos', fila);

    return nuevoProd;
  }

  /// Actualiza los datos y precios de un producto existente
  Future<Producto> actualizarProducto(Producto producto) async {
    final db = await _db.database;
    final ahora = AppDatabase.ahora();

    final prodActualizado = producto.copyWith(
      updatedAt: DateTime.parse(ahora),
    );

    final fila = AppDatabase.aFila(prodActualizado.toMap());
    fila.remove('id');

    await db.update(
      'productos',
      fila,
      where: 'id = ? AND tenant_id = ?',
      whereArgs: [producto.id, producto.tenantId],
    );

    return prodActualizado;
  }

  /// Desactiva lógicamente un producto (Soft Delete para trazabilidad histórica)
  Future<void> desactivarProducto(String productoId) async {
    final db = await _db.database;
    final ahora = AppDatabase.ahora();

    await db.update(
      'productos',
      {'estado_activo': 0, 'updated_at': ahora},
      where: 'id = ?',
      whereArgs: [productoId],
    );
  }

  /// Reactivar un producto previamente dado de baja (Soft Delete inverso)
  Future<Producto> reactivarProducto(String productoId) async {
    final db = await _db.database;
    final ahora = AppDatabase.ahora();

    await db.update(
      'productos',
      {'estado_activo': 1, 'updated_at': ahora},
      where: 'id = ?',
      whereArgs: [productoId],
    );

    final rows = await db.query(
      'productos',
      where: 'id = ?',
      whereArgs: [productoId],
      limit: 1,
    );

    return Producto.fromMap(AppDatabase.aMapa(rows.first));
  }

  /// Obtiene los productos inactivos (retirados del catálogo) para reactivación
  Future<List<Producto>> obtenerProductosInactivos(String tenantId) async {
    final db = await _db.database;
    final rows = await db.query(
      'productos',
      where: 'tenant_id = ? AND estado_activo = 0',
      whereArgs: [tenantId],
      orderBy: 'updated_at DESC',
    );

    return rows
        .map((item) => Producto.fromMap(AppDatabase.aMapa(item)))
        .toList();
  }

  /// Verifica si un código de barras ya está en uso por otro producto activo.
  Future<Producto?> verificarCodigoBarrasDisponible(
    String tenantId,
    String codigoBarras, {
    String? excluirProductoId,
  }) async {
    if (codigoBarras.trim().isEmpty) return null;

    final db = await _db.database;
    String whereClause = 'tenant_id = ? AND estado_activo = 1 AND codigo_barras = ?';
    List<dynamic> whereArgs = [tenantId, codigoBarras.trim()];

    if (excluirProductoId != null) {
      whereClause += ' AND id <> ?';
      whereArgs.add(excluirProductoId);
    }

    final rows = await db.query(
      'productos',
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return Producto.fromMap(AppDatabase.aMapa(rows.first));
  }

  /// Registra un ajuste manual de stock como movimiento inmutable de auditoría.
  Future<void> registrarAjusteManualStock({
    required String productoId,
    required String tenantId,
    required double cantidadDelta,
    required double costoUnitario,
    double? stockAnterior,
    double? stockPosterior,
  }) async {
    final db = await _db.database;
    final tipoMovimiento = cantidadDelta > 0 ? 'AJUSTE_POSITIVO' : 'AJUSTE_NEGATIVO';
    final costoTotal = costoUnitario * cantidadDelta.abs();
    final ahora = AppDatabase.ahora();

    await db.insert(
      'movimientos_inventario',
      AppDatabase.aFila({
        'id': AppDatabase.nuevoId(),
        'tenant_id': tenantId,
        'producto_id': productoId,
        'tipo_movimiento': tipoMovimiento,
        'cantidad': cantidadDelta.abs(),
        'costo_unitario': costoUnitario,
        'costo_total': costoTotal,
        'motivo': 'Ajuste manual de stock desde edición de catálogo',
        'stock_anterior': stockAnterior,
        'stock_posterior': stockPosterior,
        'created_at': ahora,
      }),
    );
  }
}
