import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_client.dart';
import '../../data/models/categoria_model.dart';
import '../../data/repositories/categorias_repository.dart';

/// Proveedor del repositorio de categorías
final categoriasRepositoryProvider = Provider<CategoriasRepository>((ref) {
  return CategoriasRepository(SupabaseConfig.client);
});

/// Proveedor reactivo del árbol completo de categorías y subcategorías
final arbolCategoriasProvider = FutureProvider<List<CategoriaModel>>((ref) async {
  final repo = ref.watch(categoriasRepositoryProvider);
  return repo.obtenerArbolCategorias(SupabaseConfig.defaultTenantId);
});

/// Proveedor de las categorías principales (Nivel 1)
final categoriasPrincipalesProvider = FutureProvider<List<CategoriaModel>>((ref) async {
  final repo = ref.watch(categoriasRepositoryProvider);
  return repo.obtenerCategoriasPrincipales(SupabaseConfig.defaultTenantId);
});

/// Proveedor para obtener las subcategorías de un padre específico
final subcategoriasPorPadreProvider = FutureProvider.family<List<CategoriaModel>, String>((ref, parentId) async {
  final repo = ref.watch(categoriasRepositoryProvider);
  return repo.obtenerSubcategoriasDePadre(SupabaseConfig.defaultTenantId, parentId);
});

/// Controlador para operaciones CRUD de Categorías y Subcategorías
class CategoriasNotifier extends StateNotifier<AsyncValue<void>> {
  final CategoriasRepository _repository;
  final Ref _ref;

  CategoriasNotifier(this._repository, this._ref) : super(const AsyncValue.data(null));

  Future<CategoriaModel?> crearCategoria({
    required String nombre,
    String? parentId,
    String? icono,
    int orden = 0,
  }) async {
    state = const AsyncValue.loading();
    try {
      final nueva = CategoriaModel(
        id: '',
        tenantId: SupabaseConfig.defaultTenantId,
        nombre: nombre.trim(),
        parentId: parentId,
        icono: icono?.trim(),
        orden: orden,
      );
      final creada = await _repository.crearCategoria(nueva);
      _ref.invalidate(arbolCategoriasProvider);
      _ref.invalidate(categoriasPrincipalesProvider);
      state = const AsyncValue.data(null);
      return creada;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> actualizarCategoria(CategoriaModel categoria) async {
    state = const AsyncValue.loading();
    try {
      await _repository.actualizarCategoria(categoria);
      _ref.invalidate(arbolCategoriasProvider);
      _ref.invalidate(categoriasPrincipalesProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> eliminarCategoria(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.eliminarCategoria(id, SupabaseConfig.defaultTenantId);
      _ref.invalidate(arbolCategoriasProvider);
      _ref.invalidate(categoriasPrincipalesProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final categoriasNotifierProvider = StateNotifierProvider<CategoriasNotifier, AsyncValue<void>>((ref) {
  return CategoriasNotifier(ref.watch(categoriasRepositoryProvider), ref);
});
