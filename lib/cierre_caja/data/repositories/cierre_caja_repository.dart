import '../../../../core/database/app_database.dart';
import '../models/cierre_caja_model.dart';

class CierreCajaRepository {
  final AppDatabase _db;

  CierreCajaRepository([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  /// Calcula el efectivo esperado en caja sumando las ventas en efectivo + fondo fijo
  Future<double> calcularMontoEsperadoEnEfectivo(
    String tenantId, {
    double fondoFijo = 0.0,
  }) async {
    try {
      final db = await _db.database;
      final res = await db.rawQuery(
        'SELECT COALESCE(SUM(monto), 0) as total FROM pagos_ventas WHERE tenant_id = ? AND metodo = "EFECTIVO"',
        [tenantId],
      );

      final totalEfectivo = (res.first['total'] as num?)?.toDouble() ?? 0.0;
      final totalEsperado = fondoFijo + totalEfectivo;
      return (totalEsperado * 100).round() / 100.0;
    } catch (_) {
      return fondoFijo;
    }
  }

  /// Registra el cierre de caja inmutable en SQLite local
  Future<CierreCaja> registrarCierre(CierreCaja cierre) async {
    final db = await _db.database;
    final id = cierre.id ?? AppDatabase.nuevoId();
    final cMap = cierre.copyWith(id: id).toMap();

    await db.insert('cierres_caja', AppDatabase.aFila(cMap));
    return CierreCaja.fromMap(cMap);
  }
}
