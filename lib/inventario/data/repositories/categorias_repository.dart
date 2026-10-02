import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/categoria_model.dart';

class CategoriasRepository {
  final SupabaseClient _client;

  CategoriasRepository(this._client);

  /// Obtiene todas las categorías y subcategorías organizadas en árbol (Padre -> Subcategorías)
  Future<List<CategoriaModel>> obtenerArbolCategorias(String tenantId) async {
    final response = await _client
        .from('categorias')
        .select()
        .eq('tenant_id', tenantId)
        .order('orden', ascending: true)
        .order('nombre', ascending: true);

    final List<dynamic> data = response as List<dynamic>;
    final List<CategoriaModel> todas = data
        .map((item) => CategoriaModel.fromMap(item as Map<String, dynamic>))
        .toList();

    // Separar principales y subcategorías
    final principales = todas.where((c) => c.esPrincipal).toList();
    final Map<String, List<CategoriaModel>> subPorPadre = {};

    for (final c in todas.where((c) => !c.esPrincipal)) {
      if (c.parentId != null) {
        subPorPadre.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }

    // Ensamblar árbol
    return principales.map((padre) {
      final subs = subPorPadre[padre.id] ?? [];
      return padre.copyWith(subcategorias: subs);
    }).toList();
  }

  /// Obtiene solo las categorías principales (Nivel 1)
  Future<List<CategoriaModel>> obtenerCategoriasPrincipales(String tenantId) async {
    final response = await _client
        .from('categorias')
        .select()
        .eq('tenant_id', tenantId)
        .isFilter('parent_id', null)
        .order('orden', ascending: true)
        .order('nombre', ascending: true);

    return (response as List<dynamic>)
        .map((item) => CategoriaModel.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene las subcategorías de una categoría padre dada
  Future<List<CategoriaModel>> obtenerSubcategoriasDePadre(String tenantId, String parentId) async {
    final response = await _client
        .from('categorias')
        .select()
        .eq('tenant_id', tenantId)
        .eq('parent_id', parentId)
        .order('orden', ascending: true)
        .order('nombre', ascending: true);

    return (response as List<dynamic>)
        .map((item) => CategoriaModel.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  /// Registra una nueva categoría o subcategoría
  Future<CategoriaModel> crearCategoria(CategoriaModel categoria) async {
    final map = categoria.toMap();
    map.remove('id');
    map.remove('created_at');
    map.remove('updated_at');

    final response = await _client
        .from('categorias')
        .insert(map)
        .select()
        .single();

    return CategoriaModel.fromMap(response);
  }

  /// Actualiza nombre, icono u orden de una categoría existente
  Future<CategoriaModel> actualizarCategoria(CategoriaModel categoria) async {
    final map = categoria.toMap();
    map.remove('created_at');
    map['updated_at'] = DateTime.now().toUtc().toIso8601String();

    final response = await _client
        .from('categorias')
        .update(map)
        .eq('id', categoria.id)
        .eq('tenant_id', categoria.tenantId)
        .select()
        .single();

    return CategoriaModel.fromMap(response);
  }

  /// Elimina una categoría o subcategoría (si es principal, cascade elimina sus subcategorías)
  Future<void> eliminarCategoria(String id, String tenantId) async {
    await _client
        .from('categorias')
        .delete()
        .eq('id', id)
        .eq('tenant_id', tenantId);
  }
}
