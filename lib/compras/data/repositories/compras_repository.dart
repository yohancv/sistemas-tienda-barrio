import '../../../../core/database/app_database.dart';
import '../models/compra_model.dart';
import '../models/item_compra_model.dart';
import '../models/proveedor_model.dart';

class ComprasRepository {
  final AppDatabase _db;

  ComprasRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  /// Obtiene todos los proveedores activos de la tienda
  Future<List<ProveedorModel>> obtenerProveedores(String tenantId) async {
    final db = await _db.database;
    final rows = await db.query(
      'proveedores',
      where: 'tenant_id = ? AND activo = 1',
      whereArgs: [tenantId],
      orderBy: 'nombre_empresa ASC',
    );

    return rows
        .map((item) => ProveedorModel.fromMap(AppDatabase.aMapa(item)))
        .toList();
  }

  /// Registra un nuevo proveedor o distribuidor
  Future<ProveedorModel> crearProveedor(ProveedorModel proveedor) async {
    final db = await _db.database;
    final id = proveedor.id.isNotEmpty ? proveedor.id : AppDatabase.nuevoId();
    final ahora = AppDatabase.ahora();

    final nuevo = proveedor.copyWith(
      id: id,
      createdAt: proveedor.createdAt,
    );

    final fila = AppDatabase.aFila(nuevo.toMap());
    fila['created_at'] = ahora;

    await db.insert('proveedores', fila);
    return nuevo;
  }

  /// Edita los datos de un proveedor existente
  Future<ProveedorModel> editarProveedor(ProveedorModel proveedor) async {
    final db = await _db.database;

    await db.update(
      'proveedores',
      {
        'nombre_empresa': proveedor.nombreEmpresa,
        'nombre_contacto': proveedor.nombreContacto,
        'telefono': proveedor.telefono,
        'nit_ci': proveedor.nitCi,
        'dias_visita': proveedor.diasVisita,
        'activo': proveedor.activo ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [proveedor.id],
    );

    return proveedor;
  }

  /// Registra una compra completa de mercadería de manera atómica en SQLite:
  /// Incrementa stock, actualiza costos mayoristas, genera kardex (ENTRADA_COMPRA)
  /// y descuenta de caja si hubo egreso del turno.
  Future<Map<String, dynamic>> registrarCompraMercaderia({
    required CompraModel compra,
    required List<ItemCompraModel> detalles,
  }) async {
    final db = await _db.database;

    return await db.transaction<Map<String, dynamic>>((txn) async {
      final compraId = compra.id.isNotEmpty ? compra.id : AppDatabase.nuevoId();
      final ahora = AppDatabase.ahora();
      final ticketCorto = compraId.length > 8 ? compraId.substring(0, 8) : compraId;

      String nombreProveedor = 'Proveedor';
      if (compra.proveedorId != null && compra.proveedorId!.isNotEmpty) {
        final provs = await txn.query('proveedores', columns: ['nombre_empresa'], where: 'id = ?', whereArgs: [compra.proveedorId]);
        if (provs.isNotEmpty) {
          nombreProveedor = provs.first['nombre_empresa'] as String? ?? 'Proveedor';
        }
      }

      // 1. Insertar Cabecera de Compra
      final compraMap = compra.copyWith(id: compraId).toMap();
      compraMap['created_at'] = ahora;
      await txn.insert('compras', AppDatabase.aFila(compraMap));

      // 2. Procesar cada detalle
      for (final item in detalles) {
        final dId = item.id ?? AppDatabase.nuevoId();
        await txn.insert('detalle_compras', AppDatabase.aFila({
          'id': dId,
          'compra_id': compraId,
          'producto_id': item.productoId,
          'cantidad': item.cantidad,
          'costo_unitario': item.costoUnitario,
          'subtotal': item.subtotal,
          if (item.nuevoPrecioVenta != null && item.nuevoPrecioVenta! > 0)
            'nuevo_precio_venta': item.nuevoPrecioVenta,
        }));

        // Actualizar producto
        final prods = await txn.query('productos', where: 'id = ?', whereArgs: [item.productoId]);
        if (prods.isEmpty) continue;

        final prod = prods.first;
        final stockActual = (prod['stock_actual'] as num).toDouble();
        final nuevoStock = stockActual + item.cantidad;

        final updates = <String, dynamic>{
          'stock_actual': nuevoStock,
          'costo_mayorista': item.costoUnitario,
          'updated_at': ahora,
        };
        if (item.nuevoPrecioVenta != null && item.nuevoPrecioVenta! > 0) {
          updates['precio_venta'] = item.nuevoPrecioVenta;
        }
        if (compra.proveedorId != null && compra.proveedorId!.isNotEmpty) {
          updates['proveedor_id'] = compra.proveedorId;
        }

        await txn.update('productos', updates, where: 'id = ?', whereArgs: [item.productoId]);

        // Kardex
        await txn.insert('movimientos_inventario', AppDatabase.aFila({
          'id': AppDatabase.nuevoId(),
          'tenant_id': compra.tenantId,
          'producto_id': item.productoId,
          'tipo_movimiento': 'ENTRADA_COMPRA',
          'cantidad': item.cantidad,
          'costo_unitario': item.costoUnitario,
          'costo_total': item.costoUnitario * item.cantidad,
          'motivo': 'Reabastecimiento compra $nombreProveedor (Ticket #$ticketCorto)',
          'referencia_id': compraId,
          'stock_anterior': stockActual,
          'stock_posterior': nuevoStock,
          'created_at': ahora,
        }));
      }

      // 3. Egreso de caja si aplica
      if (compra.montoPagadoCaja > 0 && compra.cajaTurnoId != null) {
        await txn.insert('movimientos_caja', AppDatabase.aFila({
          'id': AppDatabase.nuevoId(),
          'tenant_id': compra.tenantId,
          'turno_id': compra.cajaTurnoId,
          'tipo': 'SALIDA',
          'monto': compra.montoPagadoCaja,
          'motivo': 'Pago compra mercadería - $nombreProveedor (Ticket #$ticketCorto)',
          'origen_dinero': 'EFECTIVO_CAJA',
          'categoria': 'COMPRA_MERCADERIA',
          'created_at': ahora,
        }));
      }

      return {
        'success': true,
        'compra_id': compraId,
        'total_compra': compra.totalCompra,
        'monto_caja': compra.montoPagadoCaja,
        'monto_externo': compra.montoPagadoExterno,
        'proveedor': nombreProveedor,
        'items_count': detalles.length,
      };
    });
  }

  /// Consulta el historial de compras
  Future<List<CompraModel>> obtenerHistorialCompras(
    String tenantId, {
    DateTime? desde,
    DateTime? hasta,
    String? proveedorId,
    int limite = 50,
  }) async {
    final db = await _db.database;

    final where = <String>['c.tenant_id = ?'];
    final args = <dynamic>[tenantId];

    if (proveedorId != null && proveedorId.isNotEmpty) {
      where.add('c.proveedor_id = ?');
      args.add(proveedorId);
    }
    if (desde != null) {
      where.add('c.fecha_compra >= ?');
      args.add(desde.toIso8601String());
    }
    if (hasta != null) {
      where.add('c.fecha_compra <= ?');
      args.add(hasta.toIso8601String());
    }

    final sql = '''
      SELECT 
        c.*,
        p.nombre_empresa AS prov_nombre,
        (SELECT COUNT(*) FROM detalle_compras dc WHERE dc.compra_id = c.id) AS cant_articulos
      FROM compras c
      LEFT JOIN proveedores p ON p.id = c.proveedor_id
      WHERE ${where.join(' AND ')}
      ORDER BY c.fecha_compra DESC
      LIMIT $limite
    ''';

    final rows = await db.rawQuery(sql, args);

    return rows.map((r) {
      final map = AppDatabase.aMapa(r);
      return CompraModel(
        id: map['id'] as String,
        tenantId: map['tenant_id'] as String,
        proveedorId: map['proveedor_id'] as String?,
        numeroComprobante: map['numero_comprobante'] as String?,
        totalCompra: (map['total_compra'] as num).toDouble(),
        metodoPago: map['metodo_pago'] as String? ?? 'EFECTIVO_CAJA',
        montoPagadoCaja: (map['monto_pagado_caja'] as num?)?.toDouble() ?? 0.0,
        montoPagadoExterno: (map['monto_pagado_externo'] as num?)?.toDouble() ?? 0.0,
        cajaTurnoId: map['caja_turno_id'] as String?,
        observaciones: map['observaciones'] as String?,
        fechaCompra: DateTime.parse(map['fecha_compra'] as String),
        usuarioId: map['usuario_id'] as String?,
        nombreProveedor: map['prov_nombre'] as String?,
        cantidadArticulos: (map['cant_articulos'] as num?)?.toInt(),
      );
    }).toList();
  }

  /// Obtiene los ítems detallados de una compra específica
  Future<List<ItemCompraModel>> obtenerDetalleCompra(String compraId) async {
    final db = await _db.database;

    final sql = '''
      SELECT 
        dc.*,
        p.nombre AS prod_nombre,
        p.codigo_barras AS prod_codigo_barras,
        p.tipo_empaque AS prod_tipo_empaque,
        p.unidades_por_empaque AS prod_unidades_por_empaque,
        p.precio_venta AS prod_precio_venta
      FROM detalle_compras dc
      LEFT JOIN productos p ON p.id = dc.producto_id
      WHERE dc.compra_id = ?
    ''';

    final rows = await db.rawQuery(sql, [compraId]);

    return rows.map((r) {
      final map = AppDatabase.aMapa(r);
      return ItemCompraModel(
        id: map['id'] as String?,
        compraId: map['compra_id'] as String?,
        productoId: map['producto_id'] as String,
        cantidad: (map['cantidad'] as num).toDouble(),
        costoUnitario: (map['costo_unitario'] as num).toDouble(),
        subtotal: (map['subtotal'] as num).toDouble(),
        nuevoPrecioVenta: map['nuevo_precio_venta'] != null ? (map['nuevo_precio_venta'] as num).toDouble() : null,
        nombreProducto: map['prod_nombre'] as String? ?? 'Producto',
        codigoBarras: map['prod_codigo_barras'] as String?,
        tipoEmpaque: map['prod_tipo_empaque'] as String? ?? 'UNIDAD',
        unidadesPorEmpaque: (map['prod_unidades_por_empaque'] as num?)?.toDouble() ?? 1.0,
        costoAnterior: (map['costo_unitario'] as num).toDouble(),
        precioVentaActual: (map['prod_precio_venta'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  /// Guarda un pedido a proveedor como PENDIENTE (preventa o pedido por app/preventista).
  /// Separa automáticamente los pedidos por Empresa Distribuidora si los productos
  /// pertenecen a proveedores distintos (ej. CBN, Embol, Oriental).
  /// NO altera stock y NO descuenta de caja todavía hasta que llegue el camión.
  Future<Map<String, dynamic>> guardarPedidoPendiente({
    required CompraModel pedido,
    required List<ItemCompraModel> detalles,
  }) async {
    final db = await _db.database;

    return await db.transaction<Map<String, dynamic>>((txn) async {
      final ahora = AppDatabase.ahora();

      // 1. Agrupar los ítems según el proveedor asignado a cada producto
      final Map<String?, List<ItemCompraModel>> gruposPorProveedor = {};

      for (final item in detalles) {
        String? itemProvId = pedido.proveedorId;
        final prodRows = await txn.query(
          'productos',
          columns: ['proveedor_id'],
          where: 'id = ?',
          whereArgs: [item.productoId],
        );
        if (prodRows.isNotEmpty && prodRows.first['proveedor_id'] != null) {
          final dbProvId = prodRows.first['proveedor_id'] as String;
          if (dbProvId.trim().isNotEmpty) {
            itemProvId = dbProvId;
          }
        }
        gruposPorProveedor.putIfAbsent(itemProvId, () => []).add(item);
      }

      final List<Map<String, dynamic>> pedidosCreados = [];

      // 2. Crear un pedido pendiente independiente por cada empresa proveedora
      for (final entry in gruposPorProveedor.entries) {
        final provId = entry.key;
        final itemsGrupo = entry.value;
        final totalGrupo = itemsGrupo.fold<double>(0.0, (sum, i) => sum + i.subtotal);
        final pedidoId = AppDatabase.nuevoId();

        String nombreProveedor = 'Proveedor General';
        if (provId != null && provId.isNotEmpty) {
          final provs = await txn.query(
            'proveedores',
            columns: ['nombre_empresa'],
            where: 'id = ?',
            whereArgs: [provId],
          );
          if (provs.isNotEmpty) {
            nombreProveedor = provs.first['nombre_empresa'] as String? ?? 'Proveedor';
          }
        }

        final pedidoMap = pedido.copyWith(
          id: pedidoId,
          proveedorId: provId,
          totalCompra: totalGrupo,
          estado: 'PENDIENTE',
          montoPagadoCaja: 0.0,
          montoPagadoExterno: 0.0,
        ).toMap();
        pedidoMap['created_at'] = ahora;
        await txn.insert('compras', AppDatabase.aFila(pedidoMap));

        for (final item in itemsGrupo) {
          final dId = item.id ?? AppDatabase.nuevoId();
          await txn.insert('detalle_compras', AppDatabase.aFila({
            'id': dId,
            'compra_id': pedidoId,
            'producto_id': item.productoId,
            'cantidad': item.cantidad,
            'costo_unitario': item.costoUnitario,
            'subtotal': item.subtotal,
            if (item.nuevoPrecioVenta != null && item.nuevoPrecioVenta! > 0)
              'nuevo_precio_venta': item.nuevoPrecioVenta,
          }));
        }

        pedidosCreados.add({
          'id': pedidoId,
          'proveedor': nombreProveedor,
          'total': totalGrupo,
          'items_count': itemsGrupo.length,
        });
      }

      return {
        'success': true,
        'pedidos_creados': pedidosCreados,
        'cantidad_pedidos': pedidosCreados.length,
      };
    });
  }

  /// Confirma la llegada física del camión con la entrega de mercadería:
  /// - Recibe la lista final de ítems (ajustados si el camión trajo menos cantidad).
  /// - Suma el stock real a 'productos' en SQLite.
  /// - Registra el egreso de la caja activa del turno actual.
  /// - Genera Kardex (ENTRADA_COMPRA).
  /// - Cambia el estado de la orden a 'COMPLETADA'.
  Future<Map<String, dynamic>> confirmarRecepcionPedido({
    required String pedidoId,
    required List<ItemCompraModel> detallesRecibidos,
    required String metodoPago,
    required double montoCaja,
    required double montoExterno,
    String? cajaTurnoId,
    String? numeroComprobante,
    String? observaciones,
  }) async {
    final db = await _db.database;

    return await db.transaction<Map<String, dynamic>>((txn) async {
      final ahora = AppDatabase.ahora();
      final ticketCorto = pedidoId.length > 8 ? pedidoId.substring(0, 8) : pedidoId;

      final pedidosRows = await txn.query('compras', where: 'id = ?', whereArgs: [pedidoId]);
      if (pedidosRows.isEmpty) throw Exception('Pedido no encontrado');
      final pedidoRow = pedidosRows.first;
      final tenantId = pedidoRow['tenant_id'] as String;
      final proveedorId = pedidoRow['proveedor_id'] as String?;

      String nombreProveedor = 'Proveedor';
      if (proveedorId != null && proveedorId.isNotEmpty) {
        final provs = await txn.query('proveedores', columns: ['nombre_empresa'], where: 'id = ?', whereArgs: [proveedorId]);
        if (provs.isNotEmpty) {
          nombreProveedor = provs.first['nombre_empresa'] as String? ?? 'Proveedor';
        }
      }

      final nuevoTotal = detallesRecibidos.fold(0.0, (acc, item) => acc + item.subtotal);

      // 1. Actualizar estado y pagos de la compra
      await txn.update(
        'compras',
        {
          'total_compra': nuevoTotal,
          'metodo_pago': metodoPago,
          'monto_pagado_caja': montoCaja,
          'monto_pagado_externo': montoExterno,
          'caja_turno_id': cajaTurnoId,
          'numero_comprobante': ?numeroComprobante,
          'observaciones': ?observaciones,
          'estado': 'COMPLETADA',
          'fecha_entrega': ahora,
          'fecha_compra': ahora, // Fecha real en que ingresó físicamente
        },
        where: 'id = ?',
        whereArgs: [pedidoId],
      );

      // 2. Reemplazar detalles por lo realmente recibido
      await txn.delete('detalle_compras', where: 'compra_id = ?', whereArgs: [pedidoId]);

      for (final item in detallesRecibidos) {
        if (item.cantidad <= 0) continue; // Si no trajo nada de este producto

        final dId = AppDatabase.nuevoId();
        await txn.insert('detalle_compras', AppDatabase.aFila({
          'id': dId,
          'compra_id': pedidoId,
          'producto_id': item.productoId,
          'cantidad': item.cantidad,
          'costo_unitario': item.costoUnitario,
          'subtotal': item.subtotal,
          if (item.nuevoPrecioVenta != null && item.nuevoPrecioVenta! > 0)
            'nuevo_precio_venta': item.nuevoPrecioVenta,
        }));

        // Actualizar producto en inventario
        final prods = await txn.query('productos', where: 'id = ?', whereArgs: [item.productoId]);
        if (prods.isEmpty) continue;

        final prod = prods.first;
        final stockActual = (prod['stock_actual'] as num).toDouble();
        final nuevoStock = stockActual + item.cantidad;

        final updates = <String, dynamic>{
          'stock_actual': nuevoStock,
          'costo_mayorista': item.costoUnitario,
          'updated_at': ahora,
        };
        if (item.nuevoPrecioVenta != null && item.nuevoPrecioVenta! > 0) {
          updates['precio_venta'] = item.nuevoPrecioVenta;
        }
        if (proveedorId != null && proveedorId.isNotEmpty) {
          updates['proveedor_id'] = proveedorId;
        }

        await txn.update('productos', updates, where: 'id = ?', whereArgs: [item.productoId]);

        // Kardex
        await txn.insert('movimientos_inventario', AppDatabase.aFila({
          'id': AppDatabase.nuevoId(),
          'tenant_id': tenantId,
          'producto_id': item.productoId,
          'tipo_movimiento': 'ENTRADA_COMPRA',
          'cantidad': item.cantidad,
          'costo_unitario': item.costoUnitario,
          'costo_total': item.costoUnitario * item.cantidad,
          'motivo': 'Entrega de camión $nombreProveedor (Ticket #$ticketCorto)',
          'referencia_id': pedidoId,
          'stock_anterior': stockActual,
          'stock_posterior': nuevoStock,
          'created_at': ahora,
        }));
      }

      // 3. Egreso de caja del turno actual
      if (montoCaja > 0 && cajaTurnoId != null) {
        await txn.insert('movimientos_caja', AppDatabase.aFila({
          'id': AppDatabase.nuevoId(),
          'tenant_id': tenantId,
          'turno_id': cajaTurnoId,
          'tipo': 'SALIDA',
          'monto': montoCaja,
          'motivo': 'Pago recepción camión $nombreProveedor (Ticket #$ticketCorto)',
          'origen_dinero': 'EFECTIVO_CAJA',
          'categoria': 'COMPRA_MERCADERIA',
          'created_at': ahora,
        }));
      }

      return {
        'success': true,
        'pedido_id': pedidoId,
        'total_compra': nuevoTotal,
        'monto_caja': montoCaja,
        'monto_externo': montoExterno,
        'proveedor': nombreProveedor,
        'items_count': detallesRecibidos.length,
      };
    });
  }

  /// Cancela un pedido pendiente
  /// Cancela y elimina un pedido pendiente de la lista en camino
  Future<void> cancelarPedidoPendiente(String pedidoId) async {
    final db = await _db.database;
    await db.delete(
      'compras',
      where: 'id = ? AND estado = ?',
      whereArgs: [pedidoId, 'PENDIENTE'],
    );
  }

  /// Obtiene la lista de pedidos pendientes de entrega agrupados o filtrados por proveedor
  Future<List<CompraModel>> obtenerPedidosPendientes(
    String tenantId, {
    String? proveedorId,
  }) async {
    final db = await _db.database;

    final where = <String>['c.tenant_id = ?', "c.estado = 'PENDIENTE'"];
    final args = <dynamic>[tenantId];

    if (proveedorId != null && proveedorId.isNotEmpty) {
      where.add('c.proveedor_id = ?');
      args.add(proveedorId);
    }

    final sql = '''
      SELECT 
        c.*,
        p.nombre_empresa AS prov_nombre,
        (SELECT COUNT(*) FROM detalle_compras dc WHERE dc.compra_id = c.id) AS cant_articulos
      FROM compras c
      LEFT JOIN proveedores p ON p.id = c.proveedor_id
      WHERE ${where.join(' AND ')}
      ORDER BY c.fecha_compra DESC
    ''';

    final rows = await db.rawQuery(sql, args);

    return rows.map((r) {
      final map = AppDatabase.aMapa(r);
      return CompraModel.fromMap(map);
    }).toList();
  }

  /// Asocia un producto a un proveedor predeterminado
  Future<void> asociarProductoAProveedor(String productoId, String proveedorId) async {
    final db = await _db.database;
    await db.update(
      'productos',
      {'proveedor_id': proveedorId},
      where: 'id = ?',
      whereArgs: [productoId],
    );
  }
}
