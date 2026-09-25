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

      final double stockActual = (prodData['stock_actual'] as num).toDouble();
      final double nuevoStock = stockActual - detalle.cantidad;

      await _client
          .from('productos')
          .update({'stock_actual': nuevoStock})
          .eq('id', detalle.productoId);
    }

    return ventaCreada;
  }
}
