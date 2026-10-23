import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'package:si_tienda_barrio/core/config/supabase_client.dart';
import 'package:si_tienda_barrio/core/database/app_database.dart';
import 'package:si_tienda_barrio/cierre_caja/data/repositories/caja_repository.dart';
import 'package:si_tienda_barrio/cuentas_por_cobrar/data/repositories/clientes_repository.dart';
import 'package:si_tienda_barrio/punto_de_venta/data/repositories/venta_repository.dart';
import 'package:si_tienda_barrio/punto_de_venta/data/models/venta_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  sqflite.databaseFactory = databaseFactoryFfi;

  const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    return '.';
  });

  setUpAll(() async {
    final dbPath = await sqflite.getDatabasesPath();
    try {
      await sqflite.deleteDatabase('$dbPath/tienda_barrio.db');
    } catch (_) {}
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    try {
      final db = await AppDatabase.instance.database;
      await db.close();
      final dbPath = await sqflite.getDatabasesPath();
      await sqflite.deleteDatabase('$dbPath/tienda_barrio.db');
    } catch (_) {}
  });

  test('Rebaja Casera y Fiado Parcial con preservación íntegra de productos en historial', () async {
    final db = await AppDatabase.instance.database;
    final tenantId = SupabaseConfig.defaultTenantId;

    final cajaRepo = CajaRepository();
    final ventaRepo = VentaRepository();
    final clientesRepo = ClientesRepository();

    // 1. Abrir Turno de Caja con Fondo de 100 Bs
    final turno = await cajaRepo.abrirTurno(
      tenantId: tenantId,
      montoInicial: 100.0,
      usuarioId: 'DUEÑO',
    );

    // 2. Crear Cliente para fiado
    final clienteId = 'cliente-vecina-juana';
    await db.insert('clientes', {
      'id': clienteId,
      'tenant_id': tenantId,
      'nombre': 'Doña Juana Casera',
      'telefono': '70012345',
      'limite_credito': 300.0,
      'saldo_actual': 0.0,
      'activo': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);

    // 3. Crear Productos de prueba en inventario
    await db.insert('productos', {
      'id': 'prod-arroz-5k',
      'tenant_id': tenantId,
      'nombre': 'Arroz Grano de Oro 5kg',
      'codigo_barras': '7770001',
      'precio_venta': 40.0,
      'costo_mayorista': 30.0,
      'stock_actual': 20.0,
      'stock_minimo': 2.0,
      'estado_activo': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);

    await db.insert('productos', {
      'id': 'prod-aceite-1l',
      'tenant_id': tenantId,
      'nombre': 'Aceite Fino 1L',
      'codigo_barras': '7770002',
      'precio_venta': 13.0,
      'costo_mayorista': 9.0,
      'stock_actual': 15.0,
      'stock_minimo': 2.0,
      'estado_activo': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);

    // =========================================================================
    // PRUEBA A: Venta con Rebaja / Descuento Casera (De Bs. 53 a Bs. 50)
    // =========================================================================
    // Subtotal original = 40 + 13 = 53 Bs.
    // Acordado con casera = 50 Bs (Rebaja de 3 Bs).
    final subtotalOriginal = 53.0;
    final totalAcordadoRebaja = 50.0;
    final factorRebaja = totalAcordadoRebaja / subtotalOriginal;

    final detallesVentaRebaja = [
      DetalleVenta(
        productoId: 'prod-arroz-5k',
        cantidad: 1.0,
        precioUnitario: ((40.0 * factorRebaja) * 100).round() / 100.0,
        costoUnitario: 30.0,
        subtotal: ((40.0 * factorRebaja) * 100).round() / 100.0,
      ),
      DetalleVenta(
        productoId: 'prod-aceite-1l',
        cantidad: 1.0,
        precioUnitario: ((13.0 * factorRebaja) * 100).round() / 100.0,
        costoUnitario: 9.0,
        subtotal: ((13.0 * factorRebaja) * 100).round() / 100.0,
      ),
    ];

    // Pago en efectivo con billete de 100 Bs -> Vuelto 50 Bs
    final ventaRebaja = Venta(
      tenantId: tenantId,
      cajaTurnoId: turno.id,
      totalVenta: totalAcordadoRebaja,
      metodoPago: 'EFECTIVO',
      montoRecibido: 100.0,
      cambioEntregado: 50.0,
      fechaVenta: DateTime.now(),
    );

    final pagosRebaja = [
      PagoVenta(
        tenantId: tenantId,
        metodo: 'EFECTIVO',
        monto: totalAcordadoRebaja,
        createdAt: DateTime.now(),
      ),
    ];

    await ventaRepo.registrarTransaccionCompleta(
      venta: ventaRebaja,
      detalles: detallesVentaRebaja,
      pagos: pagosRebaja,
    );

    var resumen = await cajaRepo.obtenerResumenTurno(turno.id, tenantId);
    expect(resumen.totalVentasEfectivo, 50.0);
    expect(resumen.montoEsperadoEfectivo, 150.0); // 100 inicial + 50 venta

    // =========================================================================
    // PRUEBA B: Fiado Parcial (Total 70 Bs, Anticipo 20 Bs en Efectivo, Saldo 50 Bs fiado)
    // =========================================================================
    final totalFiado = 70.0;
    final anticipoEfectivo = 20.0;
    final saldoFiado = 50.0;

    final ventaFiadoParcial = Venta(
      tenantId: tenantId,
      clienteId: clienteId,
      cajaTurnoId: turno.id,
      totalVenta: totalFiado,
      metodoPago: 'CREDITO_FIADO',
      montoRecibido: anticipoEfectivo,
      cambioEntregado: 30.0, // Entregó un billete de 50 para el anticipo de 20
      fechaVenta: DateTime.now(),
    );

    final detallesFiado = [
      const DetalleVenta(
        productoId: 'prod-arroz-5k',
        cantidad: 1.0,
        precioUnitario: 40.0,
        costoUnitario: 30.0,
        subtotal: 40.0,
      ),
      const DetalleVenta(
        productoId: 'prod-aceite-1l',
        cantidad: 2.0,
        precioUnitario: 15.0,
        costoUnitario: 9.0,
        subtotal: 30.0,
      ),
    ];

    final pagosFiadoParcial = [
      PagoVenta(
        tenantId: tenantId,
        metodo: 'EFECTIVO',
        monto: anticipoEfectivo,
        createdAt: DateTime.now(),
      ),
      PagoVenta(
        tenantId: tenantId,
        metodo: 'FIADO',
        monto: saldoFiado,
        createdAt: DateTime.now(),
      ),
    ];

    await ventaRepo.registrarTransaccionCompleta(
      venta: ventaFiadoParcial,
      detalles: detallesFiado,
      pagos: pagosFiadoParcial,
    );

    // 1. Verificar Trigger de Saldo de Cliente:
    // Debe haber sumado exactamente (70 - 20) = 50 Bs.
    final clienteRes = await db.query('clientes', where: 'id = ?', whereArgs: [clienteId]);
    final saldoCliente = (clienteRes.first['saldo_actual'] as num).toDouble();
    expect(saldoCliente, 50.0, reason: 'El saldo del cliente debe ser exactamente el neto fiado (70 - 20 = 50)');

    // 2. Verificar Caja:
    // El anticipo en efectivo (20) debe ingresar a totalVentasEfectivo
    // Los fiados otorgados netos deben ser 50
    resumen = await cajaRepo.obtenerResumenTurno(turno.id, tenantId);
    expect(resumen.totalVentasEfectivo, 70.0, reason: '50 de la venta A + 20 del anticipo fiado B');
    expect(resumen.totalFiadosOtorgados, 50.0, reason: 'Monto neto que queda debiendo la clienta');
    expect(resumen.montoEsperadoEfectivo, 170.0, reason: '100 inicial + 50 venta + 20 anticipo');

    // 3. Verificar Historial del Cliente (Cuentas por Cobrar):
    final movimientos = await clientesRepo.obtenerMovimientosCliente(clienteId, limite: 10);
    expect(movimientos.isNotEmpty, true);

    final movFiado = movimientos.firstWhere((m) => m['tipo'] == 'FIADO');
    expect(movFiado['total_cuenta'], 70.0);
    expect(movFiado['anticipo'], 20.0);
    expect(movFiado['monto'], 50.0);

    // 4. Verificar que se preserven íntegramente los productos sacados
    final items = movFiado['detalles_items'] as List<Map<String, dynamic>>?;
    expect(items, isNotNull);
    expect(items!.length, 2, reason: 'Deben estar los 2 productos que sacó en la venta');
    expect(items.any((it) => it['nombre'] == 'Arroz Grano de Oro 5kg'), true);
    expect(items.any((it) => it['nombre'] == 'Aceite Fino 1L'), true);

    // =========================================================================
    // PRUEBA C: Fiado Parcial con Anticipo por QR
    // =========================================================================
    // Total 40 Bs, paga 15 Bs por QR, fía 25 Bs
    final ventaFiadoQr = Venta(
      tenantId: tenantId,
      clienteId: clienteId,
      cajaTurnoId: turno.id,
      totalVenta: 40.0,
      metodoPago: 'CREDITO_FIADO',
      montoRecibido: 15.0,
      cambioEntregado: 0.0,
      fechaVenta: DateTime.now(),
    );

    final detallesQr = [
      const DetalleVenta(
        productoId: 'prod-arroz-5k',
        cantidad: 1.0,
        precioUnitario: 40.0,
        costoUnitario: 30.0,
        subtotal: 40.0,
      ),
    ];

    final pagosFiadoQr = [
      PagoVenta(
        tenantId: tenantId,
        metodo: 'QR',
        monto: 15.0,
        createdAt: DateTime.now(),
      ),
      PagoVenta(
        tenantId: tenantId,
        metodo: 'FIADO',
        monto: 25.0,
        createdAt: DateTime.now(),
      ),
    ];

    await ventaRepo.registrarTransaccionCompleta(
      venta: ventaFiadoQr,
      detalles: detallesQr,
      pagos: pagosFiadoQr,
    );

    // Deuda anterior era 50, sumamos 25 -> 75 Bs
    final clienteRes2 = await db.query('clientes', where: 'id = ?', whereArgs: [clienteId]);
    final saldoCliente2 = (clienteRes2.first['saldo_actual'] as num).toDouble();
    expect(saldoCliente2, 75.0);

    // En caja, ventasQr debe registrar 15 Bs
    resumen = await cajaRepo.obtenerResumenTurno(turno.id, tenantId);
    expect(resumen.totalVentasQr, 15.0);
    expect(resumen.totalFiadosOtorgados, 75.0); // 50 anterior + 25 nuevo
  });
}
