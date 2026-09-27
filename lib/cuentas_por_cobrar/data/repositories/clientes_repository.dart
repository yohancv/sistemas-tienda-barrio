import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/abono_model.dart';
import '../models/cliente_model.dart';

class ClientesRepository {
  final SupabaseClient _client;

  ClientesRepository(this._client);

  /// Obtiene todos los clientes activos ordenados prioritariamente por los que tienen mayor deuda
  Future<List<Cliente>> obtenerClientes(String tenantId) async {
    final response = await _client
        .from('clientes')
        .select()
        .eq('tenant_id', tenantId)
        .eq('activo', true)
        .order('saldo_actual', ascending: false)
        .order('nombre', ascending: true);

    return (response as List<dynamic>)
        .map((item) => Cliente.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Busca clientes activos por coincidencia en nombre o teléfono
  Future<List<Cliente>> buscarClientes(String tenantId, String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return obtenerClientes(tenantId);
    }

    final response = await _client
        .from('clientes')
        .select()
        .eq('tenant_id', tenantId)
        .eq('activo', true)
        .or('nombre.ilike.%$cleanQuery%,telefono.ilike.%$cleanQuery%')
        .order('saldo_actual', ascending: false)
        .order('nombre', ascending: true);

    return (response as List<dynamic>)
        .map((item) => Cliente.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Registra un nuevo cliente/vecino en el sistema
  Future<Cliente> crearCliente(Cliente cliente) async {
    final map = cliente.toMap()..remove('id'); // Dejar que PostgreSQL genere el UUID
    final response = await _client
        .from('clientes')
        .insert(map)
        .select()
        .single();

    return Cliente.fromMap(response);
  }

  /// Ejecuta un abono a deuda de forma atómica mediante la función RPC en PostgreSQL
  Future<Map<String, dynamic>> registrarAbono({
    required String clienteId,
    required double monto,
    String metodoPago = 'EFECTIVO',
    String? notas,
    required String tenantId,
  }) async {
    try {
      final response = await _client.rpc(
        'registrar_abono_deuda',
        params: {
          'p_cliente_id': clienteId,
          'p_monto': monto,
          'p_metodo_pago': metodoPago,
          'p_notas': notas,
          'p_tenant_id': tenantId,
        },
      );

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      throw Exception('Error al registrar abono a deuda: $e');
    }
  }

  /// Obtiene los abonos realizados por un cliente específico
  Future<List<AbonoDeuda>> obtenerHistorialAbonos(
    String clienteId, {
    int limite = 30,
  }) async {
    final response = await _client
        .from('abonos_deuda')
        .select()
        .eq('cliente_id', clienteId)
        .order('fecha_abono', ascending: false)
        .limit(limite);

    return (response as List<dynamic>)
        .map((item) => AbonoDeuda.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene las ventas sacadas a fiado por este cliente
  Future<List<Map<String, dynamic>>> obtenerVentasFiadas(
    String clienteId, {
    int limite = 30,
  }) async {
    final response = await _client
        .from('ventas')
        .select()
        .eq('cliente_id', clienteId)
        .eq('metodo_pago', 'CREDITO_FIADO')
        .order('fecha_venta', ascending: false)
        .limit(limite);

    return List<Map<String, dynamic>>.from(response as List);
  }
}
