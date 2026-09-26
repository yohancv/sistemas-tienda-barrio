import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../punto_de_venta/data/models/item_carrito_model.dart';
import '../../../punto_de_venta/state/providers/carrito_providers.dart';
import '../../../punto_de_venta/ui/screens/ticket_screen.dart';
import '../../../punto_de_venta/ui/widgets/modal_venta_fraccionada.dart';
import '../../../punto_de_venta/ui/widgets/modal_venta_dual.dart';
import '../../../cierre_caja/ui/screens/cierre_caja_screen.dart';
import '../../data/models/producto_model.dart';
import '../../state/providers/inventario_providers.dart';
import 'lista_reposicion_screen.dart';

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
    final soloStockBajo = ref.watch(filtroSoloStockBajoProvider);
    final totalArticulos = ref.watch(totalArticulosProvider);
    final totalMonto = ref.watch(totalCarritoProvider);

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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ListaReposicionScreen(),
                ),
              );
            },
          ),

          // Botón de Cierre de Caja Ciego
          IconButton(
            icon: const Icon(Icons.point_of_sale, size: 28, color: Colors.white),
            tooltip: 'Cierre de Caja',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CierreCajaScreen(),
                ),
              );
            },
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
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), // Espacio para el FAB
                    itemCount: productos.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final producto = productos[index];
                      return _ProductoCard(producto: producto);
                    },
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TicketScreen(),
                    ),
                  );
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
}

/// Tarjeta de producto reactiva al Carrito con toque amplio
class _ProductoCard extends ConsumerWidget {
  final Producto producto;

  const _ProductoCard({required this.producto});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool stockBajo = producto.esStockBajo;
    final String unidadTexto = producto.esFraccionable ? 'kg/g' : 'uds';

    return Container(
      constraints: const BoxConstraints(minHeight: 80.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: stockBajo ? AppColors.danger : AppColors.border,
          width: stockBajo ? 2.0 : 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
              // Producto estándar (botella, paquete cerrado)
              // → Agregar directamente al ticket
              ref.read(carritoProvider.notifier).agregarProducto(producto);
              _mostrarSnackAgregado(context, producto.nombre);
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
                    color: stockBajo
                        ? AppColors.danger.withAlpha(25)
                        : AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    producto.esFraccionable ? Icons.scale : Icons.local_drink,
                    size: 30,
                    color: stockBajo ? AppColors.danger : AppColors.primary,
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
                      Row(
                        children: [
                          if (stockBajo)
                            const Padding(
                              padding: EdgeInsets.only(right: 4.0),
                              child: Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.danger),
                            ),
                          Text(
                            'Stock: ${producto.stockActual.toStringAsFixed(producto.esFraccionable ? 2 : 0)} $unidadTexto',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: stockBajo ? FontWeight.w800 : FontWeight.w500,
                              color: stockBajo ? AppColors.danger : AppColors.textSecondary,
                            ),
                          ),
                          if (producto.codigoBarras != null && producto.codigoBarras!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• #${producto.codigoBarras}',
                              style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Precio de venta
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Bs. ${producto.precioVenta.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.success,
                      ),
                    ),
                    const Text(
                      'Precio venta',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
}
