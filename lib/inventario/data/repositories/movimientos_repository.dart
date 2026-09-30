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
  /// Descuenta el stock físico y guarda la auditoría inmutable con stock_anterior y stock_posterior.
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

  /// Consulta el Kardex filtrable con JOIN al catálogo de productos
  Future<List<MovimientoInventario>> obtenerKardex({
    required String tenantId,
    String? productoId,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? filtroTipo,
    int limite = 100,
  }) async {
    try {
      var query = _client
          .from('movimientos_inventario')
          .select('*, productos(nombre, codigo_barras)')
          .eq('tenant_id', tenantId);

      // Filtro por producto específico
      if (productoId != null && productoId.isNotEmpty) {
        query = query.eq('producto_id', productoId);
      }

      // Filtros de fecha
      if (fechaInicio != null) {
        query = query.gte('created_at', fechaInicio.toIso8601String());
      }
      if (fechaFin != null) {
        query = query.lte('created_at', fechaFin.toIso8601String());
      }

      // Filtros por grupo de tipo de movimiento
      if (filtroTipo != null && filtroTipo != 'TODOS') {
        switch (filtroTipo) {
          case 'VENTA':
            query = query.eq('tipo_movimiento', 'VENTA');
            break;
          case 'MERMAS':
            query = query.inFilter('tipo_movimiento', [
              'MERMA_ROTURA',
              'MERMA_VENCIMIENTO',
              'MERMA_DETERIORO',
            ]);
            break;
          case 'DESEMPAQUES':
            query = query.inFilter('tipo_movimiento', [
              'DESEMPAQUE_SALIDA',
              'DESEMPAQUE_ENTRADA',
            ]);
            break;
          case 'AJUSTES':
            query = query.inFilter('tipo_movimiento', [
              'AJUSTE_POSITIVO',
              'AJUSTE_NEGATIVO',
              'AJUSTE_MANUAL',
            ]);
            break;
          case 'ENTRADAS':
            query = query.inFilter('tipo_movimiento', [
              'ENTRADA_COMPRA',
              'DESEMPAQUE_ENTRADA',
              'AJUSTE_POSITIVO',
            ]);
            break;
          default:
            query = query.eq('tipo_movimiento', filtroTipo);
        }
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limite);

      return (response as List<dynamic>)
          .map((item) => MovimientoInventario.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      // ignore: avoid_print
      print('[Kardex Repository Error] Falló al consultar kardex: $e\n$stack');
      return [];
    }
  }

  /// Consulta rápida de movimientos recientes de auditoría
  Future<List<MovimientoInventario>> obtenerHistorialMovimientos(
    String tenantId, {
    int limite = 50,
  }) async {
    return obtenerKardex(tenantId: tenantId, limite: limite);
  }
}
