import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../inventario/data/models/producto_model.dart';
import '../../../inventario/state/providers/inventario_providers.dart';
import '../../../inventario/ui/screens/formulario_producto_screen.dart';
import '../../../inventario/ui/screens/kardex_screen.dart';
import '../../data/models/item_carrito_model.dart';
import '../../state/providers/carrito_providers.dart';
import '../screens/ticket_screen.dart';
import '../widgets/modal_venta_fraccionada.dart';
import '../../../recargas/ui/widgets/modal_registro_recarga_rapida.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/theme/theme_provider.dart';

/// Pantalla del Apartado 1: Productos / Ventas (POS)
///
/// Implementa navegación jerárquica en cascada:
/// Nivel 1: Categorías (ej. Sodas, Cervezas, Licores, Abarrotes)
/// Nivel 2: Marcas dentro de la categoría (ej. Coca-Cola, Pepsi, Mendocina)
/// Nivel 3: Presentaciones de producto con tarjeta (imagen, toggle Paquete/Unidad, precio y botón +)
class VentasProductosScreen extends ConsumerStatefulWidget {
  const VentasProductosScreen({super.key});

  @override
  ConsumerState<VentasProductosScreen> createState() => _VentasProductosScreenState();
}

class _VentasProductosScreenState extends ConsumerState<VentasProductosScreen> {
  String? _categoriaSeleccionada;
  String? _marcaSeleccionada;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final Debouncer _debouncer = Debouncer(milliseconds: 220);
  String _debouncedQuery = '';

  // Guarda la opción de venta por defecto (Paquete vs Unidad) seleccionada para cada producto en pantalla
  final Map<String, ModoVenta> _modosVentaPorProducto = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _abrirModalRecargas() {
    AppHaptics.medium();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ModalRegistroRecargaRapida(),
    );
  }

  void _irACategoria(String categoria) {
    AppHaptics.selection();
    setState(() {
      _categoriaSeleccionada = categoria;
      _marcaSeleccionada = null;
    });
  }

  void _irAMarca(String marca) {
    AppHaptics.selection();
    setState(() {
      _marcaSeleccionada = marca;
    });
  }

  void _retroceder() {
    AppHaptics.light();
    setState(() {
      if (_marcaSeleccionada != null) {
        _marcaSeleccionada = null;
      } else if (_categoriaSeleccionada != null) {
        _categoriaSeleccionada = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosListProvider);
    final totalArticulos = ref.watch(totalArticulosProvider);
    final totalMonto = ref.watch(totalCarritoProvider);
    final esOscuro = ref.watch(esModoOscuroProvider);
    final query = _debouncedQuery;

    final bgColor = esOscuro ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          }
        },
        child: productosAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Error al cargar productos: $err', style: const TextStyle(color: AppColors.danger)),
            ),
          ),
          data: (todosLosProductos) {
            // Si hay búsqueda activa por texto, mostramos directamente los resultados filtrados
            if (query.isNotEmpty) {
              final resultados = todosLosProductos.where((p) {
                final n = p.nombre.toLowerCase();
                final c = (p.categoria ?? '').toLowerCase();
                final s = (p.subcategoria ?? '').toLowerCase();
                final b = (p.codigoBarras ?? '').toLowerCase();
                return n.contains(query) || c.contains(query) || s.contains(query) || b.contains(query);
              }).toList();

              return Column(
                children: [
                  _buildBarraBusqueda(esOscuro),
                  Expanded(child: _buildListaProductos(resultados, esOscuro)),
                  _buildBarraCobroFlotante(totalArticulos, totalMonto, esOscuro),
                ],
              );
            }

            // Flujo Jerárquico normal
            return Column(
              children: [
                _buildBarraBusqueda(esOscuro),
                _buildMigasDePan(esOscuro),
                Expanded(
                  child: _categoriaSeleccionada == null
                      ? _buildGridCategorias(todosLosProductos, esOscuro)
                      : (_marcaSeleccionada == null
                          ? _buildGridMarcas(todosLosProductos, _categoriaSeleccionada!, esOscuro)
                          : _buildPresentacionesMarca(todosLosProductos, _categoriaSeleccionada!, _marcaSeleccionada!, esOscuro)),
                ),
                _buildBarraCobroFlotante(totalArticulos, totalMonto, esOscuro),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBarraBusqueda(bool esOscuro) {
    final searchBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final inputBg = esOscuro ? AppColors.darkBackground : AppColors.surfaceMuted;
    final inputBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textMuted = esOscuro ? AppColors.darkTextMuted : AppColors.textMuted;

    return Container(
      color: searchBg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (val) {
                _debouncer.run(() {
                  if (mounted) setState(() => _debouncedQuery = val.trim().toLowerCase());
                });
              },
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, marca o código...',
                hintStyle: TextStyle(color: textMuted, fontSize: 13.5),
                prefixIcon: const Icon(Icons.search, color: AppColors.retailBlue, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, color: textMuted),
                        onPressed: () {
                          _searchController.clear();
                          _debouncer.run(() {});
                          setState(() => _debouncedQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.retailBlue, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFF005CA9),
            borderRadius: BorderRadius.circular(14),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _abrirModalRecargas,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withAlpha(40)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.phone_android_rounded, color: Colors.white, size: 19),
                    SizedBox(width: 5),
                    Text(
                      'Recarga',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMigasDePan(bool esOscuro) {
    if (_categoriaSeleccionada == null) return const SizedBox.shrink();

    final bg = esOscuro ? AppColors.darkSurface : AppColors.surfaceMuted;
    final textMuted = esOscuro ? AppColors.darkTextMuted : AppColors.textMuted;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bg,
      child: Row(
        children: [
          InkWell(
            onTap: () => setState(() {
              _categoriaSeleccionada = null;
              _marcaSeleccionada = null;
            }),
            child: Row(
              children: [
                const Icon(Icons.storefront, size: 18, color: AppColors.retailBlue),
                const SizedBox(width: 4),
                Text('Inicio', style: AppTypography.bodySmall.copyWith(color: AppColors.retailBlue, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, size: 18, color: textMuted),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => setState(() => _marcaSeleccionada = null),
            child: Text(
              _categoriaSeleccionada!,
              style: AppTypography.bodySmall.copyWith(
                color: _marcaSeleccionada == null ? textPrimary : AppColors.retailBlue,
                fontWeight: _marcaSeleccionada == null ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          if (_marcaSeleccionada != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 18, color: textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _marcaSeleccionada!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.retailBlue),
            tooltip: 'Retroceder',
            onPressed: _retroceder,
          ),
        ],
      ),
    );
  }

  Widget _buildGridCategorias(List<Producto> productos, bool esOscuro) {
    // Obtener categorías únicas con su conteo de productos
    final Map<String, int> conteoCat = {};
    for (final p in productos) {
      final c = p.categoria ?? 'Otros';
      conteoCat[c] = (conteoCat[c] ?? 0) + 1;
    }

    final categoriasOrdenadas = conteoCat.keys.toList()..sort();
    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textMuted = esOscuro ? AppColors.darkTextSecondary : AppColors.textMuted;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.92,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: categoriasOrdenadas.length,
      itemBuilder: (context, index) {
        final cat = categoriasOrdenadas[index];
        final emoji = Producto.emojiCategoria(cat);
        final cant = conteoCat[cat] ?? 0;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cardBorder),
          ),
          color: cardBg,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _irACategoria(cat),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 38)),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      cat,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: esOscuro ? Colors.white.withAlpha(15) : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cardBorder.withAlpha(100), width: 0.8),
                    ),
                    child: Text(
                      '$cant ${cant == 1 ? 'opción' : 'opciones'}',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridMarcas(List<Producto> productos, String categoria, bool esOscuro) {
    // Filtrar productos de esta categoría
    final prodsCat = productos.where((p) => (p.categoria ?? 'Otros') == categoria).toList();

    // Extraer marcas (subcategorías)
    final Map<String, int> conteoMarcas = {};
    for (final p in prodsCat) {
      final m = p.subcategoria ?? 'General';
      conteoMarcas[m] = (conteoMarcas[m] ?? 0) + 1;
    }

    final marcas = conteoMarcas.keys.toList()..sort();
    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textMuted = esOscuro ? AppColors.darkTextSecondary : AppColors.textMuted;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.92,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: marcas.length,
      itemBuilder: (context, index) {
        final marca = marcas[index];
        final cant = conteoMarcas[marca] ?? 0;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: esOscuro ? cardBorder : AppColors.retailBlue.withAlpha(70),
              width: 1.2,
            ),
          ),
          color: cardBg,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _irAMarca(marca),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.retailBlue.withAlpha(esOscuro ? 35 : 20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sell_outlined, color: AppColors.retailBlue, size: 26),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      marca,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: esOscuro ? Colors.white.withAlpha(15) : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cardBorder.withAlpha(100), width: 0.8),
                    ),
                    child: Text(
                      '$cant ${cant == 1 ? 'presentación' : 'presentaciones'}',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPresentacionesMarca(List<Producto> productos, String categoria, String marca, bool esOscuro) {
    final filtrados = productos.where((p) {
      return (p.categoria ?? 'Otros') == categoria && (p.subcategoria ?? 'General') == marca;
    }).toList();

    return _buildListaProductos(filtrados, esOscuro);
  }

  Widget _buildListaProductos(List<Producto> productos, bool esOscuro) {
    if (productos.isEmpty) {
      final textMuted = esOscuro ? AppColors.darkTextSecondary : AppColors.textMuted;
      return Center(
        child: Text('No hay productos disponibles en este apartado', style: TextStyle(color: textMuted, fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
      itemCount: productos.length,
      itemBuilder: (context, index) {
        final prod = productos[index];
        return _buildTarjetaProductoVenta(prod, esOscuro);
      },
    );
  }

  Widget _buildTarjetaProductoVenta(Producto producto, bool esOscuro) {
    final tieneOpcionesEmpaque = producto.permiteVentaEmpaque || producto.permiteVentaSuelta;
    final modoActual = _modosVentaPorProducto[producto.id] ?? ModoVenta.normal;

    // Calcular precio según el modo seleccionado
    double precioAMostrar = producto.precioVenta;
    String etiquetaModo = 'Por Unidad';

    if (producto.esFraccionable) {
      precioAMostrar = producto.precioVenta;
      etiquetaModo = 'Por ${producto.unidadMedida}';
    } else if (modoActual == ModoVenta.porEmpaqueMayorista && producto.permiteVentaEmpaque) {
      precioAMostrar = producto.precioVentaEmpaqueEfectivo;
      etiquetaModo = 'Por ${producto.nombreEmpaqueLegible} (${producto.unidadesPorEmpaque.toInt()} uds)';
    } else if (modoActual == ModoVenta.suelta && producto.permiteVentaSuelta) {
      precioAMostrar = producto.precioVentaSuelta;
      etiquetaModo = 'Por ${producto.nombreUnidadSuelta} suelto';
    }

    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textMuted = esOscuro ? AppColors.darkTextSecondary : AppColors.textMuted;
    final thumbBg = esOscuro ? AppColors.darkSurfaceMuted : AppColors.surfaceMuted;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorder),
      ),
      color: cardBg,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila superior: Imagen/Ícono + Nombre + 3 Puntos
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen o ícono temático
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: thumbBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Center(
                    child: Text(
                      Producto.emojiCategoria(producto.categoria),
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Nombre y categoría/marca
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producto.nombre,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${producto.categoria ?? "General"} • ${producto.subcategoria ?? ""}',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Stock: ${producto.stockLegibleDesglosado}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: producto.esStockBajo ? AppColors.danger : AppColors.retailGreen,
                        ),
                      ),
                    ],
                  ),
                ),

                // 3 Puntos: Editar y Kardex
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: textMuted),
                  color: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: cardBorder),
                  ),
                  onSelected: (val) {
                    if (val == 'editar') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => FormularioProductoScreen(productoParaEditar: producto)),
                      ).then((_) => ref.invalidate(productosListProvider));
                    } else if (val == 'kardex') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => KardexScreen(
                            productoIdInicial: producto.id,
                            nombreProductoInicial: producto.nombre,
                          ),
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'editar',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 20, color: AppColors.retailBlue),
                          const SizedBox(width: 8),
                          Text('Editar Producto', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'kardex',
                      child: Row(
                        children: [
                          const Icon(Icons.history, size: 20, color: AppColors.secondary),
                          const SizedBox(width: 8),
                          Text('Ver Kardex', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            const SizedBox(height: 8),

            // Selector interactivo de alto contraste: Paquete / Caja vs Unidad vs Suelto
            if (tieneOpcionesEmpaque && !producto.esFraccionable)
              _buildSelectorModoVenta(producto, modoActual, esOscuro),

            const SizedBox(height: 10),

            // Fila inferior: Precio dinámico + Badge explícito de modo + Botón AÑADIR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bs. ${precioAMostrar.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: esOscuro ? AppColors.darkSuccessBright : AppColors.retailGreen,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (esOscuro ? AppColors.darkAccent : AppColors.retailBlue).withAlpha(esOscuro ? 35 : 18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (esOscuro ? AppColors.darkAccent : AppColors.retailBlue).withAlpha(60),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              modoActual == ModoVenta.porEmpaqueMayorista
                                  ? Icons.inventory_2_rounded
                                  : (modoActual == ModoVenta.suelta ? Icons.grain_rounded : Icons.sell_outlined),
                              size: 13,
                              color: esOscuro ? AppColors.darkAccent : AppColors.retailBlue,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Venta: $etiquetaModo',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: esOscuro ? AppColors.darkAccent : AppColors.retailBlue,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Botón '+' amplio (touch target >= 48dp)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: esOscuro ? AppColors.darkAccent : AppColors.retailBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: Icon(Icons.add_shopping_cart_rounded, size: 20, color: esOscuro ? AppColors.darkTextPrimary : Colors.white),
                  label: Text(
                    'AÑADIR',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: esOscuro ? AppColors.darkTextPrimary : Colors.white,
                    ),
                  ),
                  onPressed: () => _agregarProductoAlTicket(producto, modoActual),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Selector de alto contraste con botones segmentados y confirmación visual
  Widget _buildSelectorModoVenta(Producto producto, ModoVenta modoActual, bool esOscuro) {
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final containerBg = esOscuro ? AppColors.darkBackground : const Color(0xFFF1F5F9);

    final List<_OpcionModoVenta> opciones = [];

    // 1. Empaque cerrado (Caja, Paquete, Fardo)
    if (producto.permiteVentaEmpaque) {
      final uds = producto.unidadesPorEmpaque.toInt();
      opciones.add(
        _OpcionModoVenta(
          modo: ModoVenta.porEmpaqueMayorista,
          icono: Icons.inventory_2_rounded,
          titulo: '${producto.nombreEmpaqueLegible} ($uds uds)',
        ),
      );
    }

    // 2. Unidad entera (Botella, Lata, Pieza)
    opciones.add(
      const _OpcionModoVenta(
        modo: ModoVenta.normal,
        icono: Icons.check_circle_rounded,
        titulo: 'Unidad',
      ),
    );

    // 3. Venta suelta (Cigarro suelto, etc.)
    if (producto.permiteVentaSuelta) {
      opciones.add(
        _OpcionModoVenta(
          modo: ModoVenta.suelta,
          icono: Icons.grain_rounded,
          titulo: '${producto.nombreUnidadSuelta} suelto',
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1.2),
      ),
      child: Row(
        children: opciones.map((op) {
          final seleccionado = modoActual == op.modo;
          final activeColor = esOscuro ? AppColors.darkAccent : AppColors.retailBlue;
          final activeTextColor = esOscuro ? AppColors.darkTextPrimary : Colors.white;
          final inactiveTextColor = esOscuro ? AppColors.darkTextSecondary : const Color(0xFF64748B);

          return Expanded(
            child: InkWell(
              onTap: () {
                AppHaptics.selection();
                setState(() {
                  _modosVentaPorProducto[producto.id] = op.modo;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: seleccionado ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: seleccionado
                      ? [
                          BoxShadow(
                            color: Colors.black.withAlpha(esOscuro ? 50 : 25),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      seleccionado ? Icons.check_circle_rounded : op.icono,
                      size: 16,
                      color: seleccionado ? activeTextColor : inactiveTextColor,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        op.titulo,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: seleccionado ? FontWeight.bold : FontWeight.w600,
                          color: seleccionado ? activeTextColor : inactiveTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _agregarProductoAlTicket(Producto producto, ModoVenta modo) {
    AppHaptics.light();
    if (producto.esFraccionable) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ModalVentaFraccionada(
          producto: producto,
          onAgregarAlTicket: (peso, totalCobrar) {
            AppHaptics.light();
            ref.read(carritoProvider.notifier).agregarFraccionado(producto, peso, ModoVenta.porPeso);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Añadido: ${producto.nombre} ($peso ${producto.unidadMedida})'),
                duration: const Duration(milliseconds: 900),
                backgroundColor: AppColors.primaryDark,
              ),
            );
          },
        ),
      );
      return;
    }

    String modoTexto = '1 Unidad';
    if (modo == ModoVenta.porEmpaqueMayorista) {
      ref.read(carritoProvider.notifier).agregarEmpaque(producto, 1.0);
      modoTexto = '1 ${producto.nombreEmpaqueLegible} (${producto.unidadesPorEmpaque.toInt()} uds)';
    } else if (modo == ModoVenta.suelta) {
      ref.read(carritoProvider.notifier).agregarSuelto(producto, 1.0);
      modoTexto = '1 ${producto.nombreUnidadSuelta} suelto';
    } else {
      ref.read(carritoProvider.notifier).agregarProducto(producto, 1.0);
      modoTexto = '1 Unidad';
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Añadido al ticket: $modoTexto de ${producto.nombre}'),
        duration: const Duration(milliseconds: 1100),
        backgroundColor: AppColors.primaryDark,
      ),
    );
  }

  Widget _buildBarraCobroFlotante(double totalArticulos, double totalMonto, bool esOscuro) {
    if (totalArticulos <= 0) return const SizedBox.shrink();

    final articulosTexto = totalArticulos == totalArticulos.roundToDouble()
        ? totalArticulos.toInt().toString()
        : totalArticulos.toStringAsFixed(1);

    final barBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final barBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textMuted = esOscuro ? AppColors.darkTextMuted : AppColors.textMuted;
    final textTotal = esOscuro ? AppColors.darkSuccessBright : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: barBg,
        border: Border(top: BorderSide(color: barBorder, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(esOscuro ? 45 : 12),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart, color: AppColors.retailBlue, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '$articulosTexto ${totalArticulos == 1 ? "artículo" : "artículos"}',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  'Bs. ${totalMonto.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: textTotal,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: esOscuro ? AppColors.darkSuccess : AppColors.retailGreen,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: Icon(Icons.receipt_long_rounded, size: 22, color: esOscuro ? AppColors.darkSuccessDark : Colors.white),
              label: Text(
                'VER TICKET',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: esOscuro ? AppColors.darkSuccessDark : Colors.white,
                ),
              ),
              onPressed: () {
                AppHaptics.medium();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TicketScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionModoVenta {
  final ModoVenta modo;
  final IconData icono;
  final String titulo;

  const _OpcionModoVenta({
    required this.modo,
    required this.icono,
    required this.titulo,
  });
}
