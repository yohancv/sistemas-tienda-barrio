import '../../../../core/database/app_database.dart';
import '../models/caja_turno_model.dart';
import '../models/movimiento_caja_model.dart';
import '../models/resumen_caja_model.dart';
import '../models/venta_turno_model.dart';

class CajaRepository {
  final AppDatabase _db;

  CajaRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  /// Obtiene el turno de caja abierto actualmente para el tenant
  Future<CajaTurnoModel?> obtenerTurnoActivo(String tenantId) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'cajas_turnos',
        where: 'tenant_id = ? AND estado = ?',
        whereArgs: [tenantId, 'ABIERTA'],
        orderBy: 'fecha_apertura DESC',
        limit: 1,
      );

      if (rows.isEmpty) return null;
      return CajaTurnoModel.fromMap(AppDatabase.aMapa(rows.first));
    } catch (_) {
      return null;
    }
  }

  /// Devuelve el inicio de la jornada comercial (05:00 AM) para una fecha dada.
  /// En tiendas nocturnas, las ventas de 00:00 a 04:59 AM pertenecen a la jornada que inició a las 05:00 AM del día previo.
  static DateTime obtenerInicioJornadaComercial([DateTime? fecha]) {
    final ref = fecha ?? DateTime.now();
    if (ref.hour < 5) {
      final ayer = ref.subtract(const Duration(days: 1));
      return DateTime(ayer.year, ayer.month, ayer.day, 5, 0, 0);
    }
    return DateTime(ref.year, ref.month, ref.day, 5, 0, 0);
  }

  /// Asegura que siempre exista un turno de caja activo (Modo Dueño / Caja Continua).
  /// Si amaneció una nueva jornada (después de las 05:00 AM) y el turno anterior no se cerró,
  /// realiza un corte automático silencioso y arranca el nuevo día con 0.0 Bs listo para operar.
  Future<CajaTurnoModel> asegurarTurnoActivo({
    required String tenantId,
    double montoInicial = 0.0,
    String? usuarioId,
  }) async {
    final db = await _db.database;

    final turnosAbiertos = await db.query(
      'cajas_turnos',
      where: 'tenant_id = ? AND estado = ?',
      whereArgs: [tenantId, 'ABIERTA'],
      orderBy: 'fecha_apertura DESC',
    );

    // Si existían múltiples turnos abiertos duplicados, consolidar cerrando los sobrantes de inmediato
    if (turnosAbiertos.length > 1) {
      for (int i = 1; i < turnosAbiertos.length; i++) {
        final idSobrante = turnosAbiertos[i]['id'] as String;
        await db.update(
          'cajas_turnos',
          {'estado': 'CERRADA', 'observaciones_cierre': 'Consolidado automático'},
          where: 'id = ?',
          whereArgs: [idSobrante],
        );
      }
    }

    final inicioJornadaActual = obtenerInicioJornadaComercial();
    CajaTurnoModel? turnoActivo;

    if (turnosAbiertos.isNotEmpty) {
      final masReciente = CajaTurnoModel.fromMap(AppDatabase.aMapa(turnosAbiertos.first));

      // Auto-Corte Silencioso de Madrugada (05:00 AM):
      // Si el turno abierto es de una jornada comercial anterior (abierto antes de las 05:00 AM del ciclo actual),
      // se congela y archiva automáticamente para que la tienda amanezca lista con 0.0 Bs.
      if (masReciente.fechaApertura.isBefore(inicioJornadaActual)) {
        try {
          final resumenVencido = await obtenerResumenTurno(masReciente.id, tenantId);
          await cerrarTurno(
            turnoId: masReciente.id,
            montoContado: resumenVencido.montoEsperadoEfectivo,
            resumen: resumenVencido,
            observaciones: 'Cierre automático de madrugada (05:00 AM)',
          );
        } catch (_) {}
      } else {
        turnoActivo = masReciente;
      }
    }

    // Si no había turno o el anterior se cerró por cambio de jornada, abrir el nuevo turno con 0.0 Bs
    turnoActivo ??= await abrirTurno(
      tenantId: tenantId,
      montoInicial: 0.0,
      usuarioId: usuarioId ?? 'DUEÑO',
    );

    // Auto-curación (Auto-heal): Re-asociar ventas y abonos de la jornada actual al turno activo
    try {
      final inicioJornadaIso = inicioJornadaActual.toIso8601String();

      await db.rawUpdate('''
        UPDATE ventas
        SET caja_turno_id = ?
        WHERE (caja_turno_id IS NULL 
            OR caja_turno_id = '' 
            OR caja_turno_id NOT IN (SELECT id FROM cajas_turnos WHERE estado = 'CERRADA'))
          AND (caja_turno_id != ? OR caja_turno_id IS NULL)
          AND fecha_venta >= ?
      ''', [turnoActivo.id, turnoActivo.id, inicioJornadaIso]);

      await db.rawUpdate('''
        UPDATE abonos_deuda
        SET caja_turno_id = ?
        WHERE (caja_turno_id IS NULL 
            OR caja_turno_id = '' 
            OR caja_turno_id NOT IN (SELECT id FROM cajas_turnos WHERE estado = 'CERRADA'))
          AND (caja_turno_id != ? OR caja_turno_id IS NULL)
          AND fecha_abono >= ?
      ''', [turnoActivo.id, turnoActivo.id, inicioJornadaIso]);
    } catch (_) {}

    return turnoActivo;
  }

  /// Inicia un nuevo turno de caja con el fondo inicial en Bs (por defecto 0.0 Bs).
  /// Cierra cualquier turno previo que haya quedado residualmente abierto para evitar bloqueos.
  Future<CajaTurnoModel> abrirTurno({
    required String tenantId,
    required double montoInicial,
    String? usuarioId,
  }) async {
    final db = await _db.database;

    // Cerrar cualquier turno previo que haya quedado en estado ABIERTA
    await db.update(
      'cajas_turnos',
      {
        'estado': 'CERRADA',
        'fecha_cierre': AppDatabase.ahora(),
        'observaciones_cierre': 'Cierre por apertura de nuevo turno',
      },
      where: 'tenant_id = ? AND estado = ?',
      whereArgs: [tenantId, 'ABIERTA'],
    );

    final id = AppDatabase.nuevoId();
    final ahora = AppDatabase.ahora();

    final payload = {
      'id': id,
      'tenant_id': tenantId,
      'monto_inicial': montoInicial,
      'monto_esperado_efectivo': montoInicial,
      'total_ventas_efectivo': 0.0,
      'total_ventas_qr': 0.0,
      'total_fiados_otorgados': 0.0,
      'total_fiados_cobrados_efectivo': 0.0,
      'total_fiados_cobrados_qr': 0.0,
      'total_salidas_manuales': 0.0,
      'total_entradas_manuales': 0.0,
      'total_retiros_qr': 0.0,
      'total_salidas_tienda': 0.0,
      'total_salidas_personal': 0.0,
      'saldo_neto_qr': 0.0,
      'estado': 'ABIERTA',
      'fecha_apertura': ahora,
      'created_at': ahora,
      'usuario_id': usuarioId ?? 'DUEÑO',
    };

    await db.insert('cajas_turnos', AppDatabase.aFila(payload));
    return CajaTurnoModel.fromMap(payload);
  }

  /// Calcula el resumen financiero consolidado del turno
  Future<ResumenCajaModel> obtenerResumenTurno(String turnoId, String tenantId) async {
    final db = await _db.database;

    final turnos = await db.query(
      'cajas_turnos',
      where: 'id = ? AND tenant_id = ?',
      whereArgs: [turnoId, tenantId],
    );

    if (turnos.isEmpty) {
      throw Exception('Turno de caja no encontrado');
    }

    final turno = CajaTurnoModel.fromMap(AppDatabase.aMapa(turnos.first));
    final inicioJornadaTurno = obtenerInicioJornadaComercial(turno.fechaApertura);
    final fechaFiltro = turno.fechaApertura.isAfter(inicioJornadaTurno)
        ? inicioJornadaTurno.toIso8601String()
        : turno.fechaApertura.toIso8601String();

    // 1. Movimientos de caja (Efectivo y QR)
    final movsData = await db.query(
      'movimientos_caja',
      where: 'turno_id = ?',
      whereArgs: [turnoId],
    );

    double totalEntradasCaja = 0.0;
    double totalSalidasCaja = 0.0;
    double totalEntradasQr = 0.0;
    double totalRetirosQr = 0.0;
    double totalSalidasTienda = 0.0;
    double totalSalidasPersonal = 0.0;
    double totalMercaderiaFutura = 0.0;

    for (final row in movsData) {
      final tipo = row['tipo'] as String;
      final monto = (row['monto'] as num).toDouble();
      final origen = row['origen_dinero'] as String? ?? 'EFECTIVO_CAJA';
      final categoria = row['categoria'] as String? ?? 'GASTO_TIENDA';

      if (origen == 'EFECTIVO_CAJA') {
        if (tipo == 'ENTRADA') totalEntradasCaja += monto;
        if (tipo == 'SALIDA') totalSalidasCaja += monto;
      } else if (origen == 'BANCO_QR') {
        if (tipo == 'ENTRADA') totalEntradasQr += monto;
        if (tipo == 'SALIDA') totalRetirosQr += monto;
      }

      if (tipo == 'SALIDA') {
        if (categoria == 'RETIRO_PERSONAL' || categoria == 'AHORRO') {
          totalSalidasPersonal += monto;
        } else if (categoria == 'MERCADERIA_FUTURA') {
          totalMercaderiaFutura += monto;
        } else if (categoria == 'GASTO_TIENDA' || categoria == 'PAGO_AYUDANTE' || categoria == 'OTRO') {
          totalSalidasTienda += monto;
        }
      }
    }

    // 2. Ventas Efectivo y QR desde pagos_ventas
    final sqlPagos = '''
      SELECT pv.metodo, SUM(pv.monto) as total
      FROM pagos_ventas pv
      JOIN ventas v ON v.id = pv.venta_id
      WHERE (pv.tenant_id = ? OR v.tenant_id = ? OR pv.tenant_id IS NULL OR v.tenant_id IS NULL)
        AND (
          v.caja_turno_id = ?
          OR (
            (v.caja_turno_id IS NULL OR v.caja_turno_id = '' OR v.caja_turno_id NOT IN (SELECT id FROM cajas_turnos WHERE estado = 'CERRADA'))
            AND v.fecha_venta >= ?
          )
        )
      GROUP BY pv.metodo
    ''';

    final pagosRes = await db.rawQuery(sqlPagos, [tenantId, tenantId, turnoId, fechaFiltro]);
    double ventasEfectivo = 0.0;
    double ventasQr = 0.0;

    for (final r in pagosRes) {
      final metodo = (r['metodo'] as String? ?? '').toUpperCase().trim();
      final total = (r['total'] as num?)?.toDouble() ?? 0.0;
      if (metodo == 'EFECTIVO') ventasEfectivo += total;
      if (metodo == 'QR' || metodo == 'BANCO' || metodo == 'TRANSFERENCIA') ventasQr += total;
    }

    // Fallback: ventas registradas directamente que no tengan filas en pagos_ventas
    final sqlVentasSinPagos = '''
      SELECT v.metodo_pago, SUM(v.total_venta) as total
      FROM ventas v
      WHERE (v.tenant_id = ? OR v.tenant_id IS NULL)
        AND (
          v.caja_turno_id = ?
          OR (
            (v.caja_turno_id IS NULL OR v.caja_turno_id = '' OR v.caja_turno_id NOT IN (SELECT id FROM cajas_turnos WHERE estado = 'CERRADA'))
            AND v.fecha_venta >= ?
          )
        )
        AND v.id NOT IN (SELECT DISTINCT venta_id FROM pagos_ventas WHERE venta_id IS NOT NULL)
      GROUP BY v.metodo_pago
    ''';
    final ventasSinPagosRes = await db.rawQuery(sqlVentasSinPagos, [tenantId, turnoId, fechaFiltro]);
    for (final r in ventasSinPagosRes) {
      final metodo = (r['metodo_pago'] as String? ?? '').toUpperCase().trim();
      final total = (r['total'] as num?)?.toDouble() ?? 0.0;
      if (metodo == 'EFECTIVO') ventasEfectivo += total;
      if (metodo == 'QR' || metodo == 'BANCO' || metodo == 'TRANSFERENCIA') ventasQr += total;
    }

    // 3. Fiados Otorgados (monto neto fiado tras descontar anticipos en efectivo/QR)
    final sqlFiados = '''
      SELECT COALESCE(SUM(total_venta - COALESCE(monto_recibido, 0)), 0) as total
      FROM ventas
      WHERE (tenant_id = ? OR tenant_id IS NULL)
        AND (metodo_pago = 'CREDITO_FIADO' OR metodo_pago = 'FIADO')
        AND (
          caja_turno_id = ?
          OR (
            (caja_turno_id IS NULL OR caja_turno_id = '' OR caja_turno_id NOT IN (SELECT id FROM cajas_turnos WHERE estado = 'CERRADA'))
            AND fecha_venta >= ?
          )
        )
    ''';
    final fiadosRes = await db.rawQuery(sqlFiados, [tenantId, turnoId, fechaFiltro]);
    final double fiadosOtorgados = (fiadosRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // 4. Fiados Cobrados (Abonos)
    final sqlAbonos = '''
      SELECT metodo_pago, COALESCE(SUM(monto), 0) as total
      FROM abonos_deuda
      WHERE (tenant_id = ? OR tenant_id IS NULL)
        AND (
          caja_turno_id = ?
          OR (
            (caja_turno_id IS NULL OR caja_turno_id = '' OR caja_turno_id NOT IN (SELECT id FROM cajas_turnos WHERE estado = 'CERRADA'))
            AND fecha_abono >= ?
          )
        )
      GROUP BY metodo_pago
    ''';
    final abonosRes = await db.rawQuery(sqlAbonos, [tenantId, turnoId, fechaFiltro]);
    double fiadosCobradosEfectivo = 0.0;
    double fiadosCobradosQr = 0.0;

    for (final r in abonosRes) {
      final metodo = (r['metodo_pago'] as String? ?? '').toUpperCase().trim();
      final total = (r['total'] as num?)?.toDouble() ?? 0.0;
      if (metodo == 'EFECTIVO') fiadosCobradosEfectivo += total;
      if (metodo == 'QR' || metodo == 'TRANSFERENCIA' || metodo == 'BANCO') fiadosCobradosQr += total;
    }

    // 5. Cálculos finales
    final double esperadoEfectivo = turno.montoInicial +
        ventasEfectivo +
        fiadosCobradosEfectivo +
        totalEntradasCaja -
        totalSalidasCaja;

    final double saldoNetoQr = (ventasQr + fiadosCobradosQr + totalEntradasQr) - totalRetirosQr;

    return ResumenCajaModel(
      turnoId: turnoId,
      estado: turno.estado,
      fechaApertura: turno.fechaApertura,
      montoInicial: turno.montoInicial,
      totalVentasEfectivo: ventasEfectivo,
      totalVentasQr: ventasQr,
      totalFiadosOtorgados: fiadosOtorgados,
      totalFiadosCobradosEfectivo: fiadosCobradosEfectivo,
      totalFiadosCobradosQr: fiadosCobradosQr,
      totalEntradasManuales: totalEntradasCaja,
      totalEntradasQr: totalEntradasQr,
      totalSalidasManuales: totalSalidasCaja,
      totalRetirosQr: totalRetirosQr,
      totalSalidasTienda: totalSalidasTienda,
      totalSalidasPersonal: totalSalidasPersonal,
      totalMercaderiaFutura: totalMercaderiaFutura,
      saldoNetoQr: (saldoNetoQr * 100).round() / 100.0,
      montoEsperadoEfectivo: (esperadoEfectivo * 100).round() / 100.0,
    );
  }

  /// Registra una entrada o salida manual (efectivo o QR)
  Future<MovimientoCajaModel> registrarMovimientoManual({
    required String tenantId,
    required String turnoId,
    required String tipo,
    required double monto,
    required String motivo,
    String origenDinero = 'EFECTIVO_CAJA',
    String categoria = 'GASTO_TIENDA',
  }) async {
    final db = await _db.database;
    final id = AppDatabase.nuevoId();
    final ahora = AppDatabase.ahora();

    final payload = {
      'id': id,
      'tenant_id': tenantId,
      'turno_id': turnoId,
      'tipo': tipo,
      'monto': monto,
      'motivo': motivo,
      'origen_dinero': origenDinero,
      'categoria': categoria,
      'created_at': ahora,
    };

    await db.insert('movimientos_caja', AppDatabase.aFila(payload));

    // Si se retira dinero de QR/Banco con fin de "CAMBIO_SENCILLO" para el cajón,
    // inyectamos automáticamente una entrada en efectivo a la caja
    if (origenDinero == 'BANCO_QR' && categoria == 'CAMBIO_SENCILLO' && tipo == 'SALIDA') {
      try {
        await db.insert('movimientos_caja', AppDatabase.aFila({
          'id': AppDatabase.nuevoId(),
          'tenant_id': tenantId,
          'turno_id': turnoId,
          'tipo': 'ENTRADA',
          'monto': monto,
          'motivo': 'Sencillo ingresado al cajón (Retiro de Banco QR)',
          'origen_dinero': 'EFECTIVO_CAJA',
          'categoria': 'CAMBIO_SENCILLO',
          'created_at': ahora,
        }));
      } catch (_) {}
    }

    return MovimientoCajaModel.fromMap(payload);
  }

  /// Lista los movimientos manuales registrados durante el turno
  Future<List<MovimientoCajaModel>> obtenerMovimientosTurno(String turnoId) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'movimientos_caja',
        where: 'turno_id = ?',
        whereArgs: [turnoId],
        orderBy: 'created_at DESC',
      );

      return rows
          .map((m) => MovimientoCajaModel.fromMap(AppDatabase.aMapa(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Cierra definitivamente el turno de caja congelando todos los totales
  Future<CajaTurnoModel> cerrarTurno({
    required String turnoId,
    required double montoContado,
    required ResumenCajaModel resumen,
    Map<String, int>? desglose,
    String? observaciones,
  }) async {
    final db = await _db.database;
    final double diferencia = ((montoContado - resumen.montoEsperadoEfectivo) * 100).round() / 100.0;
    final ahora = AppDatabase.ahora();

    final payload = {
      'fecha_cierre': ahora,
      'total_ventas_efectivo': resumen.totalVentasEfectivo,
      'total_ventas_qr': resumen.totalVentasQr,
      'total_fiados_otorgados': resumen.totalFiadosOtorgados,
      'total_fiados_cobrados_efectivo': resumen.totalFiadosCobradosEfectivo,
      'total_fiados_cobrados_qr': resumen.totalFiadosCobradosQr,
      'total_entradas_manuales': resumen.totalEntradasManuales,
      'total_salidas_manuales': resumen.totalSalidasManuales,
      'total_retiros_qr': resumen.totalRetirosQr,
      'total_salidas_tienda': resumen.totalSalidasTienda,
      'total_salidas_personal': resumen.totalSalidasPersonal,
      'saldo_neto_qr': resumen.saldoNetoQr,
      'monto_esperado_efectivo': resumen.montoEsperadoEfectivo,
      'monto_real_contado': montoContado,
      'diferencia': diferencia,
      'desglose_efectivo': desglose,
      if (observaciones != null && observaciones.trim().isNotEmpty)
        'observaciones_cierre': observaciones.trim(),
      'estado': 'CERRADA',
    };

    await db.update(
      'cajas_turnos',
      AppDatabase.aFila(payload),
      where: 'id = ?',
      whereArgs: [turnoId],
    );

    final rows = await db.query(
      'cajas_turnos',
      where: 'id = ?',
      whereArgs: [turnoId],
    );

    return CajaTurnoModel.fromMap(AppDatabase.aMapa(rows.first));
  }

  /// Obtiene los turnos históricos cerrados
  Future<List<CajaTurnoModel>> obtenerHistorialTurnos(
    String tenantId, {
    int limite = 20,
  }) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'cajas_turnos',
        where: 'tenant_id = ?',
        whereArgs: [tenantId],
        orderBy: 'fecha_apertura DESC',
        limit: limite,
      );

      return rows
          .map((m) => CajaTurnoModel.fromMap(AppDatabase.aMapa(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Obtiene el último turno cerrado
  Future<CajaTurnoModel?> obtenerUltimoTurnoCerrado(String tenantId) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'cajas_turnos',
        where: 'tenant_id = ? AND estado = ?',
        whereArgs: [tenantId, 'CERRADA'],
        orderBy: 'fecha_cierre DESC',
        limit: 1,
      );

      if (rows.isEmpty) return null;
      return CajaTurnoModel.fromMap(AppDatabase.aMapa(rows.first));
    } catch (_) {
      return null;
    }
  }

  /// Obtiene la lista completa de ventas registradas durante el turno activo con su desglose de pago (Efectivo/QR/Mixto/Fiado)
  Future<List<VentaTurnoModel>> obtenerVentasTurno(String turnoId, String tenantId) async {
    try {
      final db = await _db.database;

      final turnos = await db.query(
        'cajas_turnos',
        where: 'id = ? AND tenant_id = ?',
        whereArgs: [turnoId, tenantId],
      );

      if (turnos.isEmpty) return [];

      final turno = CajaTurnoModel.fromMap(AppDatabase.aMapa(turnos.first));
      final inicioJornadaTurno = obtenerInicioJornadaComercial(turno.fechaApertura);
      final fechaFiltro = turno.fechaApertura.isAfter(inicioJornadaTurno)
          ? inicioJornadaTurno.toIso8601String()
          : turno.fechaApertura.toIso8601String();

      final sql = '''
        SELECT 
          v.id,
          v.total_venta,
          v.metodo_pago,
          v.monto_recibido,
          v.cambio_entregado,
          v.fecha_venta,
          c.nombre as cliente_nombre
        FROM ventas v
        LEFT JOIN clientes c ON c.id = v.cliente_id
        WHERE (v.tenant_id = ? OR v.tenant_id IS NULL)
          AND (
            v.caja_turno_id = ?
            OR (
              (v.caja_turno_id IS NULL OR v.caja_turno_id = '' OR v.caja_turno_id NOT IN (SELECT id FROM cajas_turnos WHERE estado = 'CERRADA'))
              AND v.fecha_venta >= ?
            )
          )
        ORDER BY v.fecha_venta DESC
      ''';

      final rows = await db.rawQuery(sql, [tenantId, turnoId, fechaFiltro]);
      if (rows.isEmpty) return [];

      final List<VentaTurnoModel> lista = [];

      for (final r in rows) {
        final vId = r['id'] as String;
        final ticketCorto = vId.length > 8 ? vId.substring(0, 8) : vId;
        final totalVenta = (r['total_venta'] as num?)?.toDouble() ?? 0.0;
        final metodoPago = (r['metodo_pago'] as String? ?? 'EFECTIVO').toUpperCase();
        final fechaVenta = r['fecha_venta'] != null ? DateTime.parse(r['fecha_venta'] as String) : DateTime.now();
        final clienteNombre = r['cliente_nombre'] as String?;

        // Desglose de pagos exactos (Efectivo y QR)
        final pagosRows = await db.query(
          'pagos_ventas',
          where: 'venta_id = ?',
          whereArgs: [vId],
        );

        double efectivo = 0.0;
        double qr = 0.0;

        if (pagosRows.isNotEmpty) {
          for (final p in pagosRows) {
            final m = (p['metodo'] as String? ?? '').toUpperCase().trim();
            final val = (p['monto'] as num?)?.toDouble() ?? 0.0;
            if (m == 'EFECTIVO') efectivo += val;
            if (m == 'QR' || m == 'TRANSFERENCIA' || m == 'BANCO') qr += val;
          }
        } else {
          if (metodoPago == 'EFECTIVO') efectivo = totalVenta;
          if (metodoPago == 'QR' || metodoPago == 'TRANSFERENCIA' || metodoPago == 'BANCO') qr = totalVenta;
        }

        // Resumen de productos vendidos
        final detallesRows = await db.rawQuery('''
          SELECT dv.cantidad, p.nombre
          FROM detalle_ventas dv
          LEFT JOIN productos p ON p.id = dv.producto_id
          WHERE dv.venta_id = ?
        ''', [vId]);

        final items = detallesRows.map((d) {
          final cant = (d['cantidad'] as num?)?.toDouble() ?? 1.0;
          final nombre = d['nombre'] as String? ?? 'Producto';
          final cantStr = cant == cant.roundToDouble() ? cant.toInt().toString() : cant.toStringAsFixed(1);
          return '${cantStr}x $nombre';
        }).join(', ');

        lista.add(VentaTurnoModel(
          id: vId,
          ticketCorto: ticketCorto,
          totalVenta: totalVenta,
          metodoPago: metodoPago,
          montoRecibido: (r['monto_recibido'] as num?)?.toDouble() ?? 0.0,
          cambioEntregado: (r['cambio_entregado'] as num?)?.toDouble() ?? 0.0,
          fechaVenta: fechaVenta,
          clienteNombre: clienteNombre,
          itemsResumen: items.isNotEmpty ? items : 'Sin detalle',
          totalEfectivo: efectivo,
          totalQr: qr,
        ));
      }

      return lista;
    } catch (_) {
      return [];
    }
  }
}
