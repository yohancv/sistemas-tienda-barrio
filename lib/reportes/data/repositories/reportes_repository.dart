import 'dart:math';
import '../../../core/database/app_database.dart';
import '../models/reporte_financiero_model.dart';

class ReportesRepository {
  final AppDatabase _db;

  ReportesRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  /// Genera el reporte completo consolidado para el período especificado
  Future<DashboardReporteCompleto> obtenerReporteCompleto(PeriodoFiltroReporte periodo) async {
    final now = DateTime.now();
    DateTime fechaInicio;
    final DateTime fechaFin = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (periodo) {
      case PeriodoFiltroReporte.hoy:
        fechaInicio = DateTime(now.year, now.month, now.day, 0, 0, 0);
        break;
      case PeriodoFiltroReporte.estaSemana:
        // Últimos 7 días incluyendo hoy
        final haceSieteDias = now.subtract(const Duration(days: 6));
        fechaInicio = DateTime(haceSieteDias.year, haceSieteDias.month, haceSieteDias.day, 0, 0, 0);
        break;
      case PeriodoFiltroReporte.esteMes:
        // Desde el día 1 del mes en curso
        fechaInicio = DateTime(now.year, now.month, 1, 0, 0, 0);
        break;
    }

    final inicioIso = fechaInicio.toIso8601String();
    final finIso = fechaFin.toIso8601String();

    final db = await _db.database;

    // 1. Consulta financiera de ventas globales
    final resVentas = await db.rawQuery('''
      SELECT 
        COUNT(id) as conteo_ventas,
        COALESCE(SUM(total_venta), 0) as suma_ventas
      FROM ventas
      WHERE fecha_venta >= ? AND fecha_venta <= ?
    ''', [inicioIso, finIso]);

    final int totalTransacciones = (resVentas.first['conteo_ventas'] as num?)?.toInt() ?? 0;
    final double sumaVentasCabecera = (resVentas.first['suma_ventas'] as num?)?.toDouble() ?? 0.0;

    // 2. Consulta de costos y artículos desde detalle_ventas
    final resDetalles = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(dv.cantidad), 0) as total_articulos,
        COALESCE(SUM(dv.subtotal), 0) as suma_subtotales,
        COALESCE(SUM(dv.cantidad * dv.costo_unitario), 0) as costo_total
      FROM detalle_ventas dv
      JOIN ventas v ON dv.venta_id = v.id
      WHERE v.fecha_venta >= ? AND v.fecha_venta <= ?
    ''', [inicioIso, finIso]);

    final int totalArticulosVendidos = ((resDetalles.first['total_articulos'] as num?)?.toDouble() ?? 0.0).round();
    final double sumaDetalles = (resDetalles.first['suma_subtotales'] as num?)?.toDouble() ?? 0.0;
    final double costoTotalMercaderia = (resDetalles.first['costo_total'] as num?)?.toDouble() ?? 0.0;

    // Si por alguna razón la cabecera tiene un total mayor o igual, aseguramos concordancia
    final double ventasTotales = max(sumaVentasCabecera, sumaDetalles);

    // 3. Desglose de Medios de Pago de Ventas (pagos_ventas con fallback a ventas)
    double ventasEfectivo = 0.0;
    double ventasQr = 0.0;
    double ventasFiado = 0.0;

    final resPagos = await db.rawQuery('''
      SELECT 
        pv.metodo,
        COALESCE(SUM(pv.monto), 0) as total
      FROM pagos_ventas pv
      JOIN ventas v ON pv.venta_id = v.id
      WHERE v.fecha_venta >= ? AND v.fecha_venta <= ?
      GROUP BY pv.metodo
    ''', [inicioIso, finIso]);

    if (resPagos.isNotEmpty) {
      for (final fila in resPagos) {
        final m = fila['metodo'] as String? ?? '';
        final val = (fila['total'] as num?)?.toDouble() ?? 0.0;
        if (m == 'EFECTIVO') ventasEfectivo += val;
        if (m == 'QR') ventasQr += val;
        if (m == 'FIADO') ventasFiado += val;
      }
    } else {
      // Fallback a ventas.metodo_pago
      final resMetodosVenta = await db.rawQuery('''
        SELECT 
          metodo_pago,
          COALESCE(SUM(total_venta), 0) as total
        FROM ventas
        WHERE fecha_venta >= ? AND fecha_venta <= ?
        GROUP BY metodo_pago
      ''', [inicioIso, finIso]);

      for (final fila in resMetodosVenta) {
        final m = fila['metodo_pago'] as String? ?? '';
        final val = (fila['total'] as num?)?.toDouble() ?? 0.0;
        if (m == 'EFECTIVO') ventasEfectivo += val;
        if (m == 'QR') ventasQr += val;
        if (m == 'CREDITO_FIADO' || m == 'FIADO') ventasFiado += val;
      }
    }

    // 4. Consulta de Abonos a Deuda (Fiados cobrados durante este período)
    final resAbonos = await db.rawQuery('''
      SELECT 
        metodo_pago,
        COALESCE(SUM(monto), 0) as total
      FROM abonos_deuda
      WHERE fecha_abono >= ? AND fecha_abono <= ?
      GROUP BY metodo_pago
    ''', [inicioIso, finIso]);

    double abonosEfectivo = 0.0;
    double abonosQr = 0.0;
    for (final fila in resAbonos) {
      final m = (fila['metodo_pago'] as String? ?? 'EFECTIVO').toUpperCase();
      final val = (fila['total'] as num?)?.toDouble() ?? 0.0;
      if (m == 'QR' || m == 'TRANSFERENCIA' || m == 'BANCO') {
        abonosQr += val;
      } else {
        abonosEfectivo += val;
      }
    }
    final double totalAbonosCobrados = abonosEfectivo + abonosQr;

    // 5. Total de Dinero Ingresado a Caja y Banco (Flujo de Dinero Líquido)
    final double totalDineroEnCaja = ventasEfectivo + abonosEfectivo;
    final double totalDineroEnBanco = ventasQr + abonosQr;
    final double totalCobradoReal = totalDineroEnCaja + totalDineroEnBanco;

    // 6. Proporción de Costos (Cobrado vs Fiado)
    final double ventasCobradas = ventasEfectivo + ventasQr;
    final double baseVentas = max(ventasTotales, ventasCobradas + ventasFiado);

    final double proporcionCobrada = baseVentas > 0
        ? (ventasCobradas / baseVentas).clamp(0.0, 1.0)
        : 0.0;
    final double costoMercaderiaCobrada = costoTotalMercaderia * proporcionCobrada;
    final double costoMercaderiaFiada = max(0.0, costoTotalMercaderia - costoMercaderiaCobrada);

    // 7. Mermas y Bajas del período (pérdidas financieras)
    final resMermas = await db.rawQuery('''
      SELECT COALESCE(SUM(costo_total), 0) as total_mermas
      FROM movimientos_inventario
      WHERE tipo_movimiento IN ('MERMA_ROTURA', 'MERMA_VENCIMIENTO', 'MERMA_DETERIORO', 'AJUSTE_NEGATIVO')
        AND created_at >= ? AND created_at <= ?
    ''', [inicioIso, finIso]);

    final double totalMermas = (resMermas.first['total_mermas'] as num?)?.toDouble() ?? 0.0;

    // 8. Gastos Operativos de Tienda (salidas registradas en caja: bolsas, luz, ayudante, etc.)
    final resGastos = await db.rawQuery('''
      SELECT COALESCE(SUM(monto), 0) as total_gastos
      FROM movimientos_caja
      WHERE tipo = 'SALIDA'
        AND categoria IN ('GASTO_TIENDA', 'PAGO_AYUDANTE', 'OTRO')
        AND created_at >= ? AND created_at <= ?
    ''', [inicioIso, finIso]);

    final double totalGastosTienda = (resGastos.first['total_gastos'] as num?)?.toDouble() ?? 0.0;

    // 9. Ganancias Diferenciadas y Utilidad Neta del Balance
    final double gananciaBrutaCobrada = max(0.0, ventasCobradas - costoMercaderiaCobrada);
    final double margenCobradoPorcentaje = ventasCobradas > 0
        ? (gananciaBrutaCobrada / ventasCobradas) * 100.0
        : (baseVentas > 0 ? ((baseVentas - costoTotalMercaderia) / baseVentas) * 100.0 : 0.0);

    // Los abonos son cobros de fiados: contienen recuperación de costo + ganancia
    final double factorMargenAbonos = margenCobradoPorcentaje > 0 ? (margenCobradoPorcentaje / 100.0) : 0.20;
    final double gananciaRealAbonos = totalAbonosCobrados * factorMargenAbonos;

    final double gananciaCobradaEnMano = max(0.0, gananciaBrutaCobrada + gananciaRealAbonos - totalMermas);
    final double utilidadNetaBalance = gananciaCobradaEnMano - totalGastosTienda;
    final double gananciaPendienteFiados = max(0.0, ventasFiado - costoMercaderiaFiada);
    final double gananciaTotalProyectada = max(0.0, (baseVentas - costoTotalMercaderia) - totalMermas - totalGastosTienda);

    final financiero = ReporteFinancieroModel(
      ventasTotales: baseVentas,
      ventasCobradas: ventasCobradas,
      ventasFiadas: ventasFiado,
      totalAbonosCobrados: totalAbonosCobrados,
      totalEfectivoVentas: ventasEfectivo,
      totalEfectivoAbonos: abonosEfectivo,
      totalDineroEnCaja: totalDineroEnCaja,
      totalQrVentas: ventasQr,
      totalQrAbonos: abonosQr,
      totalDineroEnBanco: totalDineroEnBanco,
      totalCobradoReal: totalCobradoReal,
      costoTotalMercaderia: costoTotalMercaderia,
      costoMercaderiaCobrada: costoMercaderiaCobrada,
      costoMercaderiaFiada: costoMercaderiaFiada,
      totalMermas: totalMermas,
      totalGastosTienda: totalGastosTienda,
      gananciaCobradaEnMano: gananciaCobradaEnMano,
      utilidadNetaBalance: utilidadNetaBalance,
      gananciaPendienteFiados: gananciaPendienteFiados,
      gananciaTotalProyectada: gananciaTotalProyectada,
      margenCobradoPorcentaje: margenCobradoPorcentaje,
      totalTransacciones: totalTransacciones,
      totalArticulosVendidos: totalArticulosVendidos,
    );

    // 5. Top 5 Productos Más Vendidos
    final resTop = await db.rawQuery('''
      SELECT 
        p.id as producto_id,
        p.nombre as nombre,
        p.categoria as categoria,
        COALESCE(SUM(dv.cantidad), 0) as cantidad_vendida,
        COALESCE(SUM(dv.subtotal), 0) as total_venta,
        COALESCE(SUM(dv.cantidad * dv.costo_unitario), 0) as costo_total
      FROM detalle_ventas dv
      JOIN ventas v ON dv.venta_id = v.id
      JOIN productos p ON dv.producto_id = p.id
      WHERE v.fecha_venta >= ? AND v.fecha_venta <= ?
      GROUP BY p.id, p.nombre, p.categoria
      ORDER BY total_venta DESC
      LIMIT 5
    ''', [inicioIso, finIso]);

    final List<TopProductoReporteModel> topProductos = resTop.map((row) {
      final vTotal = (row['total_venta'] as num?)?.toDouble() ?? 0.0;
      final cTotal = (row['costo_total'] as num?)?.toDouble() ?? 0.0;
      return TopProductoReporteModel(
        productoId: row['producto_id'] as String? ?? '',
        nombre: row['nombre'] as String? ?? 'Producto',
        categoria: row['categoria'] as String?,
        cantidadVendida: (row['cantidad_vendida'] as num?)?.toDouble() ?? 0.0,
        totalVenta: vTotal,
        costoTotal: cTotal,
        gananciaAportada: max(0.0, vTotal - cTotal),
      );
    }).toList();

    // 6. Ventas por Categoría
    final resCategorias = await db.rawQuery('''
      SELECT 
        COALESCE(p.categoria, 'Otros') as categoria,
        COALESCE(SUM(dv.subtotal), 0) as total_venta,
        COALESCE(SUM(dv.cantidad * dv.costo_unitario), 0) as costo_total
      FROM detalle_ventas dv
      JOIN ventas v ON dv.venta_id = v.id
      JOIN productos p ON dv.producto_id = p.id
      WHERE v.fecha_venta >= ? AND v.fecha_venta <= ?
      GROUP BY COALESCE(p.categoria, 'Otros')
      ORDER BY total_venta DESC
    ''', [inicioIso, finIso]);

    final List<CategoriaVentaReporteModel> ventasPorCategoria = resCategorias.map((row) {
      final vTotal = (row['total_venta'] as num?)?.toDouble() ?? 0.0;
      final cTotal = (row['costo_total'] as num?)?.toDouble() ?? 0.0;
      final porc = ventasTotales > 0 ? (vTotal / ventasTotales) * 100.0 : 0.0;
      return CategoriaVentaReporteModel(
        categoria: row['categoria'] as String? ?? 'Otros',
        totalVenta: vTotal,
        totalGanancia: max(0.0, vTotal - cTotal),
        porcentajeDelTotal: porc,
      );
    }).toList();

    return DashboardReporteCompleto(
      periodo: periodo,
      fechaInicio: fechaInicio,
      fechaFin: fechaFin,
      financiero: financiero,
      topProductos: topProductos,
      ventasPorCategoria: ventasPorCategoria,
    );
  }
}
