import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../punto_de_venta/data/models/item_carrito_model.dart';
import '../../../punto_de_venta/state/providers/carrito_providers.dart';
import '../../../punto_de_venta/ui/screens/ticket_screen.dart';
import '../../../punto_de_venta/ui/widgets/modal_venta_fraccionada.dart';
import '../../../punto_de_venta/ui/widgets/modal_venta_dual.dart';
import '../../../punto_de_venta/ui/widgets/modal_seleccionar_cantidad.dart';
import '../../../cierre_caja/ui/screens/cierre_caja_screen.dart';
import '../../data/models/producto_model.dart';
import '../../state/providers/inventario_providers.dart';
import 'lista_reposicion_screen.dart';
import 'kardex_screen.dart';
import '../../../compras/ui/screens/compras_proveedores_screen.dart';
import 'formulario_producto_screen.dart';
import '../../../cuentas_por_cobrar/state/providers/clientes_providers.dart';
import '../../../cuentas_por_cobrar/ui/screens/gestion_fiados_screen.dart';

class CatalogoScreen extends ConsumerStatefulWidget {
  const CatalogoScreen({super.key});

  @override
  ConsumerState<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends ConsumerState<CatalogoScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosFiltradosProvider);
    final totalProductosBase = ref.watch(productosListProvider).maybeWhen(
          data: (l) => l.length,
          orElse: () => 0,
        );
    final conteoBajos = ref.watch(conteoStockBajoProvider);
    final conteoDeudores = ref.watch(conteoDeudoresProvider);
    final soloStockBajo = ref.watch(filtroSoloStockBajoProvider);
    final totalArticulos = ref.watch(totalArticulosProvider);
    final totalMonto = ref.watch(totalCarritoProvider);
    final categoriasConteo = ref.watch(categoriasDisponiblesProvider);
    final categoriaSeleccionada = ref.watch(filtroCategoriaSeleccionadaProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Catálogo de Inventario',
          style: AppTypography.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: false,
        actions: [
          // Botón de acceso directo a la Lista de Reposición con Badge
          IconButton(
            icon: Badge(
              isLabelVisible: conteoBajos > 0,
              backgroundColor: AppColors.danger,
              label: Text(
                '$conteoBajos',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              child: const Icon(Icons.assignment_outlined, size: 28, color: Colors.white),
            ),
            tooltip: 'Lista de Reposición / Compras',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ListaReposicionScreen(),
                ),
              );
              ref.invalidate(productosListProvider);
            },
          ),

          // Botón de Proveedores y Compras de Mercadería
          IconButton(
            icon: const Icon(Icons.local_shipping_outlined, size: 28, color: Colors.white),
            tooltip: 'Proveedores y Compras',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ComprasProveedoresScreen(),
                ),
              );
              ref.invalidate(productosListProvider);
            },
          ),

          // Botón de Kardex e Historial de Movimientos
          IconButton(
            icon: const Icon(Icons.auto_stories_rounded, size: 28, color: Colors.white),
            tooltip: 'Kardex e Historial de Movimientos',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const KardexScreen(),
                ),
              );
              ref.invalidate(productosListProvider);
            },
          ),

          // Botón de Cuentas por Cobrar (Fiados y Deudores)
          IconButton(
            icon: Badge(
              isLabelVisible: conteoDeudores > 0,
              backgroundColor: AppColors.warning,
              textColor: Colors.black,
              label: Text(
                '$conteoDeudores',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              child: const Icon(Icons.people_alt_outlined, size: 28, color: Colors.white),
            ),
            tooltip: 'Fiados y Cuentas por Cobrar',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GestionFiadosScreen(),
                ),
              );
              ref.invalidate(productosListProvider);
            },
          ),

          // Botón de Cierre de Caja Ciego
          IconButton(
            icon: const Icon(Icons.point_of_sale, size: 28, color: Colors.white),
            tooltip: 'Cierre de Caja',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CierreCajaScreen(),
                ),
              );
              ref.invalidate(productosListProvider);
            },
          ),

          // Botón para Registrar Nuevo Producto
          IconButton(
            icon: const Icon(Icons.add_box_outlined, size: 28, color: Colors.white),
            tooltip: 'Nuevo Producto',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FormularioProductoScreen(),
                ),
              );
              ref.invalidate(productosListProvider);
            },
          ),

          // Menú con opciones adicionales (Productos retirados para reactivación)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
            tooltip: 'Más opciones',
            onSelected: (value) {
              if (value == 'retirados') {
                _mostrarProductosRetirados(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'retirados',
                child: Row(
                  children: [
                    Icon(Icons.restore, color: AppColors.warning),
                    SizedBox(width: 10),
                    Text('Productos Retirados', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de Búsqueda de alta accesibilidad
            Container(
              padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 8.0),
              color: AppColors.surface,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o código...',
                  hintStyle: const TextStyle(fontSize: 18.0, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search, size: 30, color: AppColors.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 28, color: AppColors.danger),
                          tooltip: 'Limpiar búsqueda',
                          onPressed: () {
                            _searchController.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2.5),
                  ),
                ),
                onChanged: (value) {
                  ref.read(searchQueryProvider.notifier).state = value;
                  setState(() {});
                },
              ),
            ),

            // Chips accesibles de filtrado rápido (Todos vs Por Reponer)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              color: AppColors.surface,
              child: Row(
                children: [
                  // Selector 'Todos'
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        ref.read(filtroSoloStockBajoProvider.notifier).state = false;
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: !soloStockBajo ? AppColors.primary : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !soloStockBajo ? AppColors.primary : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Todos ($totalProductosBase)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: !soloStockBajo ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Selector 'Por Reponer'
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        ref.read(filtroSoloStockBajoProvider.notifier).state = true;
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: soloStockBajo ? AppColors.danger : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: soloStockBajo ? AppColors.danger : AppColors.danger.withAlpha(90),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 20,
                              color: soloStockBajo ? Colors.white : AppColors.danger,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Por Reponer ($conteoBajos)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: soloStockBajo ? Colors.white : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Carrusel horizontal de Categorías de la Tienda (Fase 4)
            if (categoriasConteo.isNotEmpty)
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.only(left: 14.0, right: 14.0, bottom: 8.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Chip 'Todas las Categorías'
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          avatar: const Icon(Icons.apps_rounded, size: 16),
                          label: Text('Todas ($totalProductosBase)'),
                          selected: categoriaSeleccionada == null,
                          selectedColor: AppColors.primary.withAlpha(25),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: categoriaSeleccionada == null ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: categoriaSeleccionada == null ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: categoriaSeleccionada == null ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          onSelected: (_) {
                            ref.read(filtroCategoriaSeleccionadaProvider.notifier).state = null;
                          },
                        ),
                      ),
                      // Chips por cada categoría registrada
                      ...categoriasConteo.entries.map((entry) {
                        final catNombre = entry.key;
                        final catCantidad = entry.value;
                        final esSeleccionada = categoriaSeleccionada?.toLowerCase() == catNombre.toLowerCase();
                        final emoji = Producto.emojiCategoria(catNombre);

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            avatar: Text(emoji, style: const TextStyle(fontSize: 14)),
                            label: Text('$catNombre ($catCantidad)'),
                            selected: esSeleccionada,
                            selectedColor: AppColors.primary.withAlpha(25),
                            checkmarkColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: esSeleccionada ? AppColors.primary : AppColors.textPrimary,
                              fontWeight: esSeleccionada ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: esSeleccionada ? AppColors.primary : AppColors.border,
                              ),
                            ),
                            onSelected: (selected) {
                              ref.read(filtroCategoriaSeleccionadaProvider.notifier).state =
                                  selected ? catNombre : null;
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

            const Divider(height: 1, thickness: 1, color: AppColors.border),

            // Lista reactiva de productos filtrados
            Expanded(
              child: productosAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: AppColors.primary,
                  ),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 60, color: AppColors.danger),
                        const SizedBox(height: 16),
                        const Text(
                          'No se pudo cargar el inventario',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Verifica tu conexión a internet o intenta nuevamente.',
                          style: AppTypography.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            minimumSize: const Size(200, 56),
                          ),
                          onPressed: () => ref.refresh(productosListProvider),
                          icon: const Icon(Icons.refresh, color: Colors.white, size: 26),
                          label: Text('Reintentar', style: AppTypography.buttonText),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (productos) {
                  if (productos.isEmpty) {
                    if (soloStockBajo) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 64, color: AppColors.success),
                              const SizedBox(height: 16),
                              const Text(
                                '¡No hay productos por reponer!',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Todos los productos cuentan con existencias suficientes según su stock mínimo.',
                                style: AppTypography.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(180, 50),
                                  side: const BorderSide(color: AppColors.primary, width: 2),
                                ),
                                onPressed: () {
                                  ref.read(filtroSoloStockBajoProvider.notifier).state = false;
                                },
                                child: const Text(
                                  'Ver todos los productos',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                size: 64, color: AppColors.textMuted),
                            const SizedBox(height: 16),
                            const Text(
                              'No se encontraron productos',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Intenta con otra palabra o verifica si está registrado.',
                              style: AppTypography.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                minimumSize: const Size(200, 50),
                              ),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const FormularioProductoScreen(),
                                  ),
                                );
                                ref.invalidate(productosListProvider);
                              },
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text(
                                'Registrar nuevo producto',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      ref.invalidate(productosListProvider);
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), // Espacio para el FAB
                      itemCount: productos.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final producto = productos[index];
                        return _ProductoCard(producto: producto);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // Botón flotante extendido para ir al Ticket en Espera
      floatingActionButton: totalArticulos > 0
          ? Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FloatingActionButton.extended(
                backgroundColor: AppColors.success,
                elevation: 6,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TicketScreen(),
                    ),
                  );
                  ref.invalidate(productosListProvider);
                },
                icon: const Icon(Icons.shopping_cart_checkout, color: Colors.white, size: 30),
                label: Text(
                  'Ver Ticket (${totalArticulos.toStringAsFixed(totalArticulos.truncateToDouble() == totalArticulos ? 0 : 2)}) • Bs. ${totalMonto.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// Muestra un BottomSheet con los productos retirados (inactivos) para reactivación (Fase 6)
  void _mostrarProductosRetirados(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final inactivosAsync = ref.watch(productosInactivosProvider);

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.3,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.restore, color: AppColors.warning, size: 28),
                          const SizedBox(width: 10),
                          Text(
                            'Productos Retirados',
                            style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: inactivosAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error: $e')),
                        data: (inactivos) {
                          if (inactivos.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 64, color: AppColors.success),
                                    SizedBox(height: 16),
                                    Text(
                                      'No hay productos retirados',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Todos los productos están activos en el catálogo.',
                                      style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: inactivos.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final prod = inactivos[index];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            prod.nombre,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Bs. ${prod.precioVenta.toStringAsFixed(2)} · Stock: ${prod.stockActual.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.success,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () async {
                                          final resultado = await ref
                                              .read(productoOperacionProvider.notifier)
                                              .reactivarProducto(prod.id);

                                          if (resultado != null && context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                backgroundColor: AppColors.success,
                                                content: Text(
                                                  '¡"${resultado.nombre}" reactivado en el catálogo!',
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.restore, color: Colors.white, size: 20),
                                        label: const Text(
                                          'Reactivar',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Tarjeta de producto reactiva al Carrito con toque amplio
class _ProductoCard extends ConsumerWidget {
  final Producto producto;

  const _ProductoCard({required this.producto});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool stockBajo = producto.esStockBajo;
    final unidadesEnCajasMap = ref.watch(unidadesEnEmpaquesPadreProvider);
    final double unidadesEnCajas = unidadesEnCajasMap[producto.id] ?? 0.0;
    final bool tieneCajasEnAlmacen = unidadesEnCajas > 0;
    // Solo es alerta crítica si no hay cajas en bodega o el total sumando cajas sigue bajo
    final bool alertaCompraDistribuidor =
        stockBajo && (!tieneCajasEnAlmacen || (producto.stockActual + unidadesEnCajas <= producto.stockMinimo));

    final String unidadTexto = producto.esFraccionable ? 'kg/g' : 'uds';

    return Container(
      constraints: const BoxConstraints(minHeight: 80.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alertaCompraDistribuidor
              ? AppColors.danger
              : (tieneCajasEnAlmacen && stockBajo ? AppColors.secondary : AppColors.border),
          width: (alertaCompraDistribuidor || (tieneCajasEnAlmacen && stockBajo)) ? 2.0 : 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => KardexScreen(
                  productoIdInicial: producto.id,
                  nombreProductoInicial: producto.nombre,
                ),
              ),
            );
            ref.invalidate(productosListProvider);
          },
          onTap: () {
            // Ruta de decisión según tipo de producto
            if (producto.esFraccionable) {
              // Producto pesable (pollo, queso, carne, coca)
              // → Abrir modal de balanza / dinero rápido
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ModalVentaFraccionada(
                  producto: producto,
                  onAgregarAlTicket: (peso, totalCobrar) {
                    ref.read(carritoProvider.notifier).agregarFraccionado(
                      producto,
                      peso,
                      ModoVenta.porPeso,
                    );
                    _mostrarSnackAgregado(context, producto.nombre);
                  },
                ),
              );
            } else if (producto.permiteVentaSuelta) {
              // Producto con venta dual (cigarros, pastillas)
              // → Abrir modal cajetilla vs suelto
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ModalVentaDual(
                  producto: producto,
                  onSeleccionar: (resultado) {
                    if (resultado.esEmpaqueEntero) {
                      ref.read(carritoProvider.notifier).agregarProducto(producto);
                    } else {
                      ref.read(carritoProvider.notifier).agregarSuelto(
                        producto,
                        resultado.cantidadSuelta,
                      );
                    }
                    _mostrarSnackAgregado(context, producto.nombre);
                  },
                ),
              );
            } else {
              // Producto estándar (botella, paquete cerrado, lata, etc.)
              // → Abrir modal para elegir exactamente cuántas unidades vender con atajos y validación de stock
              final itemsCarrito = ref.read(carritoProvider);
              final itemExistente =
                  itemsCarrito.where((i) => i.producto.id == producto.id).firstOrNull;
              final inicial = itemExistente != null ? itemExistente.cantidad : 1.0;

              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ModalSeleccionarCantidad(
                  producto: producto,
                  unidadesEnCajas: unidadesEnCajas,
                  cantidadInicialEnCarrito: inicial,
                  onConfirmar: (cantidad) {
                    ref.read(carritoProvider.notifier).establecerCantidad(producto, cantidad);
                    _mostrarSnackAgregado(context, '${cantidad.toInt()} uds de ${producto.nombre}');
                  },
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ícono indicador grande
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: alertaCompraDistribuidor
                        ? AppColors.danger.withAlpha(25)
                        : (tieneCajasEnAlmacen && stockBajo
                            ? AppColors.secondary.withAlpha(20)
                            : AppColors.primary.withAlpha(20)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    tieneCajasEnAlmacen && stockBajo
                        ? Icons.inventory_2_outlined
                        : (producto.esFraccionable ? Icons.scale : Icons.local_drink),
                    size: 30,
                    color: alertaCompraDistribuidor
                        ? AppColors.danger
                        : (tieneCajasEnAlmacen && stockBajo ? AppColors.secondary : AppColors.primary),
                  ),
                ),
                const SizedBox(width: 14),

                // Información textual
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        producto.nombre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          if (alertaCompraDistribuidor)
                            const Padding(
                              padding: EdgeInsets.only(right: 2.0),
                              child: Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger),
                            ),
                          Text(
                            'Stock: ${producto.stockActual.toStringAsFixed(producto.esFraccionable ? 2 : 0)} $unidadTexto',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: alertaCompraDistribuidor ? FontWeight.w800 : FontWeight.w500,
                              color: alertaCompraDistribuidor ? AppColors.danger : AppColors.textSecondary,
                            ),
                          ),
                          if (producto.codigoBarras != null && producto.codigoBarras!.isNotEmpty)
                            Text(
                              '• #${producto.codigoBarras}',
                              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                      if (tieneCajasEnAlmacen && stockBajo) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.unarchive_outlined, size: 14, color: AppColors.secondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Hay ${unidadesEnCajas.toInt()} uds en almacén',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Precio de venta
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: 'Toca para cambiar precio rápido',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _mostrarDialogoCambiarPrecio(context, ref, producto),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Bs. ${producto.precioVenta.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_outlined, size: 15, color: AppColors.success),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Text(
                      'Precio venta',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botón Cambiar Precio rápido
                        Tooltip(
                          message: 'Cambiar precio rápido',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => _mostrarDialogoCambiarPrecio(context, ref, producto),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withAlpha(15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.success.withAlpha(50)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.price_change_outlined, size: 14, color: AppColors.success),
                                  SizedBox(width: 2),
                                  Text(
                                    'Precio',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Botón Kardex directo
                        Tooltip(
                          message: 'Ver Kardex',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => KardexScreen(
                                    productoIdInicial: producto.id,
                                    nombreProductoInicial: producto.nombre,
                                  ),
                                ),
                              );
                              ref.invalidate(productosListProvider);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primary.withAlpha(40)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_stories_outlined, size: 14, color: AppColors.primary),
                                  SizedBox(width: 2),
                                  Text(
                                    'Kardex',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Botón Editar
                        Tooltip(
                          message: 'Editar producto',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FormularioProductoScreen(
                                    productoParaEditar: producto,
                                  ),
                                ),
                              );
                              ref.invalidate(productosListProvider);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_note_rounded, size: 15, color: AppColors.textSecondary),
                                  SizedBox(width: 2),
                                  Text(
                                    'Editar',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Muestra feedback visual inmediato al agregar un producto al ticket
  void _mostrarSnackAgregado(BuildContext context, String nombreProducto) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Agregado: $nombreProducto',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Diálogo rápido para actualizar precio de venta (y costo si varió) sin abrir el formulario completo
  void _mostrarDialogoCambiarPrecio(
    BuildContext context,
    WidgetRef ref,
    Producto producto,
  ) {
    final precioCtrl = TextEditingController(
      text: producto.precioVenta.toStringAsFixed(2),
    );
    final costoCtrl = TextEditingController(
      text: producto.costoMayorista.toStringAsFixed(2),
    );
    bool actualizarCosto = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            final nuevoPrecio =
                double.tryParse(precioCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
            final costoAUsar = actualizarCosto
                ? (double.tryParse(costoCtrl.text.trim().replaceAll(',', '.')) ??
                    producto.costoMayorista)
                : producto.costoMayorista;
            final ganancia = nuevoPrecio - costoAUsar;
            final margen = nuevoPrecio > 0 ? (ganancia / nuevoPrecio) * 100 : 0.0;
            final markup = costoAUsar > 0 ? (ganancia / costoAUsar) * 100 : 0.0;

            void ajustarPrecio(double delta) {
              final actual = double.tryParse(
                      precioCtrl.text.trim().replaceAll(',', '.')) ??
                  producto.precioVenta;
              final nuevo = (actual + delta).clamp(0.0, 99999.0);
              precioCtrl.text = nuevo.toStringAsFixed(2);
              setStateDialog(() {});
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.price_change_rounded,
                        color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Cambiar Precio de Venta',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Nombre del producto
                    Text(
                      '${Producto.emojiCategoria(producto.categoria)} ${producto.nombre}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Costo actual: Bs. ${producto.costoMayorista.toStringAsFixed(2)}  •  Precio actual: Bs. ${producto.precioVenta.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const Divider(height: 20),

                    // Campo de Nuevo Precio de Venta
                    TextFormField(
                      controller: precioCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Nuevo Precio de Venta (Mostrador)',
                        prefixText: 'Bs. ',
                        border:
                            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppColors.surface,
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 10),

                    // Botones rápidos de ajuste
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _BotonDeltaPrecio(label: '+0.50', onTap: () => ajustarPrecio(0.50)),
                        _BotonDeltaPrecio(label: '+1.00', onTap: () => ajustarPrecio(1.00)),
                        _BotonDeltaPrecio(label: '+2.00', onTap: () => ajustarPrecio(2.00)),
                        _BotonDeltaPrecio(label: '+5.00', onTap: () => ajustarPrecio(5.00)),
                        _BotonDeltaPrecio(
                            label: '-0.50', esResta: true, onTap: () => ajustarPrecio(-0.50)),
                        _BotonDeltaPrecio(
                            label: '-1.00', esResta: true, onTap: () => ajustarPrecio(-1.00)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Checkbox para también actualizar costo de compra si varió
                    InkWell(
                      onTap: () => setStateDialog(() => actualizarCosto = !actualizarCosto),
                      child: Row(
                        children: [
                          Checkbox(
                            value: actualizarCosto,
                            activeColor: AppColors.primary,
                            onChanged: (val) =>
                                setStateDialog(() => actualizarCosto = val ?? false),
                          ),
                          const Expanded(
                            child: Text(
                              '¿También varió el costo de compra?',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (actualizarCosto) ...[
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: costoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style:
                            const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Nuevo Costo de Compra (Bs.)',
                          prefixText: 'Bs. ',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        onChanged: (_) => setStateDialog(() {}),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Caja de rentabilidad en tiempo real
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: nuevoPrecio < costoAUsar
                            ? AppColors.danger.withAlpha(20)
                            : (margen >= 20
                                ? AppColors.success.withAlpha(20)
                                : AppColors.warning.withAlpha(20)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: nuevoPrecio < costoAUsar
                              ? AppColors.danger
                              : (margen >= 20
                                  ? AppColors.success.withAlpha(50)
                                  : AppColors.warning.withAlpha(50)),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Ganancia neta x unidad:',
                                  style: TextStyle(fontSize: 12)),
                              Text(
                                'Bs. ${ganancia.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: ganancia < 0
                                      ? AppColors.danger
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Margen s/ venta:',
                                  style: TextStyle(fontSize: 12)),
                              Text(
                                '${margen.toStringAsFixed(1)}% (Markup: ${markup.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: margen < 10
                                      ? AppColors.danger
                                      : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          if (nuevoPrecio < costoAUsar) ...[
                            const SizedBox(height: 6),
                            const Text(
                              '⚠️ ¡Cuidado! El precio de venta es menor al costo de compra.',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.danger),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: nuevoPrecio <= 0
                      ? null
                      : () async {
                          Navigator.pop(dialogCtx);
                          final exito = await ref
                              .read(productoOperacionProvider.notifier)
                              .actualizarPrecioVenta(
                                producto,
                                nuevoPrecio,
                                nuevoCosto: actualizarCosto ? costoAUsar : null,
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor:
                                    exito ? AppColors.success : AppColors.danger,
                                content: Text(
                                  exito
                                      ? '✅ Precio de "${producto.nombre}" actualizado a Bs. ${nuevoPrecio.toStringAsFixed(2)}'
                                      : 'Error al actualizar precio',
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.save_outlined, color: Colors.white, size: 18),
                  label: const Text('Guardar Precio',
                      style:
                          TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BotonDeltaPrecio extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool esResta;

  const _BotonDeltaPrecio({
    required this.label,
    required this.onTap,
    this.esResta = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: esResta
              ? AppColors.danger.withAlpha(15)
              : AppColors.primary.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: esResta
                ? AppColors.danger.withAlpha(40)
                : AppColors.primary.withAlpha(40),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: esResta ? AppColors.danger : AppColors.primary,
          ),
        ),
      ),
    );
  }
}
