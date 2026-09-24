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
}
