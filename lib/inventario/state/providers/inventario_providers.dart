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

/// Categoría seleccionada actualmente para filtrar en el catálogo (null = todas)
final filtroCategoriaSeleccionadaProvider = StateProvider<String?>((ref) => null);

/// Mapa de categorías únicas disponibles en los productos con su conteo de artículos
final categoriasDisponiblesProvider = Provider<Map<String, int>>((ref) {
  final productosAsync = ref.watch(productosListProvider);
  return productosAsync.maybeWhen(
    data: (productos) {
      final Map<String, int> conteo = {};
      for (final p in productos) {
        final cat = p.categoria?.trim();
        if (cat != null && cat.isNotEmpty) {
          conteo[cat] = (conteo[cat] ?? 0) + 1;
        }
      }
      return conteo;
    },
    orElse: () => {},
  );
});

/// Proveedor reactivo de productos aplicando simultáneamente el filtro de búsqueda, el chip de stock bajo y categoría
final productosFiltradosProvider = Provider<AsyncValue<List<Producto>>>((ref) {
  final productosAsync = ref.watch(productosListProvider);
  final soloStockBajo = ref.watch(filtroSoloStockBajoProvider);
  final productosStockBajo = ref.watch(productosStockBajoListProvider);
  final categoriaSeleccionada = ref.watch(filtroCategoriaSeleccionadaProvider);

  return productosAsync.whenData((productos) {
    var resultado = productos;

    if (soloStockBajo) {
      final idsBajos = productosStockBajo.map((p) => p.id).toSet();
      resultado = resultado.where((p) => idsBajos.contains(p.id)).toList();
    }

    if (categoriaSeleccionada != null) {
      resultado = resultado
          .where((p) => p.categoria?.trim().toLowerCase() == categoriaSeleccionada.toLowerCase())
          .toList();
    }

    return resultado;
  });
});

/// Contador global de productos que necesitan reponerse para insignias y alertas
final conteoStockBajoProvider = Provider<int>((ref) {
  final productosBajos = ref.watch(productosStockBajoListProvider);
  return productosBajos.length;
});

/// Estado de la operación de guardado o edición de producto
class ProductoOperacionState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const ProductoOperacionState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  ProductoOperacionState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return ProductoOperacionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

/// Notifier que controla la creación, edición y desactivación de productos
class ProductoOperacionNotifier extends StateNotifier<ProductoOperacionState> {
  final InventarioRepository _repository;
  final Ref _ref;

  ProductoOperacionNotifier(this._repository, this._ref)
      : super(const ProductoOperacionState());

  /// Verifica si un código de barras ya está registrado por otro producto activo.
  /// Retorna el Producto colisionante, o null si está disponible.
  Future<Producto?> verificarCodigoBarras(String codigo, {String? excluirProductoId}) async {
    if (codigo.trim().isEmpty) return null;
    try {
      return await _repository.verificarCodigoBarrasDisponible(
        SupabaseConfig.defaultTenantId,
        codigo,
        excluirProductoId: excluirProductoId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Guarda un producto (Crea si id está vacío, actualiza si ya existe).
  /// Si se edita el stock de un producto existente, registra un movimiento de auditoría inmutable.
  Future<Producto?> guardarProducto(Producto producto, {double? stockAnterior}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      Producto resultado;
      if (producto.id.isEmpty) {
        resultado = await _repository.crearProducto(producto);
        state = state.copyWith(
          isLoading: false,
          successMessage: '¡Producto "${resultado.nombre}" registrado con éxito!',
        );
      } else {
        resultado = await _repository.actualizarProducto(producto);

        // Registrar auditoría inmutable si el stock cambió durante la edición
        if (stockAnterior != null) {
          final delta = producto.stockActual - stockAnterior;
          if (delta.abs() > 0.001) {
            try {
              await _repository.registrarAjusteManualStock(
                productoId: producto.id,
                tenantId: producto.tenantId,
                cantidadDelta: delta,
                costoUnitario: producto.costoMayorista,
                stockAnterior: stockAnterior,
                stockPosterior: producto.stockActual,
              );
            } catch (_) {
              // No bloquear el guardado si falla el registro de auditoría
            }
          }
        }

        state = state.copyWith(
          isLoading: false,
          successMessage: '¡Producto "${resultado.nombre}" actualizado correctamente!',
        );
      }

      // Invalidar proveedores de inventario para refrescar el catálogo de inmediato
      _ref.invalidate(productosListProvider);
      return resultado;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al guardar producto: $e',
      );
      return null;
    }
  }

  /// Actualiza rápidamente el precio de venta (y opcionalmente costo) de un producto
  Future<bool> actualizarPrecioVenta(
    Producto producto,
    double nuevoPrecio, {
    double? nuevoCosto,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final modificado = producto.copyWith(
        precioVenta: nuevoPrecio,
        costoMayorista: nuevoCosto ?? producto.costoMayorista,
        updatedAt: DateTime.now(),
      );
      await _repository.actualizarProducto(modificado);
      _ref.invalidate(productosListProvider);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Precio de "${producto.nombre}" actualizado a Bs. ${nuevoPrecio.toStringAsFixed(2)}',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al actualizar precio: $e',
      );
      return false;
    }
  }

  /// Desactiva lógicamente un producto (Soft Delete inmutable)
  Future<bool> desactivarProducto(String productoId, String nombre) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _repository.desactivarProducto(productoId);
      _ref.invalidate(productosListProvider);
      _ref.invalidate(productosInactivosProvider);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Producto "$nombre" retirado del catálogo.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al retirar producto: $e',
      );
      return false;
    }
  }

  /// Reactivar un producto desactivado (restaurar al catálogo)
  Future<Producto?> reactivarProducto(String productoId) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final resultado = await _repository.reactivarProducto(productoId);
      _ref.invalidate(productosListProvider);
      _ref.invalidate(productosInactivosProvider);
      state = state.copyWith(
        isLoading: false,
        successMessage: '¡Producto "${resultado.nombre}" reactivado en el catálogo!',
      );
      return resultado;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al reactivar producto: $e',
      );
      return null;
    }
  }

  void limpiarMensajes() {
    state = const ProductoOperacionState();
  }
}

final productoOperacionProvider =
    StateNotifierProvider<ProductoOperacionNotifier, ProductoOperacionState>((ref) {
  final repo = ref.watch(inventarioRepositoryProvider);
  return ProductoOperacionNotifier(repo, ref);
});

/// Proveedor de productos inactivos (retirados) para la pantalla de reactivación
final productosInactivosProvider = FutureProvider<List<Producto>>((ref) async {
  final repository = ref.watch(inventarioRepositoryProvider);
  const tenantId = SupabaseConfig.defaultTenantId;
  return repository.obtenerProductosInactivos(tenantId);
});

