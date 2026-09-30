import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/compra_model.dart';
import '../models/item_compra_model.dart';
import '../models/proveedor_model.dart';

class ComprasRepository {
  final SupabaseClient _client;

  ComprasRepository(this._client);

  /// Obtiene todos los proveedores activos de la tienda
  Future<List<ProveedorModel>> obtenerProveedores(String tenantId) async {
    final response = await _client
        .from('proveedores')
        .select()
        .eq('tenant_id', tenantId)
        .eq('activo', true)
        .order('nombre_empresa', ascending: true);

    return (response as List<dynamic>)
        .map((item) => ProveedorModel.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Registra un nuevo proveedor o distribuidor
  Future<ProveedorModel> crearProveedor(ProveedorModel proveedor) async {
    final map = proveedor.toMap()..remove('id');
    final response = await _client
        .from('proveedores')
        .insert(map)
        .select()
        .single();

    return ProveedorModel.fromMap(response);
  }

  /// Edita los datos de un proveedor existente
  Future<ProveedorModel> editarProveedor(ProveedorModel proveedor) async {
    final response = await _client
        .from('proveedores')
        .update({
          'nombre_empresa': proveedor.nombreEmpresa,
          'nombre_contacto': proveedor.nombreContacto,
          'telefono': proveedor.telefono,
          'nit_ci': proveedor.nitCi,
          'dias_visita': proveedor.diasVisita,
          'activo': proveedor.activo,
        })
        .eq('id', proveedor.id)
        .select()
        .single();

    return ProveedorModel.fromMap(response);
  }

  /// Registra una compra completa de mercadería de manera atómica mediante RPC PostgreSQL.
  /// Incrementa stock, actualiza costos mayoristas, genera kardex (ENTRADA_COMPRA)
  /// y descuenta de caja si hubo egreso de turno.
  Future<Map<String, dynamic>> registrarCompraMercaderia({
    required CompraModel compra,
    required List<ItemCompraModel> detalles,
  }) async {
    try {
      final response = await _client.rpc(
        'fn_registrar_compra_mercaderia',
        params: {
          'p_compra': compra.toMap(),
          'p_detalles': detalles.map((d) => d.toMap()).toList(),
        },
      );

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      throw Exception('Error al registrar compra de mercadería: $e');
    }
  }

  /// Consulta el historial de compras con filtros opcionales
  Future<List<CompraModel>> obtenerHistorialCompras(
    String tenantId, {
    DateTime? desde,
    DateTime? hasta,
    String? proveedorId,
    int limite = 50,
  }) async {
    var query = _client
        .from('compras')
        .select('*, proveedores(nombre_empresa), detalle_compras(id)')
        .eq('tenant_id', tenantId);

    if (proveedorId != null && proveedorId.isNotEmpty) {
      query = query.eq('proveedor_id', proveedorId);
    }

    if (desde != null) {
      query = query.gte('fecha_compra', desde.toIso8601String());
    }

    if (hasta != null) {
      query = query.lte('fecha_compra', hasta.toIso8601String());
    }

    final response = await query
        .order('fecha_compra', ascending: false)
        .limit(limite);

    return (response as List<dynamic>)
        .map((item) => CompraModel.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene los ítems detallados de una compra específica
  Future<List<ItemCompraModel>> obtenerDetalleCompra(String compraId) async {
    final response = await _client
        .from('detalle_compras')
        .select('*, productos(nombre, codigo_barras, tipo_empaque, unidades_por_empaque, precio_venta)')
        .eq('compra_id', compraId);

    return (response as List<dynamic>)
        .map((item) => ItemCompraModel.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Asocia un producto a un proveedor predeterminado ("CBN no vende aceite")
  Future<void> asociarProductoAProveedor(String productoId, String proveedorId) async {
    await _client
        .from('productos')
        .update({'proveedor_id': proveedorId})
        .eq('id', productoId);
  }
}
