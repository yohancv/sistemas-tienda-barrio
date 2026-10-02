import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../data/models/categoria_model.dart';
import '../../state/providers/categorias_providers.dart';

/// Pantalla dedicada para gestionar el Árbol de Categorías y Subcategorías
class GestionCategoriasScreen extends ConsumerStatefulWidget {
  const GestionCategoriasScreen({super.key});

  @override
  ConsumerState<GestionCategoriasScreen> createState() => _GestionCategoriasScreenState();
}

class _GestionCategoriasScreenState extends ConsumerState<GestionCategoriasScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filtroTexto = '';

  final List<String> _emojisSugeridos = [
    '🍺', '🥤', '🌿', '🥛', '🍪', '🚬', '🍞', '🧼', '🍬', '🥩', '🧊', '🥫', '🍿', '🧃', '🥚', '🧀'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirModalCrearOEditarCategoria({
    CategoriaModel? categoriaParaEditar,
    CategoriaModel? categoriaPadre,
  }) {
    final bool esSubcategoria = categoriaPadre != null || (categoriaParaEditar != null && !categoriaParaEditar.esPrincipal);
    final String tituloModal = categoriaParaEditar != null
        ? (esSubcategoria ? 'Editar Subcategoría' : 'Editar Categoría')
        : (esSubcategoria ? 'Nueva Subcategoría en ${categoriaPadre?.nombre}' : 'Nueva Categoría Principal');

    final TextEditingController nombreCtrl = TextEditingController(text: categoriaParaEditar?.nombre ?? '');
    String iconoSeleccionado = categoriaParaEditar?.icono ?? (esSubcategoria ? '' : '📁');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tituloModal,
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      esSubcategoria
                          ? 'Agrega marcas, sabores o tamaños bajo esta categoría'
                          : 'Crea una familia general de productos para tu tienda',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 18),

                    // Selector de emoji si es principal
                    if (!esSubcategoria) ...[
                      const Text(
                        'Ícono / Emoji identificador:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _emojisSugeridos.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final emoji = _emojisSugeridos[index];
                            final seleccionado = iconoSeleccionado == emoji;
                            return InkWell(
                              onTap: () => setModalState(() => iconoSeleccionado = emoji),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: seleccionado ? AppColors.primary.withAlpha(30) : AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: seleccionado ? AppColors.primary : AppColors.border,
                                    width: seleccionado ? 2 : 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(emoji, style: const TextStyle(fontSize: 22)),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Campo de Nombre
                    TextField(
                      controller: nombreCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: esSubcategoria ? 'Nombre de la subcategoría (ej. Huari, Menta, 2 Litros)' : 'Nombre de la categoría (ej. Cervezas, Gaseosas)',
                        hintText: esSubcategoria ? 'Ej. Huari 710cc o Menta' : 'Ej. Cervezas',
                        prefixIcon: Icon(esSubcategoria ? Icons.subdirectory_arrow_right : Icons.category, color: AppColors.primary),
                        filled: true,
                        fillColor: AppColors.surfaceMuted,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botón Guardar
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final nombre = nombreCtrl.text.trim();
                        if (nombre.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor ingresa un nombre.')),
                          );
                          return;
                        }

                        Navigator.pop(ctx);

                        if (categoriaParaEditar != null) {
                          // Actualizar
                          final actualizado = categoriaParaEditar.copyWith(
                            nombre: nombre,
                            icono: esSubcategoria ? null : iconoSeleccionado,
                          );
                          final exito = await ref.read(categoriasNotifierProvider.notifier).actualizarCategoria(actualizado);
                          if (mounted && exito) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.success,
                                content: Text('Categoría "$nombre" actualizada correctamente.'),
                              ),
                            );
                          }
                        } else {
                          // Crear
                          final creada = await ref.read(categoriasNotifierProvider.notifier).crearCategoria(
                                nombre: nombre,
                                parentId: categoriaPadre?.id,
                                icono: esSubcategoria ? null : iconoSeleccionado,
                              );
                          if (mounted && creada != null) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.success,
                                content: Text('"$nombre" agregada con éxito.'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 22),
                      label: Text(
                        categoriaParaEditar != null ? 'Guardar Cambios' : 'Crear y Guardar',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmarEliminarCategoria(CategoriaModel categoria) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            const SizedBox(width: 8),
            Text(categoria.esPrincipal ? '¿Eliminar Categoría?' : '¿Eliminar Subcategoría?'),
          ],
        ),
        content: Text(
          categoria.esPrincipal
              ? 'Se eliminará "${categoria.nombre}" y todas las subcategorías que contiene. Los productos mantendrán su nombre pero perderán esta clasificación.'
              : '¿Estás seguro de eliminar la subcategoría "${categoria.nombre}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              final exito = await ref.read(categoriasNotifierProvider.notifier).eliminarCategoria(categoria.id);
              if (mounted && exito) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.danger,
                    content: Text('"${categoria.nombre}" ha sido eliminada.'),
                  ),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final arbolAsync = ref.watch(arbolCategoriasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Categorías y Familias',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refrescar categorías',
            onPressed: () => ref.invalidate(arbolCategoriasProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Búsqueda
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: AppColors.surface,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar categoría o subcategoría...',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _filtroTexto.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.danger),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _filtroTexto = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              onChanged: (val) => setState(() => _filtroTexto = val.trim().toLowerCase()),
            ),
          ),
          const Divider(height: 1),

          // Lista de Categorías en Árbol
          Expanded(
            child: arbolAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 50, color: AppColors.danger),
                      const SizedBox(height: 12),
                      Text('Error al cargar categorías: $e', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.refresh(arbolCategoriasProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (categorias) {
                // Filtrado por búsqueda
                final filtradas = categorias.where((padre) {
                  if (_filtroTexto.isEmpty) return true;
                  if (padre.nombre.toLowerCase().contains(_filtroTexto)) return true;
                  return padre.subcategorias.any((sub) => sub.nombre.toLowerCase().contains(_filtroTexto));
                }).toList();

                if (filtradas.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.category_outlined, size: 64, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            _filtroTexto.isEmpty ? 'No tienes categorías registradas aún' : 'No se encontraron coincidencias',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _filtroTexto.isEmpty
                                ? 'Crea tus categorías principales (ej. Cervezas, Gaseosas, Coca) para organizar tu tienda.'
                                : 'Intenta con otro término de búsqueda.',
                            style: const TextStyle(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          if (_filtroTexto.isEmpty)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                              onPressed: () => _abrirModalCrearOEditarCategoria(),
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text('Crear Primera Categoría', style: TextStyle(color: Colors.white)),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                  itemCount: filtradas.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final padre = filtradas[index];
                    final subs = padre.subcategorias;

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: _filtroTexto.isNotEmpty,
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              padre.iconoOEmoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                          title: Text(
                            padre.nombre,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '${subs.length} ${subs.length == 1 ? 'subcategoría' : 'subcategorías'}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: AppColors.secondary, size: 24),
                                tooltip: 'Agregar subcategoría',
                                onPressed: () => _abrirModalCrearOEditarCategoria(categoriaPadre: padre),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20, color: AppColors.textMuted),
                                onSelected: (val) {
                                  if (val == 'editar') {
                                    _abrirModalCrearOEditarCategoria(categoriaParaEditar: padre);
                                  } else if (val == 'eliminar') {
                                    _confirmarEliminarCategoria(padre);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'editar',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Editar Categoría'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'eliminar',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                        SizedBox(width: 8),
                                        Text('Eliminar', style: TextStyle(color: AppColors.danger)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          children: [
                            const Divider(height: 1),
                            if (subs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 18, color: AppColors.textMuted),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Sin subcategorías registradas.',
                                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _abrirModalCrearOEditarCategoria(categoriaPadre: padre),
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Agregar'),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: subs.length,
                                separatorBuilder: (_, _) => const Divider(height: 1, indent: 40),
                                itemBuilder: (context, subIndex) {
                                  final sub = subs[subIndex];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.only(left: 36, right: 12),
                                    leading: const Text('↳', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                                    title: Text(
                                      sub.nombre,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
                                          tooltip: 'Editar subcategoría',
                                          onPressed: () => _abrirModalCrearOEditarCategoria(categoriaParaEditar: sub),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                                          tooltip: 'Eliminar subcategoría',
                                          onPressed: () => _confirmarEliminarCategoria(sub),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        elevation: 4,
        onPressed: () => _abrirModalCrearOEditarCategoria(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nueva Categoría Principal',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }
}
