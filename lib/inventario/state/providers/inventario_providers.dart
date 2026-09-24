import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_client.dart';
import '../../data/models/producto_model.dart';
import '../../data/repositories/inventario_repository.dart';

/// Proveedor del repositorio de inventario inyectando el cliente global de Supabase
final inventarioRepositoryProvider = Provider<InventarioRepository>((ref) {
  return InventarioRepository(SupabaseConfig.client);
});

/// Proveedor del texto de búsqueda reactivo
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Proveedor de la lista de productos activos/filtrados
final productosListProvider = FutureProvider<List<Producto>>((ref) async {
  final repository = ref.watch(inventarioRepositoryProvider);
  final query = ref.watch(searchQueryProvider);
  const tenantId = 'tenant-demo'; // Tenant temporal de trabajo Fase 1

  if (query.trim().isEmpty) {
    return repository.obtenerProductosActivos(tenantId);
  } else {
    return repository.buscarProducto(tenantId, query);
  }
});
