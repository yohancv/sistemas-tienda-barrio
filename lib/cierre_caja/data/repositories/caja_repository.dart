import '../../../../core/database/app_database.dart';
import '../models/caja_turno_model.dart';
import '../models/movimiento_caja_model.dart';
import '../models/resumen_caja_model.dart';

class CajaRepository {
  final AppDatabase _db;

  CajaRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  /// Obtiene el turno de caja abierto actualmente para el tenant
  Future<CajaTurnoModel?> obtenerTurnoActivo(String tenantId) async {
    try {
      final db = await _db.database;
      final rows = await db.query(
        'cajas_turnos',
        where: 'tenant_id = ? AND estado = "ABIERTA"',
        whereArgs: [tenantId],
        orderBy: 'fecha_apertura DESC',
        limit: 1,
      );

      if (rows.isEmpty) return null;
      return CajaTurnoModel.fromMap(AppDatabase.aMapa(rows.first));
    } catch (_) {
      return null;
    }
  }

  /// Asegura que siempre exista un turno de caja activo (Modo Dueño / Caja Continua).
  /// Si no hay un turno abierto, crea uno automáticamente con fondo inicial 0.0 Bs.
  Future<CajaTurnoModel> asegurarTurnoActivo({
    required String tenantId,
    double montoInicial = 0.0,
    String? usuarioId,
  }) async {
    final turnoExistente = await obtenerTurnoActivo(tenantId);
    if (turnoExistente != null) return turnoExistente;

    return await abrirTurno(
      tenantId: tenantId,
      montoInicial: montoInicial,
      usuarioId: usuarioId ?? 'DUEÑO',
    );
  }

  /// Inicia un nuevo turno de caja con el fondo inicial en Bs.
  Future<CajaTurnoModel> abrirTurno({
    required String tenantId,
    required double montoInicial,
    String? usuarioId,
  }) async {
    final turnoExistente = await obtenerTurnoActivo(tenantId);
    if (turnoExistente != null) {
      throw Exception('Ya existe un turno de caja abierto iniciado el ${turnoExistente.fechaApertura}');
    }

    final db = await _db.database;
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
      'usuario_id': ?usuarioId,
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
    final fechaInicio = turno.fechaApertura.toIso8601String();
    final fechaFin = (turno.fechaCierre ?? DateTime.now()).toIso8601String();

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

    // 2. Ventas Efectivo y QR
    final sqlPagos = '''
      SELECT pv.metodo, SUM(pv.monto) as total
      FROM pagos_ventas pv
      JOIN ventas v ON v.id = pv.venta_id
      WHERE pv.tenant_id = ?
        AND (v.caja_turno_id = ? OR (v.caja_turno_id IS NULL AND v.fecha_venta >= ? AND v.fecha_venta <= ?))
      GROUP BY pv.metodo
    ''';

    final pagosRes = await db.rawQuery(sqlPagos, [tenantId, turnoId, fechaInicio, fechaFin]);
    double ventasEfectivo = 0.0;
    double ventasQr = 0.0;

    for (final r in pagosRes) {
      final metodo = r['metodo'] as String?;
      final total = (r['total'] as num?)?.toDouble() ?? 0.0;
      if (metodo == 'EFECTIVO') ventasEfectivo = total;
      if (metodo == 'QR') ventasQr = total;
    }

    // 3. Fiados Otorgados
    final sqlFiados = '''
      SELECT COALESCE(SUM(total_venta), 0) as total
      FROM ventas
      WHERE tenant_id = ?
        AND metodo_pago = 'CREDITO_FIADO'
        AND (caja_turno_id = ? OR (caja_turno_id IS NULL AND fecha_venta >= ? AND fecha_venta <= ?))
    ''';
    final fiadosRes = await db.rawQuery(sqlFiados, [tenantId, turnoId, fechaInicio, fechaFin]);
    final double fiadosOtorgados = (fiadosRes.first['total'] as num?)?.toDouble() ?? 0.0;

    // 4. Fiados Cobrados (Abonos)
    final sqlAbonos = '''
      SELECT metodo_pago, COALESCE(SUM(monto), 0) as total
      FROM abonos_deuda
      WHERE tenant_id = ?
        AND (caja_turno_id = ? OR (caja_turno_id IS NULL AND fecha_abono >= ? AND fecha_abono <= ?))
      GROUP BY metodo_pago
    ''';
    final abonosRes = await db.rawQuery(sqlAbonos, [tenantId, turnoId, fechaInicio, fechaFin]);
    double fiadosCobradosEfectivo = 0.0;
    double fiadosCobradosQr = 0.0;

    for (final r in abonosRes) {
      final metodo = r['metodo_pago'] as String?;
      final total = (r['total'] as num?)?.toDouble() ?? 0.0;
      if (metodo == 'EFECTIVO') fiadosCobradosEfectivo += total;
      if (metodo == 'QR' || metodo == 'TRANSFERENCIA') fiadosCobradosQr += total;
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
        where: 'tenant_id = ? AND estado = "CERRADA"',
        whereArgs: [tenantId],
        orderBy: 'fecha_cierre DESC',
        limit: 1,
      );

      if (rows.isEmpty) return null;
      return CajaTurnoModel.fromMap(AppDatabase.aMapa(rows.first));
    } catch (_) {
      return null;
    }
  }
}
