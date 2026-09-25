import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cierre_caja_model.dart';

class CierreCajaRepository {
  final SupabaseClient _client;

  CierreCajaRepository(this._client);

  /// Calcula el efectivo esperado en caja sumando las ventas en efectivo + fondo fijo
  Future<double> calcularMontoEsperadoEnEfectivo(
    String tenantId, {
    double fondoFijo = 0.0,
  }) async {
    try {
      final response = await _client
          .from('pagos_ventas')
          .select('monto')
          .eq('tenant_id', tenantId)
          .eq('metodo', 'EFECTIVO');

      double totalEfectivo = 0.0;
      for (final row in response as List<dynamic>) {
        final monto = row['monto'];
        if (monto is num) {
          totalEfectivo += monto.toDouble();
        } else if (monto is String) {
          totalEfectivo += double.tryParse(monto) ?? 0.0;
        }
      }

      final totalEsperado = fondoFijo + totalEfectivo;
      return (totalEsperado * 100).round() / 100.0;
    } catch (_) {
      return fondoFijo;
    }
  }

  /// Registra el cierre de caja inmutable en Supabase
  Future<CierreCaja> registrarCierre(CierreCaja cierre) async {
    final response = await _client
        .from('cierres_caja')
        .insert(cierre.toMap())
        .select()
        .single();

    return CierreCaja.fromMap(response);
  }
}
