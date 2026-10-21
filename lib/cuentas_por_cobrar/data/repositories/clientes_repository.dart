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

  /// Obtiene un cliente específico por su ID
  Future<Cliente?> obtenerClientePorId(String clienteId) async {
    final db = await _db.database;
    final rows = await db.query(
      'clientes',
      where: 'id = ?',
      whereArgs: [clienteId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Cliente.fromMap(AppDatabase.aMapa(rows.first));
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

  /// Actualiza los datos de un cliente existente (límite de fiado, nombre, teléfono, notas)
  Future<Cliente> actualizarCliente({
    required String clienteId,
    required String tenantId,
    String? nombre,
    String? telefono,
    double? limiteCredito,
    String? notas,
  }) async {
    final db = await _db.database;
    final ahora = AppDatabase.ahora();
    final campos = <String, dynamic>{
      'updated_at': ahora,
    };
    if (nombre != null) campos['nombre'] = nombre.trim();
    if (telefono != null) campos['telefono'] = telefono.trim();
    if (limiteCredito != null) campos['limite_credito'] = limiteCredito;
    if (notas != null) campos['notas'] = notas.trim();

    await db.update(
      'clientes',
      AppDatabase.aFila(campos),
      where: 'id = ? AND tenant_id = ?',
      whereArgs: [clienteId, tenantId],
    );

    final actualizado = await obtenerClientePorId(clienteId);
    if (actualizado == null) throw Exception('Cliente no encontrado tras actualizar');
    return actualizado;
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
      if (monto > saldoAnterior + 0.001) {
        throw Exception(
          'El abono (Bs. ${monto.toStringAsFixed(2)}) no puede exceder la deuda pendiente (Bs. ${saldoAnterior.toStringAsFixed(2)}).',
        );
      }
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
      where: 'cliente_id = ? AND (metodo_pago = ? OR metodo_pago = ?)',
      whereArgs: [clienteId, 'CREDITO_FIADO', 'FIADO'],
      orderBy: 'fecha_venta DESC',
      limit: limite,
    );

    return rows.map((r) => AppDatabase.aMapa(r)).toList();
  }

  /// Obtiene los últimos movimientos combinados (ventas fiadas y abonos) para mostrar en la tarjeta de fiados y en el historial completo
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
      WHERE cliente_id = ? AND (metodo_pago = 'CREDITO_FIADO' OR metodo_pago = 'FIADO')
      ORDER BY fecha DESC
      LIMIT $limite
    ''';

    final rows = await db.rawQuery(sql, [clienteId, clienteId]);
    final List<Map<String, dynamic>> resultado = [];

    for (final r in rows) {
      final mapa = AppDatabase.aMapa(r);
      if (mapa['tipo'] == 'FIADO') {
        final ventaId = mapa['id'] as String;
        try {
          final detalles = await db.rawQuery('''
            SELECT 
              dv.cantidad,
              COALESCE(p.nombre, 'Producto') AS nombre,
              COALESCE(p.tipo_unidad, 'UNIDAD') AS tipo_unidad,
              p.unidad_medida
            FROM detalle_ventas dv
            LEFT JOIN productos p ON dv.producto_id = p.id
            WHERE dv.venta_id = ?
          ''', [ventaId]);

          if (detalles.isNotEmpty) {
            final articulos = detalles.map((d) {
              final cant = d['cantidad'];
              final cantNum = cant is num ? cant.toDouble() : (double.tryParse(cant.toString()) ?? 1.0);
              final cantStr = (cantNum % 1 == 0) ? cantNum.toInt().toString() : cantNum.toStringAsFixed(1);
              final tipo = (d['tipo_unidad']?.toString() ?? 'UNIDAD').toUpperCase();
              final unidadMedida = d['unidad_medida']?.toString().trim();
              final String prefijo;
              if (tipo == 'KILO' || tipo == 'GRANEL' || tipo == 'FRACCIONABLE') {
                final u = (unidadMedida != null && unidadMedida.isNotEmpty) ? unidadMedida : 'kg';
                prefijo = '$cantStr $u';
              } else if (unidadMedida != null && unidadMedida.isNotEmpty && unidadMedida.toLowerCase() != 'unidad') {
                prefijo = '$cantStr $unidadMedida';
              } else {
                prefijo = cantStr;
              }
              final nombre = d['nombre']?.toString() ?? 'Producto';
              return '$prefijo $nombre';
            }).join(', ');

            mapa['productos_resumen'] = articulos;
            mapa['detalles_items'] = detalles;
          }
        } catch (_) {}
      }
      resultado.add(mapa);
    }

    return resultado;
  }

  /// Obtiene la fecha del último movimiento registrado (venta fiada o abono) para calcular antigüedad
  Future<DateTime?> obtenerFechaUltimoMovimiento(String clienteId) async {
    final db = await _db.database;
    final sql = '''
      SELECT fecha_abono AS fecha FROM abonos_deuda WHERE cliente_id = ?
      UNION ALL
      SELECT fecha_venta AS fecha FROM ventas WHERE cliente_id = ? AND (metodo_pago = 'CREDITO_FIADO' OR metodo_pago = 'FIADO')
      ORDER BY fecha DESC
      LIMIT 1
    ''';
    final rows = await db.rawQuery(sql, [clienteId, clienteId]);
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['fecha'] as String? ?? '');
  }

  /// Obtiene las ventas fiadas recientes con el detalle de sus productos para el ticket de WhatsApp
  Future<List<Map<String, dynamic>>> obtenerDetalleProductosFiados(
    String clienteId, {
    int limiteVentas = 4,
  }) async {
    final db = await _db.database;

    final ventas = await db.query(
      'ventas',
      where: 'cliente_id = ? AND (metodo_pago = ? OR metodo_pago = ?)',
      whereArgs: [clienteId, 'CREDITO_FIADO', 'FIADO'],
      orderBy: 'fecha_venta DESC',
      limit: limiteVentas,
    );

    if (ventas.isEmpty) return [];

    final List<Map<String, dynamic>> resultado = [];

    for (final v in ventas) {
      final ventaId = v['id'] as String;
      final fechaVentaStr = v['fecha_venta'] as String;
      final totalVenta = (v['total_venta'] as num?)?.toDouble() ?? 0.0;

      final detalles = await db.rawQuery('''
        SELECT 
          dv.cantidad,
          COALESCE(p.nombre, 'Producto') AS nombre,
          COALESCE(p.tipo_unidad, 'UNIDAD') AS tipo_unidad,
          dv.subtotal
        FROM detalle_ventas dv
        LEFT JOIN productos p ON dv.producto_id = p.id
        WHERE dv.venta_id = ?
      ''', [ventaId]);

      final List<Map<String, dynamic>> items = detalles.map((d) {
        final cant = d['cantidad'];
        final sub = d['subtotal'];
        return {
          'cantidad': cant is num ? cant.toDouble() : (double.tryParse(cant.toString()) ?? 1.0),
          'nombre': d['nombre']?.toString() ?? 'Producto',
          'tipo_unidad': d['tipo_unidad']?.toString() ?? 'UNIDAD',
          'subtotal': sub is num ? sub.toDouble() : (double.tryParse(sub.toString()) ?? 0.0),
        };
      }).toList();

      resultado.add({
        'venta_id': ventaId,
        'fecha': fechaVentaStr,
        'total': totalVenta,
        'items': items,
      });
    }

    return resultado;
  }
}
