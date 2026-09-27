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

/// Mapeo de unidades sueltas disponibles en cajas/empaques cerrados de almacén
/// Retorna un mapa: [producto_hijo_id -> total_unidades_en_cajas]
final unidadesEnEmpaquesPadreProvider = Provider<Map<String, double>>((ref) {
  final productosAsync = ref.watch(productosListProvider);
  return productosAsync.maybeWhen(
    data: (productos) {
      final Map<String, double> map = {};
      for (final p in productos) {
        if (p.productoHijoId != null && p.stockActual > 0 && p.estadoActivo) {
          final factor = p.unidadesPorEmpaque > 0 ? p.unidadesPorEmpaque : 1.0;
          final unidades = p.stockActual * factor;
          map[p.productoHijoId!] = (map[p.productoHijoId!] ?? 0.0) + unidades;
        }
      }
      return map;
    },
    orElse: () => {},
  );
});

/// Proveedor de la lista de productos que REALMENTE requieren compra a distribuidores.
/// REGLA DE NEGOCIO: Si un producto hijo (ej. botellas sueltas) tiene stock bajo en mostrador,
/// pero la tienda aún dispone de cajas/packs cerrados en almacén y el total sumado supera el stock mínimo,
/// NO aparece en la lista de reposición de compras porque la necesidad se cubre con desempaque interno.
final productosStockBajoListProvider = Provider<List<Producto>>((ref) {
  final productosAsync = ref.watch(productosListProvider);
  final unidadesEnCajasMap = ref.watch(unidadesEnEmpaquesPadreProvider);

  return productosAsync.maybeWhen(
    data: (productos) {
      return productos.where((p) {
        if (!p.esStockBajo) return false;

        final unidadesEnCajas = unidadesEnCajasMap[p.id] ?? 0.0;
        if (unidadesEnCajas > 0) {
          final stockTotalDisponible = p.stockActual + unidadesEnCajas;
          // Si el total disponible sumando las cajas en bodega supera el stock mínimo,
          // no requiere compra externa al distribuidor
          if (stockTotalDisponible > p.stockMinimo) {
            return false;
          }
        }
        return true;
      }).toList();
    },
    orElse: () => <Producto>[],
  );
});

/// Proveedor reactivo de productos aplicando simultáneamente el filtro de búsqueda y el chip de stock bajo
final productosFiltradosProvider = Provider<AsyncValue<List<Producto>>>((ref) {
  final productosAsync = ref.watch(productosListProvider);
  final soloStockBajo = ref.watch(filtroSoloStockBajoProvider);
  final productosStockBajo = ref.watch(productosStockBajoListProvider);

  return productosAsync.whenData((productos) {
    if (!soloStockBajo) return productos;
    final idsBajos = productosStockBajo.map((p) => p.id).toSet();
    return productos.where((p) => idsBajos.contains(p.id)).toList();
  });
});

/// Contador global de productos que necesitan reponerse para insignias y alertas
final conteoStockBajoProvider = Provider<int>((ref) {
  final productosBajos = ref.watch(productosStockBajoListProvider);
  return productosBajos.length;
});
