import '../../../../core/database/app_database.dart';
import '../models/abono_model.dart';
import '../models/cliente_model.dart';

class ClientesRepository {
  final AppDatabase _db;

  ClientesRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  /// Obtiene todos los clientes activos ordenados prioritariamente por los que tienen mayor deuda
  Future<List<Cliente>> obtenerClientes(String tenantId) async {
    final db = await _db.database;
    final rows = await db.query(
      'clientes',
      where: 'tenant_id = ? AND activo = 1',
      whereArgs: [tenantId],
      orderBy: 'saldo_actual DESC, nombre ASC',
    );

    return rows
        .map((item) => Cliente.fromMap(AppDatabase.aMapa(item)))
        .toList();
  }

  /// Busca clientes activos por coincidencia en nombre o teléfono
  Future<List<Cliente>> buscarClientes(String tenantId, String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return obtenerClientes(tenantId);
    }

    final db = await _db.database;
    final wildcard = '%$cleanQuery%';
    final rows = await db.query(
      'clientes',
      where: 'tenant_id = ? AND activo = 1 AND (nombre LIKE ? OR telefono LIKE ?)',
      whereArgs: [tenantId, wildcard, wildcard],
      orderBy: 'saldo_actual DESC, nombre ASC',
    );

    return rows
        .map((item) => Cliente.fromMap(AppDatabase.aMapa(item)))
        .toList();
  }

  /// Registra un nuevo cliente/vecino en el sistema
  Future<Cliente> crearCliente(Cliente cliente) async {
    final db = await _db.database;
    final id = cliente.id.isNotEmpty ? cliente.id : AppDatabase.nuevoId();
    final ahora = AppDatabase.ahora();

    final nuevoCliente = cliente.copyWith(
      id: id,
      createdAt: cliente.createdAt,
      updatedAt: DateTime.parse(ahora),
    );

    final fila = AppDatabase.aFila(nuevoCliente.toMap());
    await db.insert('clientes', fila);

    return nuevoCliente;
  }

  /// Ejecuta un abono a deuda de forma atómica.
  /// El trigger de SQLite `trg_saldo_cliente_por_abono` actualiza automáticamente el saldo.
  Future<Map<String, dynamic>> registrarAbono({
    required String clienteId,
    required double monto,
    String metodoPago = 'EFECTIVO',
    String? notas,
    required String tenantId,
    String? cajaTurnoId,
  }) async {
    if (monto <= 0) {
      throw Exception('El monto del abono debe ser mayor a 0');
    }

    final db = await _db.database;

    return await db.transaction<Map<String, dynamic>>((txn) async {
      final clientes = await txn.query(
        'clientes',
        where: 'id = ? AND tenant_id = ?',
        whereArgs: [clienteId, tenantId],
      );

      if (clientes.isEmpty) {
        throw Exception('Cliente no encontrado');
      }

      final cliente = clientes.first;
      final saldoAnterior = (cliente['saldo_actual'] as num).toDouble();
      final nombreCliente = cliente['nombre'] as String? ?? '';
      final abonoId = AppDatabase.nuevoId();
      final ahora = AppDatabase.ahora();

      // Insertar abono: el trigger trg_saldo_cliente_por_abono descuenta el saldo del cliente
      await txn.insert('abonos_deuda', AppDatabase.aFila({
        'id': abonoId,
        'tenant_id': tenantId,
        'cliente_id': clienteId,
        'monto': monto,
        'metodo_pago': metodoPago,
        'notas': notas,
        'fecha_abono': ahora,
        'caja_turno_id': cajaTurnoId,
      }));

      // Re-consultar cliente para obtener el nuevo saldo exacto
      final clientesActualizados = await txn.query(
        'clientes',
        where: 'id = ?',
        whereArgs: [clienteId],
      );

      final nuevoSaldo = (clientesActualizados.first['saldo_actual'] as num).toDouble();

      return {
        'success': true,
        'abono_id': abonoId,
        'cliente_id': clienteId,
        'nombre_cliente': nombreCliente,
        'monto_abonado': monto,
        'saldo_anterior': saldoAnterior,
        'nuevo_saldo': nuevoSaldo,
      };
    });
  }

  /// Obtiene los abonos realizados por un cliente específico
  Future<List<AbonoDeuda>> obtenerHistorialAbonos(
    String clienteId, {
    int limite = 30,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      'abonos_deuda',
      where: 'cliente_id = ?',
      whereArgs: [clienteId],
      orderBy: 'fecha_abono DESC',
      limit: limite,
    );

    return rows
        .map((item) => AbonoDeuda.fromMap(AppDatabase.aMapa(item)))
        .toList();
  }

  /// Obtiene las ventas sacadas a fiado por este cliente
  Future<List<Map<String, dynamic>>> obtenerVentasFiadas(
    String clienteId, {
    int limite = 30,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      'ventas',
      where: 'cliente_id = ? AND metodo_pago = "CREDITO_FIADO"',
      whereArgs: [clienteId],
      orderBy: 'fecha_venta DESC',
      limit: limite,
    );

    return rows.map((r) => AppDatabase.aMapa(r)).toList();
  }

  /// Obtiene los últimos movimientos combinados (ventas fiadas y abonos) para mostrar en la tarjeta de fiados
  Future<List<Map<String, dynamic>>> obtenerMovimientosCliente(String clienteId, {int limite = 5}) async {
    final db = await _db.database;

    final sql = '''
      SELECT 
        'ABONO' AS tipo,
        id,
        monto,
        metodo_pago AS detalle,
        fecha_abono AS fecha
      FROM abonos_deuda
      WHERE cliente_id = ?
      UNION ALL
      SELECT 
        'FIADO' AS tipo,
        id,
        total_venta AS monto,
        metodo_pago AS detalle,
        fecha_venta AS fecha
      FROM ventas
      WHERE cliente_id = ? AND metodo_pago = 'CREDITO_FIADO'
      ORDER BY fecha DESC
      LIMIT $limite
    ''';

    final rows = await db.rawQuery(sql, [clienteId, clienteId]);
    return rows.map((r) => AppDatabase.aMapa(r)).toList();
  }
}
