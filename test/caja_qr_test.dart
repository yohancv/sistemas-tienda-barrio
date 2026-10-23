import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'package:si_tienda_barrio/core/config/supabase_client.dart';
import 'package:si_tienda_barrio/core/database/app_database.dart';
import 'package:si_tienda_barrio/cierre_caja/data/repositories/caja_repository.dart';
import 'package:si_tienda_barrio/punto_de_venta/data/repositories/venta_repository.dart';
import 'package:si_tienda_barrio/punto_de_venta/data/models/venta_models.dart';
import 'package:si_tienda_barrio/reportes/data/repositories/reportes_repository.dart';
import 'package:si_tienda_barrio/reportes/data/models/reporte_financiero_model.dart';

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

  test('Venta con pago QR se refleja correctamente en Caja y Reportes', () async {
    final db = await AppDatabase.instance.database;
    final tenantId = SupabaseConfig.defaultTenantId;

    final cajaRepo = CajaRepository();
    final ventaRepo = VentaRepository();
    final reportesRepo = ReportesRepository();

    // 1. Abrir Turno de Caja con Fondo de 100 Bs
    final turno = await cajaRepo.abrirTurno(
      tenantId: tenantId,
      montoInicial: 100.0,
      usuarioId: 'DUEÑO',
    );

    // 2. Registrar Producto de prueba
    await db.insert('productos', {
      'id': 'prod-test-qr-1',
      'tenant_id': tenantId,
      'nombre': 'Vodka 750ml',
      'codigo_barras': '123456789',
      'precio_venta': 50.0,
      'costo_mayorista': 30.0,
      'stock_actual': 10.0,
      'stock_minimo': 2.0,
      'estado_activo': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);

    // 3. Registrar Venta con Pago QR de 50 Bs
    final ventaQr = Venta(
      tenantId: tenantId,
      cajaTurnoId: turno.id,
      totalVenta: 50.0,
      metodoPago: 'QR',
      montoRecibido: 50.0,
      cambioEntregado: 0.0,
      fechaVenta: DateTime.now(),
    );

    final List<DetalleVenta> detalleQr = [
      const DetalleVenta(
        productoId: 'prod-test-qr-1',
        cantidad: 1.0,
        precioUnitario: 50.0,
        subtotal: 50.0,
      ),
    ];

    final List<PagoVenta> pagosQr = [
      PagoVenta(
        tenantId: tenantId,
        metodo: 'QR',
        monto: 50.0,
        createdAt: DateTime.now(),
      ),
    ];

    await ventaRepo.registrarTransaccionCompleta(
      venta: ventaQr,
      detalles: detalleQr,
      pagos: pagosQr,
    );

    // 4. Verificar Resumen de Turno de Caja
    final resumen = await cajaRepo.obtenerResumenTurno(turno.id, tenantId);
    expect(resumen.montoInicial, 100.0);
    expect(resumen.totalVentasEfectivo, 0.0);
    expect(resumen.totalVentasQr, 50.0);
    expect(resumen.totalCobrosQr, 50.0);
    expect(resumen.saldoNetoQr, 50.0);
    expect(resumen.montoEsperadoEfectivo, 100.0);
    expect(resumen.totalDineroDisponible, 150.0);

    // 5. Verificar Ventas de Turno
    final ventasTurno = await cajaRepo.obtenerVentasTurno(turno.id, tenantId);
    expect(ventasTurno.length, 1);
    expect(ventasTurno.first.esQr, true);
    expect(ventasTurno.first.totalVenta, 50.0);
    expect(ventasTurno.first.totalQr, 50.0);
    expect(ventasTurno.first.itemsResumen, contains('Vodka 750ml'));

    // 6. Verificar Dashboard de Reportes
    final rep = await reportesRepo.obtenerReporteCompleto(PeriodoFiltroReporte.hoy);
    expect(rep.financiero.ventasTotales, 50.0);
    expect(rep.financiero.totalQrVentas, 50.0);
    expect(rep.financiero.totalDineroEnBanco, 50.0);
  });
}
