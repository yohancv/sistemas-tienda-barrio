import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/venta_models.dart';

class VentaRepository {
  final SupabaseClient _client;

  VentaRepository(this._client);

  /// Registra una venta completa inmutable:
  /// 1. Inserta la venta en 'ventas' y recupera su ID autogenerado.
  /// 2. Asigna venta_id e inserta 'detalle_ventas' en lote.
  /// 3. Asigna venta_id e inserta 'pagos_ventas' en lote.
  /// 4. Descuenta el stock correspondiente en la tabla 'productos'.
  Future<Venta> registrarTransaccionCompleta({
    required Venta venta,
    required List<DetalleVenta> detalles,
    required List<PagoVenta> pagos,
  }) async {
    // 1. Insertar Cabecera de Venta
    final ventaResponse = await _client
        .from('ventas')
        .insert(venta.toMap())
        .select()
        .single();

    final ventaCreada = Venta.fromMap(ventaResponse);
    final String ventaId = ventaCreada.id!;

    // 2. Insertar Detalle de Ventas en lote (Batch)
    final detallesPayload = detalles
        .map((d) => d.copyWith(ventaId: ventaId).toMap())
        .toList();

    await _client.from('detalle_ventas').insert(detallesPayload);

    // 3. Insertar Desglose de Pagos en lote (Batch)
    final pagosPayload = pagos
        .map((p) => p.copyWith(ventaId: ventaId).toMap())
        .toList();

    await _client.from('pagos_ventas').insert(pagosPayload);

    // 4. Descontar Stock de Inventario para cada producto vendido
    for (final detalle in detalles) {
      final prodData = await _client
          .from('productos')
          .select('stock_actual')
          .eq('id', detalle.productoId)
          .single();

      double stockActual = (prodData['stock_actual'] as num).toDouble();

      // AUTO-DESEMPAQUE TRANSPARENTE:
      // Si el stock en mostrador no alcanza para la cantidad vendida (ej. tengo 3 botellas y vendo 4),
      // verificamos si existen cajas/empaques del producto padre en almacén y abrimos automáticamente las necesarias.
      if (stockActual < detalle.cantidad) {
        final List<dynamic> cajasPadre = await _client
            .from('productos')
            .select('id, stock_actual, unidades_por_empaque')
            .eq('producto_hijo_id', detalle.productoId)
            .eq('tenant_id', venta.tenantId)
            .gt('stock_actual', 0)
            .order('stock_actual', ascending: false);

        if (cajasPadre.isNotEmpty) {
          final caja = cajasPadre.first as Map<String, dynamic>;
          final double unidadesPorCaja =
              (caja['unidades_por_empaque'] as num?)?.toDouble() ?? 1.0;
          final double faltante = detalle.cantidad - stockActual;
          final double cajasANecesitar = unidadesPorCaja > 0
              ? (faltante / unidadesPorCaja).ceilToDouble()
              : 1.0;
          final double cajasDisponibles = (caja['stock_actual'] as num).toDouble();
          final double cajasAAbrir =
              cajasANecesitar <= cajasDisponibles ? cajasANecesitar : cajasDisponibles;

          if (cajasAAbrir > 0) {
            // Ejecutar desempaque atómico mediante el RPC seguro de PostgreSQL
            await _client.rpc('desempaquetar_producto', params: {
              'p_caja_id': caja['id'],
              'p_unidades_id': detalle.productoId,
              'p_cantidad_cajas': cajasAAbrir,
              'p_tenant_id': venta.tenantId,
              'p_motivo': 'Auto-desempaque por venta en mostrador (Ticket #$ventaId)',
            });

            // Re-obtener el nuevo stock de botellas tras el desempaque automático
            final prodDataActualizado = await _client
                .from('productos')
                .select('stock_actual')
                .eq('id', detalle.productoId)
                .single();
            stockActual = (prodDataActualizado['stock_actual'] as num).toDouble();
          }
        }
      }

      final double nuevoStock = (stockActual - detalle.cantidad) < 0 ? 0.0 : (stockActual - detalle.cantidad);

      await _client
          .from('productos')
          .update({'stock_actual': nuevoStock})
          .eq('id', detalle.productoId);

      // Registrar salida por venta en el Kardex inmutable
      try {
        final ticketCorto = ventaId.length > 8 ? ventaId.substring(0, 8) : ventaId;
        await _client.from('movimientos_inventario').insert({
          'tenant_id': venta.tenantId,
          'producto_id': detalle.productoId,
          'tipo_movimiento': 'VENTA',
          'cantidad': detalle.cantidad,
          'costo_unitario': detalle.costoUnitario,
          'costo_total': (detalle.costoUnitario * detalle.cantidad),
          'motivo': 'Venta mostrador (Ticket #$ticketCorto)',
          'referencia_id': ventaId,
          'stock_anterior': stockActual,
          'stock_posterior': nuevoStock,
        });
      } catch (e) {
        // ignore: avoid_print
        print('[Kardex Venta Error] No se pudo insertar en movimientos_inventario: $e');
      }
    }

    return ventaCreada;
  }
}
