import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/movimiento_inventario_model.dart';

class MovimientosRepository {
  final SupabaseClient _client;

  MovimientosRepository(this._client);

  /// Ejecuta un desempaque mayorista de forma atómica en Supabase vía PostgreSQL RPC.
  /// Descuenta cajas, suma unidades sueltas y registra la auditoría inmutable de ambos movimientos.
  Future<Map<String, dynamic>> desempaquetarCaja({
    required String cajaId,
    required String unidadesId,
    required double cantidadCajas,
    required String tenantId,
    String? motivo,
  }) async {
    try {
      final response = await _client.rpc(
        'desempaquetar_producto',
        params: {
          'p_caja_id': cajaId,
          'p_unidades_id': unidadesId,
          'p_cantidad_cajas': cantidadCajas,
          'p_tenant_id': tenantId,
          'p_motivo': motivo,
        },
      );

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      throw Exception('Error al ejecutar desempaque mayorista: $e');
    }
  }

  /// Registra una merma o rotura de producto con su cálculo financiero de pérdida en Bs.
  /// Descuenta el stock físico y guarda la auditoría inmutable en PostgreSQL.
  Future<Map<String, dynamic>> registrarMerma({
    required String productoId,
    required double cantidad,
    required String tipoMerma, // 'MERMA_ROTURA', 'MERMA_VENCIMIENTO', 'MERMA_DETERIORO'
    required String tenantId,
    String? motivo,
  }) async {
    try {
      final response = await _client.rpc(
        'registrar_merma',
        params: {
          'p_producto_id': productoId,
          'p_cantidad': cantidad,
          'p_tipo_merma': tipoMerma,
          'p_motivo': motivo,
          'p_tenant_id': tenantId,
        },
      );

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      throw Exception('Error al registrar merma de inventario: $e');
    }
  }

  /// Consulta los movimientos recientes de auditoría de inventario (desempaques, mermas, etc.)
  Future<List<MovimientoInventario>> obtenerHistorialMovimientos(
    String tenantId, {
    int limite = 50,
  }) async {
    final response = await _client
        .from('movimientos_inventario')
        .select()
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false)
        .limit(limite);

    return (response as List<dynamic>)
        .map((item) => MovimientoInventario.fromMap(item as Map<String, dynamic>))
        .toList();
  }
}
