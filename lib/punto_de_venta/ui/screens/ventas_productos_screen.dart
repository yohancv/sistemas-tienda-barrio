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

  // Guarda la opción de venta por defecto (Paquete vs Unidad) seleccionada para cada producto en pantalla
  final Map<String, ModoVenta> _modosVentaPorProducto = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _irACategoria(String categoria) {
    setState(() {
      _categoriaSeleccionada = categoria;
      _marcaSeleccionada = null;
    });
  }

  void _irAMarca(String marca) {
    setState(() {
      _marcaSeleccionada = marca;
    });
  }

  void _retroceder() {
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
    final query = _searchController.text.trim().toLowerCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: productosAsync.when(
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
                _buildBarraBusqueda(),
                Expanded(child: _buildListaProductos(resultados)),
                _buildBarraCobroFlotante(totalArticulos, totalMonto),
              ],
            );
          }

          // Flujo Jerárquico normal
          return Column(
            children: [
              _buildBarraBusqueda(),
              _buildMigasDePan(),
              Expanded(
                child: _categoriaSeleccionada == null
                    ? _buildGridCategorias(todosLosProductos)
                    : (_marcaSeleccionada == null
                        ? _buildGridMarcas(todosLosProductos, _categoriaSeleccionada!)
                        : _buildPresentacionesMarca(todosLosProductos, _categoriaSeleccionada!, _marcaSeleccionada!)),
              ),
              _buildBarraCobroFlotante(totalArticulos, totalMonto),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBarraBusqueda() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, marca o código...',
          prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 26),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surfaceMuted,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildMigasDePan() {
    if (_categoriaSeleccionada == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceMuted,
      child: Row(
        children: [
          InkWell(
            onTap: () => setState(() {
              _categoriaSeleccionada = null;
              _marcaSeleccionada = null;
            }),
            child: Row(
              children: [
                const Icon(Icons.storefront, size: 18, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('Inicio', style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => setState(() => _marcaSeleccionada = null),
            child: Text(
              _categoriaSeleccionada!,
              style: AppTypography.bodySmall.copyWith(
                color: _marcaSeleccionada == null ? AppColors.textPrimary : AppColors.primary,
                fontWeight: _marcaSeleccionada == null ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          if (_marcaSeleccionada != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _marcaSeleccionada!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
            tooltip: 'Retroceder',
            onPressed: _retroceder,
          ),
        ],
      ),
    );
  }

  Widget _buildGridCategorias(List<Producto> productos) {
    // Obtener categorías únicas con su conteo de productos
    final Map<String, int> conteoCat = {};
    for (final p in productos) {
      final c = p.categoria ?? 'Otros';
      conteoCat[c] = (conteoCat[c] ?? 0) + 1;
    }

    final categoriasOrdenadas = conteoCat.keys.toList()..sort();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.15,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: categoriasOrdenadas.length,
      itemBuilder: (context, index) {
        final cat = categoriasOrdenadas[index];
        final emoji = Producto.emojiCategoria(cat);
        final cant = conteoCat[cat] ?? 0;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _irACategoria(cat),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 42)),
                  const SizedBox(height: 8),
                  Text(
                    cat,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$cant opciones',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridMarcas(List<Producto> productos, String categoria) {
    // Filtrar productos de esta categoría
    final prodsCat = productos.where((p) => (p.categoria ?? 'Otros') == categoria).toList();

    // Extraer marcas (subcategorías)
    final Map<String, int> conteoMarcas = {};
    for (final p in prodsCat) {
      final m = p.subcategoria ?? 'General';
      conteoMarcas[m] = (conteoMarcas[m] ?? 0) + 1;
    }

    final marcas = conteoMarcas.keys.toList()..sort();

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.25,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: marcas.length,
      itemBuilder: (context, index) {
        final marca = marcas[index];
        final cant = conteoMarcas[marca] ?? 0;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.primary.withAlpha(50), width: 1.5),
          ),
          color: Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _irAMarca(marca),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sell_outlined, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    marca,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$cant presentaciones',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPresentacionesMarca(List<Producto> productos, String categoria, String marca) {
    final filtrados = productos.where((p) {
      return (p.categoria ?? 'Otros') == categoria && (p.subcategoria ?? 'General') == marca;
    }).toList();

    return _buildListaProductos(filtrados);
  }

  Widget _buildListaProductos(List<Producto> productos) {
    if (productos.isEmpty) {
      return const Center(
        child: Text('No hay productos disponibles en este apartado', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
      itemCount: productos.length,
      itemBuilder: (context, index) {
        final prod = productos[index];
        return _buildTarjetaProductoVenta(prod);
      },
    );
  }

  Widget _buildTarjetaProductoVenta(Producto producto) {
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
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
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${producto.categoria ?? "General"} • ${producto.subcategoria ?? ""}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Stock: ${producto.stockLegibleDesglosado}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: producto.esStockBajo ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),

                // 3 Puntos: Editar y Kardex
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
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
                    const PopupMenuItem(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Editar Producto'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'kardex',
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 20, color: AppColors.secondary),
                          SizedBox(width: 8),
                          Text('Ver Kardex'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Selector Paquete vs Unidad (si aplica)
            if (tieneOpcionesEmpaque && !producto.esFraccionable)
              Row(
                children: [
                  if (producto.permiteVentaEmpaque) ...[
                    ChoiceChip(
                      label: Text(producto.nombreEmpaqueLegible),
                      selected: modoActual == ModoVenta.porEmpaqueMayorista,
                      selectedColor: AppColors.primary.withAlpha(30),
                      onSelected: (sel) {
                        if (sel) {
                          setState(() {
                            _modosVentaPorProducto[producto.id] = ModoVenta.porEmpaqueMayorista;
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Unidad'),
                      selected: modoActual == ModoVenta.normal,
                      selectedColor: AppColors.primary.withAlpha(30),
                      onSelected: (sel) {
                        if (sel) {
                          setState(() {
                            _modosVentaPorProducto[producto.id] = ModoVenta.normal;
                          });
                        }
                      },
                    ),
                  ],
                  if (producto.permiteVentaSuelta) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(producto.nombreUnidadSuelta),
                      selected: modoActual == ModoVenta.suelta,
                      selectedColor: AppColors.secondary.withAlpha(30),
                      onSelected: (sel) {
                        if (sel) {
                          setState(() {
                            _modosVentaPorProducto[producto.id] = ModoVenta.suelta;
                          });
                        }
                      },
                    ),
                  ],
                ],
              ),

            const SizedBox(height: 8),

            // Fila inferior: Precio dinámico + Botón '+'
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bs. ${precioAMostrar.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                    Text(
                      etiquetaModo,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),

                // Botón '+' amplio (touch target >= 48dp)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add, size: 22, color: Colors.white),
                  label: const Text('AÑADIR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  onPressed: () => _agregarProductoAlTicket(producto, modoActual),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _agregarProductoAlTicket(Producto producto, ModoVenta modo) {
    if (producto.esFraccionable) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ModalVentaFraccionada(
          producto: producto,
          onAgregarAlTicket: (peso, totalCobrar) {
            ref.read(carritoProvider.notifier).agregarFraccionado(producto, peso, ModoVenta.porPeso);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Añadido: ${producto.nombre} ($peso ${producto.unidadMedida})'),
                duration: const Duration(seconds: 1),
                backgroundColor: AppColors.primaryDark,
              ),
            );
          },
        ),
      );
      return;
    }

    if (modo == ModoVenta.porEmpaqueMayorista) {
      ref.read(carritoProvider.notifier).agregarEmpaque(producto, 1.0);
    } else if (modo == ModoVenta.suelta) {
      ref.read(carritoProvider.notifier).agregarSuelto(producto, 1.0);
    } else {
      ref.read(carritoProvider.notifier).agregarProducto(producto, 1.0);
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Añadido: ${producto.nombre}'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.primaryDark,
      ),
    );
  }

  Widget _buildBarraCobroFlotante(double totalArticulos, double totalMonto) {
    if (totalArticulos <= 0) return const SizedBox.shrink();

    final articulosTexto = totalArticulos == totalArticulos.roundToDouble()
        ? totalArticulos.toInt().toString()
        : totalArticulos.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 10,
            offset: const Offset(0, -3),
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
                    const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '$articulosTexto ${totalArticulos == 1 ? "artículo" : "artículos"}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                Text(
                  'Bs. ${totalMonto.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.payment, size: 22, color: Colors.white),
              label: const Text(
                'COBRAR',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              onPressed: () {
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
