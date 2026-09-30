import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/producto_model.dart';

class InventarioRepository {
  final SupabaseClient _client;

  InventarioRepository(this._client);

  /// Obtiene todos los productos activos de una tienda específica (Aislamiento Multi-Tenant)
  Future<List<Producto>> obtenerProductosActivos(String tenantId) async {
    final response = await _client
        .from('productos')
        .select()
        .eq('tenant_id', tenantId)
        .eq('estado_activo', true)
        .order('nombre', ascending: true);

    return (response as List<dynamic>)
        .map((item) => Producto.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Busca productos activos por coincidencia en nombre o código de barras (Búsqueda difusa / Barcode)
  Future<List<Producto>> buscarProducto(String tenantId, String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return obtenerProductosActivos(tenantId);
    }

    final response = await _client
        .from('productos')
        .select()
        .eq('tenant_id', tenantId)
        .eq('estado_activo', true)
        .or('nombre.ilike.%$cleanQuery%,codigo_barras.ilike.%$cleanQuery%')
        .order('nombre', ascending: true);

    return (response as List<dynamic>)
        .map((item) => Producto.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Crea un nuevo producto en Supabase (Aislamiento Multi-Tenant)
  Future<Producto> crearProducto(Producto producto) async {
    final map = producto.toMap();
    if (producto.id.isEmpty) {
      map.remove('id');
    }
    map.remove('created_at');
    map.remove('updated_at');

    final response = await _client
        .from('productos')
        .insert(map)
        .select()
        .single();

    return Producto.fromMap(response);
  }

  /// Actualiza los datos y precios de un producto existente
  Future<Producto> actualizarProducto(Producto producto) async {
    final map = producto.toMap();
    map.remove('id');
    map['updated_at'] = DateTime.now().toIso8601String();

    final response = await _client
        .from('productos')
        .update(map)
        .eq('id', producto.id)
        .select()
        .single();

    return Producto.fromMap(response);
  }

  /// Desactiva lógicamente un producto (Soft Delete para trazabilidad histórica)
  Future<void> desactivarProducto(String productoId) async {
    await _client
        .from('productos')
        .update({
          'estado_activo': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', productoId);
  }

  /// Reactivar un producto previamente dado de baja (Soft Delete inverso)
  Future<Producto> reactivarProducto(String productoId) async {
    final response = await _client
        .from('productos')
        .update({
          'estado_activo': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', productoId)
        .select()
        .single();

    return Producto.fromMap(response);
  }

  /// Obtiene los productos inactivos (retirados del catálogo) para reactivación
  Future<List<Producto>> obtenerProductosInactivos(String tenantId) async {
    final response = await _client
        .from('productos')
        .select()
        .eq('tenant_id', tenantId)
        .eq('estado_activo', false)
        .order('updated_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) => Producto.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Verifica si un código de barras ya está en uso por otro producto activo.
  /// Retorna el Producto existente si hay colisión, o null si el código está disponible.
  Future<Producto?> verificarCodigoBarrasDisponible(
    String tenantId,
    String codigoBarras, {
    String? excluirProductoId,
  }) async {
    if (codigoBarras.trim().isEmpty) return null;

    var query = _client
        .from('productos')
        .select()
        .eq('tenant_id', tenantId)
        .eq('estado_activo', true)
        .eq('codigo_barras', codigoBarras.trim());

    if (excluirProductoId != null) {
      query = query.neq('id', excluirProductoId);
    }

    final response = await query.limit(1);
    final lista = response as List<dynamic>;

    if (lista.isEmpty) return null;
    return Producto.fromMap(lista.first as Map<String, dynamic>);
  }

  /// Registra un ajuste manual de stock como movimiento inmutable de auditoría.
  /// Se usa cuando el usuario edita directamente el stock desde el formulario de producto.
  Future<void> registrarAjusteManualStock({
    required String productoId,
    required String tenantId,
    required double cantidadDelta,
    required double costoUnitario,
    double? stockAnterior,
    double? stockPosterior,
  }) async {
    final tipoMovimiento = cantidadDelta > 0 ? 'AJUSTE_POSITIVO' : 'AJUSTE_NEGATIVO';
    final costoTotal = costoUnitario * cantidadDelta.abs();

    await _client.from('movimientos_inventario').insert({
      'tenant_id': tenantId,
      'producto_id': productoId,
      'tipo_movimiento': tipoMovimiento,
      'cantidad': cantidadDelta.abs(),
      'costo_unitario': costoUnitario,
      'costo_total': costoTotal,
      'motivo': 'Ajuste manual de stock desde edición de catálogo',
      'stock_anterior': ?stockAnterior,
      'stock_posterior': ?stockPosterior,
    });
  }
}
