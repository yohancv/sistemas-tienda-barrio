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

/// Proveedor del selector de filtro rápido para ver solo productos con stock bajo
final filtroSoloStockBajoProvider = StateProvider<bool>((ref) => false);

/// Proveedor base que consulta los productos activos en Supabase según el término de búsqueda
final productosListProvider = FutureProvider<List<Producto>>((ref) async {
  final repository = ref.watch(inventarioRepositoryProvider);
  final query = ref.watch(searchQueryProvider);
  const tenantId = SupabaseConfig.defaultTenantId;
  if (query.trim().isEmpty) {
    return repository.obtenerProductosActivos(tenantId);
  } else {
    return repository.buscarProducto(tenantId, query);
  }
});

/// Proveedor reactivo de productos aplicando simultáneamente el filtro de búsqueda y el chip de stock bajo
final productosFiltradosProvider = Provider<AsyncValue<List<Producto>>>((ref) {
  final productosAsync = ref.watch(productosListProvider);
  final soloStockBajo = ref.watch(filtroSoloStockBajoProvider);

  return productosAsync.whenData((productos) {
    if (!soloStockBajo) return productos;
    return productos.where((p) => p.esStockBajo).toList();
  });
});

/// Proveedor de la lista de todos los productos que requieren reposición (stock_actual <= stock_minimo)
final productosStockBajoListProvider = Provider<List<Producto>>((ref) {
  final productosAsync = ref.watch(productosListProvider);
  return productosAsync.maybeWhen(
    data: (productos) => productos.where((p) => p.esStockBajo).toList(),
    orElse: () => <Producto>[],
  );
});

/// Contador global de productos que necesitan reponerse para insignias y alertas
final conteoStockBajoProvider = Provider<int>((ref) {
  final productosBajos = ref.watch(productosStockBajoListProvider);
  return productosBajos.length;
});
