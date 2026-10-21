import '../../../../core/database/app_database.dart';

class BiAnalyticsRepository {
  final AppDatabase _db;

  BiAnalyticsRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  /// 1. Obtiene los productos con stock crítico (<= stock mínimo) junto con la información de su proveedor
  Future<List<Map<String, dynamic>>> obtenerProductosStockCritico() async {
    final db = await _db.database;
    const sql = '''
      SELECT 
        p.id,
        p.nombre,
        p.categoria,
        p.subcategoria,
        p.stock_actual,
        p.stock_minimo,
        p.costo_mayorista,
        p.precio_venta,
        p.tipo_empaque,
        p.unidades_por_empaque,
        p.costo_por_empaque,
        p.permite_venta_suelta,
        p.tipo_unidad,
        prov.id AS proveedor_id,
        prov.nombre_empresa AS proveedor_nombre,
        prov.telefono AS proveedor_telefono,
        prov.dias_visita AS proveedor_dias_visita
      FROM productos p
      LEFT JOIN proveedores prov ON p.proveedor_id = prov.id
      WHERE p.estado_activo = 1 
        AND p.stock_actual <= p.stock_minimo
      ORDER BY (p.stock_actual - p.stock_minimo) ASC, p.stock_actual ASC
    ''';

    final rows = await db.rawQuery(sql);
    return rows.map((r) => AppDatabase.aMapa(r)).toList();
  }

  /// 2. Obtiene el balance financiero acumulado de la semana móvil (últimos 7 días)
  ///    Separa estrictamente RETIRO_PERSONAL de GASTO_TIENDA.
  Future<Map<String, dynamic>> obtenerBalanceSemanal(String tenantId) async {
    final db = await _db.database;
    final hace7Dias = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

    // Total ventas de la semana
    final sqlVentas = '''
      SELECT 
        COALESCE(SUM(total_venta), 0) AS total_ventas
      FROM ventas
      WHERE tenant_id = ? AND fecha_venta >= ?
    ''';
    final ventasRes = await db.rawQuery(sqlVentas, [tenantId, hace7Dias]);
    final double totalVentasSemana = (ventasRes.first['total_ventas'] as num?)?.toDouble() ?? 0.0;

    // Costo de mercadería vendida en la semana (para ganancia bruta)
    final sqlCosto = '''
      SELECT 
        COALESCE(SUM(dv.cantidad * dv.costo_unitario), 0) AS costo_mercaderia
      FROM detalle_ventas dv
      JOIN ventas v ON dv.venta_id = v.id
      WHERE v.tenant_id = ? AND v.fecha_venta >= ?
    ''';
    final costoRes = await db.rawQuery(sqlCosto, [tenantId, hace7Dias]);
    final double costoSemana = (costoRes.first['costo_mercaderia'] as num?)?.toDouble() ?? 0.0;

    final double gananciaBrutaSemana = totalVentasSemana - costoSemana;

    // Gastos de tienda vs Retiros personales en los últimos 7 días
    final sqlMovs = '''
      SELECT 
        categoria,
        COALESCE(SUM(monto), 0) AS subtotal
      FROM movimientos_caja
      WHERE tenant_id = ? AND tipo = 'SALIDA' AND created_at >= ?
      GROUP BY categoria
    ''';
    final movsRes = await db.rawQuery(sqlMovs, [tenantId, hace7Dias]);

    double gastosTiendaSemana = 0.0;
    double retirosPersonalesSemana = 0.0;

    for (final r in movsRes) {
      final cat = r['categoria'] as String? ?? 'OTRO';
      final monto = (r['subtotal'] as num?)?.toDouble() ?? 0.0;

      if (cat == 'RETIRO_PERSONAL' || cat == 'AHORRO') {
        retirosPersonalesSemana += monto;
      } else {
        gastosTiendaSemana += monto;
      }
    }

    final double gananciaNetaSemana = gananciaBrutaSemana - gastosTiendaSemana;
    final double balanceFinalSemana = gananciaNetaSemana - retirosPersonalesSemana;

    return {
      'total_ventas_semana': totalVentasSemana,
      'costo_mercaderia_semana': costoSemana,
      'ganancia_bruta_semana': gananciaBrutaSemana,
      'gastos_tienda_semana': gastosTiendaSemana,
      'ganancia_neta_semana': gananciaNetaSemana,
      'retiros_personales_semana': retirosPersonalesSemana,
      'balance_final_semana': balanceFinalSemana,
    };
  }

  /// 3. Obtiene la rotación de bebidas alcohólicas y licores para evaluar los 3 niveles
  Future<List<Map<String, dynamic>>> obtenerRotacionBebidasYLicores() async {
    final db = await _db.database;

    // Buscamos productos de categorías de bebidas, cervezas o licores
    const sql = '''
      SELECT 
        p.id,
        p.nombre,
        p.categoria,
        p.subcategoria,
        p.stock_actual,
        p.costo_mayorista,
        p.precio_venta,
        (
          SELECT MAX(v.fecha_venta)
          FROM detalle_ventas dv
          JOIN ventas v ON dv.venta_id = v.id
          WHERE dv.producto_id = p.id
        ) AS ultima_venta
      FROM productos p
      WHERE p.estado_activo = 1 
        AND (
          p.categoria LIKE '%Cerveza%' 
          OR p.categoria LIKE '%Licor%' 
          OR p.categoria LIKE '%Bebida%'
          OR p.subcategoria LIKE '%Cerveza%'
          OR p.subcategoria LIKE '%Ron%'
          OR p.subcategoria LIKE '%Singani%'
          OR p.subcategoria LIKE '%Fernet%'
          OR p.subcategoria LIKE '%Whisky%'
          OR p.subcategoria LIKE '%Vodka%'
        )
        AND p.stock_actual > 0
    ''';

    final rows = await db.rawQuery(sql);
    return rows.map((r) => AppDatabase.aMapa(r)).toList();
  }

  /// 4. Obtiene clientes con deuda y calcula días transcurridos desde su último movimiento
  Future<List<Map<String, dynamic>>> obtenerDeudoresConAntiguedad() async {
    final db = await _db.database;
    const sqlClientes = '''
      SELECT 
        id,
        nombre,
        telefono,
        saldo_actual,
        limite_credito
      FROM clientes
      WHERE activo = 1 AND saldo_actual > 0
      ORDER BY saldo_actual DESC
    ''';

    final clientes = await db.rawQuery(sqlClientes);
    final List<Map<String, dynamic>> resultado = [];

    for (final c in clientes) {
      final clienteId = c['id'] as String;
      final clienteMap = AppDatabase.aMapa(c);

      final sqlUltimo = '''
        SELECT fecha_abono AS fecha FROM abonos_deuda WHERE cliente_id = ?
        UNION ALL
        SELECT fecha_venta AS fecha FROM ventas WHERE cliente_id = ? AND (metodo_pago = 'CREDITO_FIADO' OR metodo_pago = 'FIADO')
        ORDER BY fecha DESC
        LIMIT 1
      ''';
      final movs = await db.rawQuery(sqlUltimo, [clienteId, clienteId]);
      DateTime? ultimaFecha;
      if (movs.isNotEmpty) {
        ultimaFecha = DateTime.tryParse(movs.first['fecha'] as String? ?? '');
      }

      final int diasSinMovimiento = ultimaFecha != null
          ? DateTime.now().difference(ultimaFecha).inDays
          : 30; // Si no tiene registros previos, consideramos 30 días

      clienteMap['dias_sin_movimiento'] = diasSinMovimiento;
      clienteMap['fecha_ultimo_movimiento'] = ultimaFecha?.toIso8601String();
      resultado.add(clienteMap);
    }

    return resultado;
  }

  /// 5. Marca un producto como estacional para silenciar alertas de baja rotación
  Future<void> silenciarProductoEstacional(String productoId) async {
    final db = await _db.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS productos_silenciados_ia (
        producto_id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL
      )
    ''');
    await db.insert('productos_silenciados_ia', {
      'producto_id': productoId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Verifica si un producto fue silenciado por el tendero
  Future<Set<String>> obtenerIdsSilenciados() async {
    final db = await _db.database;
    try {
      final rows = await db.rawQuery('SELECT producto_id FROM productos_silenciados_ia');
      return rows.map((r) => r['producto_id'] as String).toSet();
    } catch (_) {
      return {};
    }
  }
}
