import '../../../../core/database/app_database.dart';
import '../models/venta_models.dart';

class VentaRepository {
  final AppDatabase _db;

  VentaRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  /// Registra una venta completa inmutable en SQLite local:
  /// 1. Inserta la venta en 'ventas' (si es CREDITO_FIADO, el trigger actualiza el saldo del cliente automáticamente).
  /// 2. Inserta 'detalle_ventas' en lote.
  /// 3. Inserta 'pagos_ventas' en lote.
  /// 4. Descuenta el stock en 'productos' con auto-desempaque transparente si hace falta.
  /// 5. Registra el Kardex de salida en 'movimientos_inventario'.
  Future<Venta> registrarTransaccionCompleta({
    required Venta venta,
    required List<DetalleVenta> detalles,
    required List<PagoVenta> pagos,
  }) async {
    final db = await _db.database;

    return await db.transaction<Venta>((txn) async {
      final ventaId = venta.id ?? AppDatabase.nuevoId();
      final ventaAGuardar = venta.copyWith(id: ventaId);

      // 1. Insertar Cabecera de Venta
      await txn.insert('ventas', AppDatabase.aFila(ventaAGuardar.toMap()));

      // 2. Insertar Detalle de Ventas con el costo mayorista más reciente de la BD
      for (final detalle in detalles) {
        final prodsCosto = await txn.query(
          'productos',
          columns: ['costo_mayorista'],
          where: 'id = ?',
          whereArgs: [detalle.productoId],
        );
        final double costoFresco = (prodsCosto.isNotEmpty && prodsCosto.first['costo_mayorista'] != null)
            ? (prodsCosto.first['costo_mayorista'] as num).toDouble()
            : detalle.costoUnitario;

        final dId = detalle.id ?? AppDatabase.nuevoId();
        final dMap = detalle.copyWith(
          id: dId,
          ventaId: ventaId,
          costoUnitario: costoFresco,
        ).toMap();
        await txn.insert('detalle_ventas', AppDatabase.aFila(dMap));
      }

      // 3. Insertar Pagos
      for (final pago in pagos) {
        final pId = pago.id ?? AppDatabase.nuevoId();
        final pMap = pago.copyWith(id: pId, ventaId: ventaId).toMap();
        await txn.insert('pagos_ventas', AppDatabase.aFila(pMap));
      }

      // 4. Descontar Stock con Auto-Desempaque transparente
      final ahora = AppDatabase.ahora();

      for (final detalle in detalles) {
        final prods = await txn.query(
          'productos',
          columns: ['stock_actual', 'costo_mayorista', 'nombre'],
          where: 'id = ?',
          whereArgs: [detalle.productoId],
        );

        if (prods.isEmpty) continue;

        double stockActual = (prods.first['stock_actual'] as num).toDouble();
        final double costoUnit = (prods.first['costo_mayorista'] as num?)?.toDouble() ?? detalle.costoUnitario;

        // Auto-desempaque si el stock no alcanza
        if (stockActual < detalle.cantidad) {
          final cajasPadre = await txn.query(
            'productos',
            columns: ['id', 'stock_actual', 'unidades_por_empaque', 'costo_mayorista'],
            where: 'producto_hijo_id = ? AND tenant_id = ? AND stock_actual > 0',
            whereArgs: [detalle.productoId, venta.tenantId],
            orderBy: 'stock_actual DESC',
          );

          if (cajasPadre.isNotEmpty) {
            final caja = cajasPadre.first;
            final double unidadesPorCaja = (caja['unidades_por_empaque'] as num?)?.toDouble() ?? 1.0;
            final double faltante = detalle.cantidad - stockActual;
            final double cajasANecesitar = unidadesPorCaja > 0
                ? (faltante / unidadesPorCaja).ceilToDouble()
                : 1.0;
            final double cajasDisponibles = (caja['stock_actual'] as num).toDouble();
            final double cajasAAbrir = cajasANecesitar <= cajasDisponibles ? cajasANecesitar : cajasDisponibles;

            if (cajasAAbrir > 0) {
              final cajaId = caja['id'] as String;
              final costoCaja = (caja['costo_mayorista'] as num).toDouble();
              final nuevoStockCaja = cajasDisponibles - cajasAAbrir;
              final unidadesASumar = cajasAAbrir * unidadesPorCaja;
              final nuevoStockUnidades = stockActual + unidadesASumar;

              await txn.update(
                'productos',
                {'stock_actual': nuevoStockCaja, 'updated_at': ahora},
                where: 'id = ?',
                whereArgs: [cajaId],
              );

              final salidaId = AppDatabase.nuevoId();
              final entradaId = AppDatabase.nuevoId();

              await txn.insert('movimientos_inventario', AppDatabase.aFila({
                'id': salidaId,
                'tenant_id': venta.tenantId,
                'producto_id': cajaId,
                'tipo_movimiento': 'DESEMPAQUE_SALIDA',
                'cantidad': cajasAAbrir,
                'costo_unitario': costoCaja,
                'costo_total': costoCaja * cajasAAbrir,
                'motivo': 'Auto-desempaque por venta (Ticket #${ventaId.substring(0, 8)})',
                'referencia_id': entradaId,
                'stock_anterior': cajasDisponibles,
                'stock_posterior': nuevoStockCaja,
                'created_at': ahora,
              }));

              await txn.insert('movimientos_inventario', AppDatabase.aFila({
                'id': entradaId,
                'tenant_id': venta.tenantId,
                'producto_id': detalle.productoId,
                'tipo_movimiento': 'DESEMPAQUE_ENTRADA',
                'cantidad': unidadesASumar,
                'costo_unitario': unidadesPorCaja > 0 ? (costoCaja / unidadesPorCaja) : costoUnit,
                'costo_total': costoCaja * cajasAAbrir,
                'motivo': 'Entrada por auto-desempaque (Ticket #${ventaId.substring(0, 8)})',
                'referencia_id': salidaId,
                'stock_anterior': stockActual,
                'stock_posterior': nuevoStockUnidades,
                'created_at': ahora,
              }));

              stockActual = nuevoStockUnidades;
            }
          }
        }

        if (stockActual < detalle.cantidad) {
          final nombreProd = prods.first['nombre'] as String? ?? 'Producto';
          throw Exception('Stock insuficiente para "$nombreProd". Disponible: $stockActual, requerido: ${detalle.cantidad}');
        }

        final double nuevoStock = stockActual - detalle.cantidad;

        await txn.update(
          'productos',
          {'stock_actual': nuevoStock, 'updated_at': ahora},
          where: 'id = ?',
          whereArgs: [detalle.productoId],
        );

        // Kardex inmutable
        final ticketCorto = ventaId.length > 8 ? ventaId.substring(0, 8) : ventaId;
        await txn.insert('movimientos_inventario', AppDatabase.aFila({
          'id': AppDatabase.nuevoId(),
          'tenant_id': venta.tenantId,
          'producto_id': detalle.productoId,
          'tipo_movimiento': 'VENTA',
          'cantidad': detalle.cantidad,
          'costo_unitario': detalle.costoUnitario,
          'costo_total': detalle.costoUnitario * detalle.cantidad,
          'motivo': 'Venta mostrador (Ticket #$ticketCorto)',
          'referencia_id': ventaId,
          'stock_anterior': stockActual,
          'stock_posterior': nuevoStock,
          'created_at': ahora,
        }));
      }

      return ventaAGuardar;
    });
  }
}
