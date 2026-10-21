import 'package:sqflite_common/sqlite_api.dart';
import '../../../../core/database/app_database.dart';
import '../models/operadora_model.dart';
import '../models/recarga_model.dart';

class RecargasRepository {
  final AppDatabase _db;
  bool _tablasVerificadas = false;

  RecargasRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  /// Asegura que existan las 3 tablas del módulo y las 3 operadoras por defecto en SQLite
  Future<void> _asegurarTablas(Database db, String tenantId) async {
    if (_tablasVerificadas) return;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS operadoras_recargas (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        nombre TEXT NOT NULL,
        activa INTEGER NOT NULL DEFAULT 1,
        saldo_actual REAL NOT NULL DEFAULT 0.0,
        saldo_alerta_minimo REAL NOT NULL DEFAULT 20.0,
        comision_porcentaje REAL NOT NULL DEFAULT 10.0,
        color_hex TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recargas_ventas (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        operadora_id TEXT NOT NULL,
        tipo TEXT NOT NULL,
        monto REAL NOT NULL,
        costo_saldo REAL NOT NULL,
        ganancia_neta REAL NOT NULL,
        porcentaje_comision REAL NOT NULL,
        metodo_pago TEXT NOT NULL,
        numero_telefono TEXT,
        caja_turno_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recargas_bolsas_recargas (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        operadora_id TEXT NOT NULL,
        saldo_cargado REAL NOT NULL,
        dinero_pagado REAL NOT NULL,
        origen_pago TEXT NOT NULL,
        caja_turno_id TEXT,
        observaciones TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Sembrar las 3 operadoras de Bolivia si la tabla está vacía para esta tienda
    final countRes = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM operadoras_recargas WHERE tenant_id = ?',
      [tenantId],
    );
    final count = (countRes.first['total'] as num?)?.toInt() ?? 0;

    if (count == 0) {
      final ahora = DateTime.now().toIso8601String();
      final operadorasIniciales = [
        {
          'id': 'ENTEL',
          'tenant_id': tenantId,
          'nombre': 'Entel',
          'activa': 1,
          'saldo_actual': 0.0,
          'saldo_alerta_minimo': 20.0,
          'comision_porcentaje': 10.0,
          'color_hex': '#005CA9', // Azul corporativo Entel
          'updated_at': ahora,
        },
        {
          'id': 'TIGO',
          'tenant_id': tenantId,
          'nombre': 'Tigo',
          'activa': 1,
          'saldo_actual': 0.0,
          'saldo_alerta_minimo': 20.0,
          'comision_porcentaje': 10.0,
          'color_hex': '#00377B', // Azul marino corporativo Tigo
          'updated_at': ahora,
        },
        {
          'id': 'VIVA',
          'tenant_id': tenantId,
          'nombre': 'Viva',
          'activa': 1,
          'saldo_actual': 0.0,
          'saldo_alerta_minimo': 20.0,
          'comision_porcentaje': 10.0,
          'color_hex': '#7DB637', // Verde corporativo Viva
          'updated_at': ahora,
        },
      ];

      for (final op in operadorasIniciales) {
        await db.insert('operadoras_recargas', op);
      }
    }

    _tablasVerificadas = true;
  }

  /// Obtiene la lista de operadoras configuradas en la tienda
  Future<List<OperadoraModel>> obtenerOperadoras(String tenantId) async {
    final db = await _db.database;
    await _asegurarTablas(db, tenantId);

    final rows = await db.query(
      'operadoras_recargas',
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
      orderBy: 'nombre ASC',
    );

    return rows.map((r) => OperadoraModel.fromMap(AppDatabase.aMapa(r))).toList();
  }

  /// Actualiza configuración de una operadora (activar/desactivar, comisión, umbral mínimo)
  Future<void> actualizarOperadora(OperadoraModel operadora) async {
    final db = await _db.database;
    await _asegurarTablas(db, operadora.tenantId);

    await db.update(
      'operadoras_recargas',
      operadora.toMap(),
      where: 'id = ? AND tenant_id = ?',
      whereArgs: [operadora.id, operadora.tenantId],
    );
  }

  /// Registra la venta de una recarga a un vecino en SQLite
  /// 1. Inserta la venta con su cálculo exacto de ganancia neta.
  /// 2. Descuenta el saldo de la bolsa del chip.
  /// 3. Si hay turno de caja activo, inserta automáticamente el movimiento de entrada en caja/QR
  ///    para que el arqueo de efectivo físico cuadre a la perfección.
  Future<RecargaModel> registrarVentaRecarga({
    required String tenantId,
    required OperadoraModel operadora,
    required TipoRecarga tipo,
    required double monto,
    required MetodoPagoRecarga metodoPago,
    String? numeroTelefono,
    String? cajaTurnoId,
  }) async {
    final db = await _db.database;
    await _asegurarTablas(db, tenantId);

    final ahora = DateTime.now();
    final recargaId = AppDatabase.nuevoId();

    // Costo del saldo y ganancia neta según la comisión pactada
    final porcentajeComision = operadora.comisionPorcentaje;
    final costoSaldo = monto * (1.0 - (porcentajeComision / 100.0));
    final gananciaNeta = monto - costoSaldo;

    final recarga = RecargaModel(
      id: recargaId,
      tenantId: tenantId,
      operadoraId: operadora.id,
      operadoraNombre: operadora.nombre,
      tipo: tipo,
      monto: monto,
      costoSaldo: costoSaldo,
      gananciaNeta: gananciaNeta,
      porcentajeComision: porcentajeComision,
      metodoPago: metodoPago,
      numeroTelefono: numeroTelefono?.trim().isEmpty == true ? null : numeroTelefono?.trim(),
      cajaTurnoId: cajaTurnoId,
      createdAt: ahora,
    );

    await db.transaction((txn) async {
      // 1. Guardar la recarga
      await txn.insert('recargas_ventas', recarga.toMap());

      // 2. Descontar saldo de la operadora
      final nuevoSaldo = (operadora.saldoActual - monto);
      await txn.update(
        'operadoras_recargas',
        {
          'saldo_actual': nuevoSaldo,
          'updated_at': ahora.toIso8601String(),
        },
        where: 'id = ? AND tenant_id = ?',
        whereArgs: [operadora.id, tenantId],
      );

      // 3. Registrar entrada de dinero en Caja para arqueo transparente
      if (cajaTurnoId != null && cajaTurnoId.isNotEmpty) {
        final origenDinero = metodoPago == MetodoPagoRecarga.efectivo ? 'EFECTIVO_CAJA' : 'BANCO_QR';
        final tipoLabel = tipo == TipoRecarga.credito ? 'Crédito' : 'Paquete Internet';
        final telLabel = numeroTelefono != null && numeroTelefono.isNotEmpty ? ' a $numeroTelefono' : '';

        await txn.insert('movimientos_caja', {
          'id': AppDatabase.nuevoId(),
          'tenant_id': tenantId,
          'turno_id': cajaTurnoId,
          'tipo': 'ENTRADA',
          'monto': monto,
          'motivo': 'Recarga ${operadora.nombre} $tipoLabel (Bs. ${monto.toStringAsFixed(2)})$telLabel',
          'origen_dinero': origenDinero,
          'categoria': 'RECARGA',
          'created_at': ahora.toIso8601String(),
        });
      }
    });

    return recarga;
  }

  /// Registra la compra de saldo mayorista para recargar el chip de la tienda
  Future<BolsaRecargaModel> recargarBolsaSaldo({
    required String tenantId,
    required OperadoraModel operadora,
    required double saldoCargado,
    required double dineroPagado,
    required String origenPago, // 'EFECTIVO_CAJA' o 'BANCO_QR_EXTERNO'
    String? cajaTurnoId,
    String? observaciones,
  }) async {
    final db = await _db.database;
    await _asegurarTablas(db, tenantId);

    final ahora = DateTime.now();
    final id = AppDatabase.nuevoId();

    final bolsaRecarga = BolsaRecargaModel(
      id: id,
      tenantId: tenantId,
      operadoraId: operadora.id,
      saldoCargado: saldoCargado,
      dineroPagado: dineroPagado,
      origenPago: origenPago,
      cajaTurnoId: cajaTurnoId,
      observaciones: observaciones,
      createdAt: ahora,
    );

    await db.transaction((txn) async {
      // 1. Guardar movimiento de bolsa
      await txn.insert('recargas_bolsas_recargas', bolsaRecarga.toMap());

      // 2. Incrementar saldo disponible de la operadora
      final nuevoSaldo = operadora.saldoActual + saldoCargado;
      await txn.update(
        'operadoras_recargas',
        {
          'saldo_actual': nuevoSaldo,
          'updated_at': ahora.toIso8601String(),
        },
        where: 'id = ? AND tenant_id = ?',
        whereArgs: [operadora.id, tenantId],
      );

      // 3. Si se pagó con dinero del cajón físico de la tienda, registrar la salida
      if (cajaTurnoId != null && cajaTurnoId.isNotEmpty && origenPago == 'EFECTIVO_CAJA') {
        await txn.insert('movimientos_caja', {
          'id': AppDatabase.nuevoId(),
          'tenant_id': tenantId,
          'turno_id': cajaTurnoId,
          'tipo': 'SALIDA',
          'monto': dineroPagado,
          'motivo': 'Compra de saldo mayorista ${operadora.nombre} (Bolsa Bs. ${saldoCargado.toStringAsFixed(0)})',
          'origen_dinero': 'EFECTIVO_CAJA',
          'categoria': 'GASTO_TIENDA',
          'created_at': ahora.toIso8601String(),
        });
      }
    });

    return bolsaRecarga;
  }

  /// Obtiene las ventas de recargas realizadas en un turno específico (o el día de hoy)
  Future<List<RecargaModel>> obtenerVentasTurno(String tenantId, String? turnoId) async {
    final db = await _db.database;
    await _asegurarTablas(db, tenantId);

    List<Map<String, Object?>> rows;

    if (turnoId != null && turnoId.isNotEmpty) {
      rows = await db.rawQuery('''
        SELECT rv.*, op.nombre AS operadora_nombre
        FROM recargas_ventas rv
        LEFT JOIN operadoras_recargas op ON rv.operadora_id = op.id AND rv.tenant_id = op.tenant_id
        WHERE rv.tenant_id = ? AND rv.caja_turno_id = ?
        ORDER BY rv.created_at DESC
      ''', [tenantId, turnoId]);
    } else {
      // Sin turno: últimos 2 días por defecto
      final hace2Dias = DateTime.now().subtract(const Duration(days: 2)).toIso8601String();
      rows = await db.rawQuery('''
        SELECT rv.*, op.nombre AS operadora_nombre
        FROM recargas_ventas rv
        LEFT JOIN operadoras_recargas op ON rv.operadora_id = op.id AND rv.tenant_id = op.tenant_id
        WHERE rv.tenant_id = ? AND rv.created_at >= ?
        ORDER BY rv.created_at DESC
      ''', [tenantId, hace2Dias]);
    }

    return rows.map((r) => RecargaModel.fromMap(AppDatabase.aMapa(r))).toList();
  }

  /// Calcula el resumen consolidado de recargas en el turno (total vendido y ganancia neta)
  Future<Map<String, dynamic>> obtenerResumenRecargasTurno(String tenantId, String? turnoId) async {
    final db = await _db.database;
    await _asegurarTablas(db, tenantId);

    String whereClause;
    List<dynamic> args;

    if (turnoId != null && turnoId.isNotEmpty) {
      whereClause = 'tenant_id = ? AND caja_turno_id = ?';
      args = [tenantId, turnoId];
    } else {
      final inicioDia = DateTime.now().toIso8601String().substring(0, 10);
      whereClause = 'tenant_id = ? AND created_at >= ?';
      args = [tenantId, inicioDia];
    }

    final sql = '''
      SELECT 
        COALESCE(SUM(monto), 0) AS total_monto,
        COALESCE(SUM(ganancia_neta), 0) AS total_ganancia,
        COALESCE(SUM(CASE WHEN metodo_pago = 'EFECTIVO' THEN monto ELSE 0 END), 0) AS total_efectivo,
        COALESCE(SUM(CASE WHEN metodo_pago = 'QR' THEN monto ELSE 0 END), 0) AS total_qr,
        COUNT(*) AS cantidad
      FROM recargas_ventas
      WHERE $whereClause
    ''';

    final res = await db.rawQuery(sql, args);
    if (res.isEmpty) {
      return {
        'total_monto': 0.0,
        'total_ganancia': 0.0,
        'total_efectivo': 0.0,
        'total_qr': 0.0,
        'cantidad': 0,
      };
    }

    final row = res.first;
    return {
      'total_monto': (row['total_monto'] as num?)?.toDouble() ?? 0.0,
      'total_ganancia': (row['total_ganancia'] as num?)?.toDouble() ?? 0.0,
      'total_efectivo': (row['total_efectivo'] as num?)?.toDouble() ?? 0.0,
      'total_qr': (row['total_qr'] as num?)?.toDouble() ?? 0.0,
      'cantidad': (row['cantidad'] as num?)?.toInt() ?? 0,
    };
  }

  /// Anula una recarga registrada por error y restaura el saldo y el movimiento de caja
  Future<void> anularVentaRecarga(String recargaId, String tenantId) async {
    final db = await _db.database;
    await _asegurarTablas(db, tenantId);

    final rows = await db.query(
      'recargas_ventas',
      where: 'id = ? AND tenant_id = ?',
      whereArgs: [recargaId, tenantId],
      limit: 1,
    );

    if (rows.isEmpty) return;
    final r = rows.first;
    final opId = r['operadora_id'] as String;
    final monto = (r['monto'] as num).toDouble();
    final turnoId = r['caja_turno_id'] as String?;

    await db.transaction((txn) async {
      // 1. Devolver saldo a la operadora
      await txn.rawUpdate('''
        UPDATE operadoras_recargas 
        SET saldo_actual = saldo_actual + ?, updated_at = ?
        WHERE id = ? AND tenant_id = ?
      ''', [monto, DateTime.now().toIso8601String(), opId, tenantId]);

      // 2. Si tenía movimiento en caja, registrar salida de corrección
      if (turnoId != null && turnoId.isNotEmpty) {
        await txn.insert('movimientos_caja', {
          'id': AppDatabase.nuevoId(),
          'tenant_id': tenantId,
          'turno_id': turnoId,
          'tipo': 'SALIDA',
          'monto': monto,
          'motivo': 'Anulación de recarga $opId por error de registro',
          'origen_dinero': r['metodo_pago'] == 'EFECTIVO' ? 'EFECTIVO_CAJA' : 'BANCO_QR',
          'categoria': 'OTRO',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // 3. Eliminar la recarga
      await txn.delete(
        'recargas_ventas',
        where: 'id = ? AND tenant_id = ?',
        whereArgs: [recargaId, tenantId],
      );
    });
  }
}
