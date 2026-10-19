import '../../../../core/database/app_database.dart';
import '../models/movimiento_inventario_model.dart';

class MovimientosRepository {
  final AppDatabase _db;

  MovimientosRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  /// Ejecuta un desempaque mayorista de forma atómica en SQLite.
  /// Descuenta cajas, suma unidades sueltas y registra la auditoría inmutable de ambos movimientos.
  Future<Map<String, dynamic>> desempaquetarCaja({
    required String cajaId,
    required String unidadesId,
    required double cantidadCajas,
    required String tenantId,
    String? motivo,
  }) async {
    if (cantidadCajas <= 0) {
      throw Exception('La cantidad de cajas a desempaquetar debe ser mayor a 0');
    }

    final db = await _db.database;

    return await db.transaction<Map<String, dynamic>>((txn) async {
      // 1. Obtener producto caja
      final cajas = await txn.query(
        'productos',
        where: 'id = ? AND tenant_id = ?',
        whereArgs: [cajaId, tenantId],
      );

      if (cajas.isEmpty) {
        throw Exception('Producto caja no encontrado');
      }

      final caja = cajas.first;
      final stockCaja = (caja['stock_actual'] as num).toDouble();
      final costoCaja = (caja['costo_mayorista'] as num).toDouble();
      final factor = (caja['unidades_por_empaque'] as num?)?.toDouble() ?? 1.0;

      if (stockCaja < cantidadCajas) {
        throw Exception('Stock insuficiente de cajas (Disponible: $stockCaja, Solicitado: $cantidadCajas)');
      }

      // 2. Obtener producto unidades
      final unidades = await txn.query(
        'productos',
        where: 'id = ? AND tenant_id = ?',
        whereArgs: [unidadesId, tenantId],
      );

      if (unidades.isEmpty) {
        throw Exception('Producto unidades destino no encontrado');
      }

      final unidad = unidades.first;
      final stockUnidades = (unidad['stock_actual'] as num).toDouble();

      final unidadesASumar = cantidadCajas * factor;
      final costoTotal = costoCaja * cantidadCajas;
      final costoUnitarioHijo = factor > 0 ? (costoCaja / factor) : 0.0;

      final nuevoStockCaja = stockCaja - cantidadCajas;
      final nuevoStockUnidades = stockUnidades + unidadesASumar;
      final ahora = AppDatabase.ahora();

      // 3. Descontar cajas y sumar unidades
      await txn.update(
        'productos',
        {'stock_actual': nuevoStockCaja, 'updated_at': ahora},
        where: 'id = ?',
        whereArgs: [cajaId],
      );

      await txn.update(
        'productos',
        {'stock_actual': nuevoStockUnidades, 'updated_at': ahora},
        where: 'id = ?',
        whereArgs: [unidadesId],
      );

      // 4. Registrar auditoría inmutable vinculada
      final salidaId = AppDatabase.nuevoId();
      final entradaId = AppDatabase.nuevoId();

      await txn.insert('movimientos_inventario', AppDatabase.aFila({
        'id': salidaId,
        'tenant_id': tenantId,
        'producto_id': cajaId,
        'tipo_movimiento': 'DESEMPAQUE_SALIDA',
        'cantidad': cantidadCajas,
        'costo_unitario': costoCaja,
        'costo_total': costoTotal,
        'motivo': motivo ?? 'Desempaque a unidades sueltas',
        'referencia_id': entradaId,
        'stock_anterior': stockCaja,
        'stock_posterior': nuevoStockCaja,
        'created_at': ahora,
      }));

      await txn.insert('movimientos_inventario', AppDatabase.aFila({
        'id': entradaId,
        'tenant_id': tenantId,
        'producto_id': unidadesId,
        'tipo_movimiento': 'DESEMPAQUE_ENTRADA',
        'cantidad': unidadesASumar,
        'costo_unitario': costoUnitarioHijo,
        'costo_total': costoTotal,
        'motivo': motivo ?? 'Entrada generada por desempaque de caja',
        'referencia_id': salidaId,
        'stock_anterior': stockUnidades,
        'stock_posterior': nuevoStockUnidades,
        'created_at': ahora,
      }));

      return {
        'success': true,
        'cantidad_cajas': cantidadCajas,
        'unidades_sumadas': unidadesASumar,
        'nuevo_stock_caja': nuevoStockCaja,
        'nuevo_stock_unidades': nuevoStockUnidades,
      };
    });
  }

  /// Registra una merma o rotura de producto con su cálculo financiero de pérdida en Bs.
  Future<Map<String, dynamic>> registrarMerma({
    required String productoId,
    required double cantidad,
    required String tipoMerma,
    required String tenantId,
    String? motivo,
  }) async {
    if (cantidad <= 0) {
      throw Exception('La cantidad de merma debe ser mayor a 0');
    }

    final db = await _db.database;

    return await db.transaction<Map<String, dynamic>>((txn) async {
      final prods = await txn.query(
        'productos',
        where: 'id = ? AND tenant_id = ?',
        whereArgs: [productoId, tenantId],
      );

      if (prods.isEmpty) {
        throw Exception('Producto no encontrado');
      }

      final prod = prods.first;
      final stockActual = (prod['stock_actual'] as num).toDouble();
      final costoUnitario = (prod['costo_mayorista'] as num).toDouble();
      final costoTotal = costoUnitario * cantidad;
      final nuevoStock = (stockActual - cantidad) < 0 ? 0.0 : (stockActual - cantidad);
      final ahora = AppDatabase.ahora();

      await txn.update(
        'productos',
        {'stock_actual': nuevoStock, 'updated_at': ahora},
        where: 'id = ?',
        whereArgs: [productoId],
      );

      final movId = AppDatabase.nuevoId();
      await txn.insert('movimientos_inventario', AppDatabase.aFila({
        'id': movId,
        'tenant_id': tenantId,
        'producto_id': productoId,
        'tipo_movimiento': tipoMerma,
        'cantidad': cantidad,
        'costo_unitario': costoUnitario,
        'costo_total': costoTotal,
        'motivo': motivo ?? 'Registro de merma de inventario',
        'stock_anterior': stockActual,
        'stock_posterior': nuevoStock,
        'created_at': ahora,
      }));

      return {
        'success': true,
        'cantidad_merma': cantidad,
        'costo_perdida': costoTotal,
        'nuevo_stock': nuevoStock,
      };
    });
  }

  /// Consulta el Kardex filtrable con JOIN al catálogo de productos
  Future<List<MovimientoInventario>> obtenerKardex({
    required String tenantId,
    String? productoId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? filtroTipo,
    int limite = 100,
  }) async {
    try {
      final db = await _db.database;

      final whereClauses = <String>['m.tenant_id = ?'];
      final whereArgs = <dynamic>[tenantId];

      if (productoId != null && productoId.isNotEmpty) {
        whereClauses.add('m.producto_id = ?');
        whereArgs.add(productoId);
      }

      if (fechaInicio != null) {
        whereClauses.add('m.created_at >= ?');
        whereArgs.add(fechaInicio.toIso8601String());
      }
      if (fechaFin != null) {
        whereClauses.add('m.created_at <= ?');
        whereArgs.add(fechaFin.toIso8601String());
      }

      if (filtroTipo != null && filtroTipo != 'TODOS') {
        switch (filtroTipo) {
          case 'VENTA':
            whereClauses.add("m.tipo_movimiento = 'VENTA'");
            break;
          case 'MERMAS':
            whereClauses.add("m.tipo_movimiento IN ('MERMA_ROTURA', 'MERMA_VENCIMIENTO', 'MERMA_DETERIORO')");
            break;
          case 'DESEMPAQUES':
            whereClauses.add("m.tipo_movimiento IN ('DESEMPAQUE_SALIDA', 'DESEMPAQUE_ENTRADA')");
            break;
          case 'AJUSTES':
            whereClauses.add("m.tipo_movimiento IN ('AJUSTE_POSITIVO', 'AJUSTE_NEGATIVO', 'AJUSTE_MANUAL')");
            break;
          case 'ENTRADAS':
            whereClauses.add("m.tipo_movimiento IN ('ENTRADA_COMPRA', 'DESEMPAQUE_ENTRADA', 'AJUSTE_POSITIVO')");
            break;
          default:
            whereClauses.add('m.tipo_movimiento = ?');
            whereArgs.add(filtroTipo);
        }
      }

      final sql = '''
        SELECT 
          m.*,
          p.nombre AS prod_nombre,
          p.codigo_barras AS prod_codigo_barras,
          p.categoria AS prod_categoria
        FROM movimientos_inventario m
        LEFT JOIN productos p ON p.id = m.producto_id
        WHERE ${whereClauses.join(' AND ')}
        ORDER BY m.created_at DESC
        LIMIT $limite
      ''';

      final rows = await db.rawQuery(sql, whereArgs);

      return rows.map((r) {
        final map = AppDatabase.aMapa(r);
        return MovimientoInventario(
          id: map['id'] as String,
          tenantId: map['tenant_id'] as String,
          productoId: map['producto_id'] as String,
          tipoMovimiento: map['tipo_movimiento'] as String? ?? 'AJUSTE_MANUAL',
          cantidad: (map['cantidad'] as num).toDouble(),
          costoUnitario: (map['costo_unitario'] as num).toDouble(),
          costoTotal: (map['costo_total'] as num).toDouble(),
          motivo: map['motivo'] as String?,
          referenciaId: map['referencia_id'] as String?,
          stockAnterior: map['stock_anterior'] != null ? (map['stock_anterior'] as num).toDouble() : null,
          stockPosterior: map['stock_posterior'] != null ? (map['stock_posterior'] as num).toDouble() : null,
          usuarioId: map['usuario_id'] as String?,
          createdAt: DateTime.parse(map['created_at'] as String),
          nombreProducto: map['prod_nombre'] as String?,
          codigoBarrasProducto: map['prod_codigo_barras'] as String?,
          categoriaProducto: map['prod_categoria'] as String?,
        );
      }).toList();
    } catch (e, stack) {
      // ignore: avoid_print
      print('[Kardex Repository Error] Falló al consultar kardex: $e\n$stack');
      return [];
    }
  }

  /// Consulta rápida de movimientos recientes de auditoría
  Future<List<MovimientoInventario>> obtenerHistorialMovimientos(
    String tenantId, {
    int limite = 50,
  }) async {
    return obtenerKardex(tenantId: tenantId, limite: limite);
  }
}
