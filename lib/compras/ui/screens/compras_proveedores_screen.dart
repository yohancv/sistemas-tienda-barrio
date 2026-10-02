import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../cierre_caja/state/providers/caja_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../inventario/data/models/producto_model.dart';
import '../../../inventario/state/providers/inventario_providers.dart';
import '../../data/models/compra_model.dart';
import '../../data/models/item_compra_model.dart';
import '../../data/models/proveedor_model.dart';
import '../../state/providers/compras_providers.dart';
import '../widgets/modal_detalle_compra.dart';
import '../widgets/modal_nuevo_proveedor.dart';

class ComprasProveedoresScreen extends ConsumerStatefulWidget {
  final int tabInicial;

  const ComprasProveedoresScreen({
    super.key,
    this.tabInicial = 0,
  });

  @override
  ConsumerState<ComprasProveedoresScreen> createState() =>
      _ComprasProveedoresScreenState();
}

class _ComprasProveedoresScreenState
    extends ConsumerState<ComprasProveedoresScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchProductoController = TextEditingController();
  final TextEditingController _searchProveedorController = TextEditingController();
  final TextEditingController _comprobanteController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();
  final TextEditingController _montoCajaController = TextEditingController();
  final TextEditingController _montoExternoController = TextEditingController();

  String _filtroTextoProducto = '';
  String _filtroTextoProveedor = '';

  // Fase 3: Sub-vista activa (0: Catálogo del Proveedor, 1: Orden de Compra)
  int _subTabCompra = 0;
  bool _expandirConStock = true;
  bool _buscarEnTodoElCatalogo = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.tabInicial,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchProductoController.dispose();
    _searchProveedorController.dispose();
    _comprobanteController.dispose();
    _observacionesController.dispose();
    _montoCajaController.dispose();
    _montoExternoController.dispose();
    super.dispose();
  }

  void _abrirModalNuevoProveedor([ProveedorModel? proveedor]) async {
    final res = await showModalBottomSheet<ProveedorModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalNuevoProveedor(proveedorParaEditar: proveedor),
    );

    if (res != null) {
      ref.read(carritoComprasProvider.notifier).seleccionarProveedor(res);
      ref.invalidate(proveedoresListProvider);
      setState(() => _subTabCompra = 0);
    }
  }

  void _abrirDetalleCompra(CompraModel compra) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalDetalleCompra(compra: compra),
    );
  }

  Future<void> _abrirWhatsApp(String? telefono, String empresa) async {
    if (telefono == null || telefono.trim().isEmpty) return;
    final telLimpio = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse(
        'https://wa.me/591$telLimpio?text=Hola%20buenas,%20le%20escribo%20de%20la%20tienda%20para%20coordinar%20el%20pedido%20de%20$empresa');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final carrito = ref.watch(carritoComprasProvider);
    final proveedoresAsync = ref.watch(proveedoresListProvider);
    final cajaTurnoAsync = ref.watch(cajaTurnoActivaProvider);
    final resumenCaja = ref.watch(resumenCajaTurnoProvider);

    final cajaTurno = cajaTurnoAsync.valueOrNull;
    final efectivoCajaDisponible = resumenCaja.valueOrNull?.montoEsperadoEfectivo ?? 0.0;

    if (carrito.metodoPago == 'PAGO_MIXTO') {
      if (_montoCajaController.text.isEmpty && carrito.montoCaja > 0) {
        _montoCajaController.text = carrito.montoCaja.toStringAsFixed(2);
      }
      if (_montoExternoController.text.isEmpty && carrito.montoExterno > 0) {
        _montoExternoController.text = carrito.montoExterno.toStringAsFixed(2);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Proveedores y Compras',
          style: AppTypography.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.secondary,
          indicatorWeight: 3.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(
              icon: Badge(
                isLabelVisible: carrito.items.isNotEmpty,
                label: Text('${carrito.items.length}'),
                backgroundColor: AppColors.secondary,
                textColor: Colors.white,
                child: const Icon(Icons.shopping_cart_checkout),
              ),
              text: 'Nueva Compra',
            ),
            const Tab(
              icon: Icon(Icons.business_rounded),
              text: 'Proveedores',
            ),
            const Tab(
              icon: Icon(Icons.history_rounded),
              text: 'Historial',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ================================================================
          // TAB 1: NUEVA COMPRA (REABASTECIMIENTO)
          // ================================================================
          _buildTabNuevaCompra(
            context: context,
            carrito: carrito,
            proveedoresAsync: proveedoresAsync,
            cajaTurnoId: cajaTurno?.id,
            efectivoCajaDisponible: efectivoCajaDisponible,
          ),

          // ================================================================
          // TAB 2: DIRECTORIO DE PROVEEDORES
          // ================================================================
          _buildTabDirectorioProveedores(context, proveedoresAsync),

          // ================================================================
          // TAB 3: HISTORIAL DE COMPRAS
          // ================================================================
          _buildTabHistorialCompras(context, proveedoresAsync),
        ],
      ),
    );
  }

  // ==========================================================================
  // WIDGETS TAB 1: NUEVA COMPRA (FASE 3: GUIADO POR PROVEEDOR)
  // ==========================================================================
  Widget _buildTabNuevaCompra({
    required BuildContext context,
    required CarritoComprasState carrito,
    required AsyncValue<List<ProveedorModel>> proveedoresAsync,
    required String? cajaTurnoId,
    required double efectivoCajaDisponible,
  }) {
    final todosLosProductosAsync = ref.watch(productosListProvider);
    final todosLosProductos = todosLosProductosAsync.valueOrNull ?? [];
    final unidadesEnCajasMap = ref.watch(unidadesEnEmpaquesPadreProvider);

    final bool tieneProveedor = carrito.proveedorSeleccionado != null;
    final String? provId = carrito.proveedorSeleccionado?.id;

    // Catálogo del proveedor (o de toda la tienda si es compra general o activó búsqueda global)
    final productosDelProveedor = (tieneProveedor && !_buscarEnTodoElCatalogo)
        ? todosLosProductos.where((p) => p.proveedorId == provId).toList()
        : todosLosProductos;

    // 1. Productos Faltantes / Que REALMENTE requieren compra a distribuidores
    // REGLA DE NEGOCIO: Si un producto tiene stock bajo en mostrador, pero la tienda aún dispone
    // de cajas/packs cerrados en almacén (bodega) y el total sumado supera el stock mínimo,
    // NO requiere compra al distribuidor (la necesidad se cubre desempacando unidades de cajas).
    final List<Producto> productosFaltantes = [];
    final List<Producto> productosConStock = [];

    for (final p in productosDelProveedor) {
      final unidadesEnAlmacen = unidadesEnCajasMap[p.id] ?? 0.0;
      final stockTotal = p.stockActual + unidadesEnAlmacen;
      if (p.esStockBajo && stockTotal <= p.stockMinimo) {
        productosFaltantes.add(p);
      } else {
        productosConStock.add(p);
      }
    }

    // Productos para el buscador
    final productosABuscar = _buscarEnTodoElCatalogo ? todosLosProductos : productosDelProveedor;

    return Column(
      children: [
        // 1. Selector de Proveedor
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: proveedoresAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => const Text('Error al cargar proveedores'),
                      data: (proveedores) {
                        final provSeleccionado = carrito.proveedorSeleccionado;
                        final yaExiste = provSeleccionado == null ||
                            proveedores.any((p) => p.id == provSeleccionado.id);

                        final listaProveedores = [
                          ...proveedores,
                          if (!yaExiste) provSeleccionado,
                        ];

                        final String? valorValido = listaProveedores
                                .any((p) => p.id == provSeleccionado?.id)
                            ? provSeleccionado?.id
                            : null;

                        return DropdownButtonFormField<String>(
                          key: ValueKey('prov_${valorValido ?? "ninguno"}'),
                          initialValue: valorValido,
                          decoration: InputDecoration(
                            labelText: 'Empresa Proveedora (Distribuidor)',
                            prefixIcon: const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          hint: const Text('Seleccionar proveedor (ej. CBN, Embol...)'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Compra General / Sin Proveedor Fijo'),
                            ),
                            ...listaProveedores.map(
                              (p) => DropdownMenuItem<String>(
                                value: p.id,
                                child: Text(p.nombreEmpresa, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                          onChanged: (id) {
                            if (id == null) {
                              ref.read(carritoComprasProvider.notifier).seleccionarProveedor(null);
                            } else {
                              final sel = listaProveedores.firstWhere((p) => p.id == id);
                              ref.read(carritoComprasProvider.notifier).seleccionarProveedor(sel);
                            }
                            setState(() => _subTabCompra = 0);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _abrirModalNuevoProveedor(),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 20),
                        SizedBox(width: 2),
                        Text('Nuevo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),

              // Chips de acceso rápido si aún no se ha seleccionado proveedor
              if (carrito.proveedorSeleccionado == null)
                proveedoresAsync.maybeWhen(
                  data: (proveedores) {
                    if (proveedores.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text(
                              'Empresas: ',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                            ...proveedores.take(6).map((p) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: ActionChip(
                                  avatar: const Icon(Icons.business_outlined, size: 14, color: AppColors.primary),
                                  label: Text(p.nombreEmpresa, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  backgroundColor: AppColors.background,
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  onPressed: () {
                                    ref.read(carritoComprasProvider.notifier).seleccionarProveedor(p);
                                    setState(() => _subTabCompra = 0);
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),

              // Días de visita del proveedor seleccionado
              if (carrito.proveedorSeleccionado != null &&
                  carrito.proveedorSeleccionado!.tieneDiasVisita) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.event_available_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Visita del preventista: ${carrito.proveedorSeleccionado!.diasVisita}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // 2. Selector Segmentado: [Catálogo del Proveedor] vs [Orden de Compra]
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: _SegmentoBoton(
                  label: tieneProveedor
                      ? '📋 ${carrito.proveedorSeleccionado!.nombreEmpresa} (${productosDelProveedor.length})'
                      : '📋 Catálogo General (${todosLosProductos.length})',
                  seleccionado: _subTabCompra == 0,
                  onTap: () => setState(() => _subTabCompra = 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SegmentoBoton(
                  label: '🛒 Orden (${carrito.items.length}) • Bs. ${carrito.totalCompra.toStringAsFixed(2)}',
                  seleccionado: _subTabCompra == 1,
                  badgeColor: carrito.items.isNotEmpty ? AppColors.success : null,
                  onTap: () => setState(() => _subTabCompra = 1),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // 3. Contenido según el Sub-Tab activo
        Expanded(
          child: _subTabCompra == 0
              ? _buildVistaCatalogoProveedor(
                  context: context,
                  carrito: carrito,
                  tieneProveedor: tieneProveedor,
                  productosDelProveedor: productosDelProveedor,
                  productosFaltantes: productosFaltantes,
                  productosConStock: productosConStock,
                  productosABuscar: productosABuscar,
                )
              : _buildVistaOrdenCompra(
                  context: context,
                  carrito: carrito,
                  cajaTurnoId: cajaTurnoId,
                  efectivoCajaDisponible: efectivoCajaDisponible,
                  tieneProveedor: tieneProveedor,
                ),
        ),
      ],
    );
  }

  /// Sub-Vista 0: Catálogo del Proveedor (Stock Bajo con agregado en 1 clic + Con Stock)
  Widget _buildVistaCatalogoProveedor({
    required BuildContext context,
    required CarritoComprasState carrito,
    required bool tieneProveedor,
    required List<Producto> productosDelProveedor,
    required List<Producto> productosFaltantes,
    required List<Producto> productosConStock,
    required List<Producto> productosABuscar,
  }) {
    return Column(
      children: [
        // Buscador
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchProductoController,
                  decoration: InputDecoration(
                    hintText: tieneProveedor && !_buscarEnTodoElCatalogo
                        ? 'Buscar en ${carrito.proveedorSeleccionado!.nombreEmpresa}...'
                        : 'Buscar en todo el inventario...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _filtroTextoProducto.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchProductoController.clear();
                              setState(() => _filtroTextoProducto = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _filtroTextoProducto = val.toLowerCase().trim()),
                ),
              ),
              if (tieneProveedor) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: _buscarEnTodoElCatalogo ? 'Buscando en toda la tienda' : 'Buscando solo en esta empresa',
                  child: FilterChip(
                    label: Text(
                      _buscarEnTodoElCatalogo ? 'Toda la tienda' : 'Solo empresa',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _buscarEnTodoElCatalogo ? AppColors.warning : AppColors.primary,
                      ),
                    ),
                    selected: _buscarEnTodoElCatalogo,
                    selectedColor: AppColors.warning.withAlpha(25),
                    checkmarkColor: AppColors.warning,
                    onSelected: (val) => setState(() => _buscarEnTodoElCatalogo = val),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        // Lista de Productos
        Expanded(
          child: _filtroTextoProducto.isNotEmpty
              ? _buildListaBusqueda(
                  productos: productosABuscar,
                  carrito: carrito,
                )
              : _buildCatalogoCategorizado(
                  context: context,
                  carrito: carrito,
                  tieneProveedor: tieneProveedor,
                  productosDelProveedor: productosDelProveedor,
                  productosFaltantes: productosFaltantes,
                  productosConStock: productosConStock,
                ),
        ),

        // Barra inferior fija si hay productos agregados
        if (carrito.items.isNotEmpty)
          _buildBarraInferiorOrden(
            context: context,
            carrito: carrito,
            onVerOrden: () => setState(() => _subTabCompra = 1),
          ),
      ],
    );
  }

  /// Catálogo del Proveedor organizado en Stock Bajo (Faltantes) y Con Stock (Promos)
  Widget _buildCatalogoCategorizado({
    required BuildContext context,
    required CarritoComprasState carrito,
    required bool tieneProveedor,
    required List<Producto> productosDelProveedor,
    required List<Producto> productosFaltantes,
    required List<Producto> productosConStock,
  }) {
    final unidadesEnCajasMap = ref.watch(unidadesEnEmpaquesPadreProvider);

    if (tieneProveedor && productosDelProveedor.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Sin productos registrados para ${carrito.proveedorSeleccionado!.nombreEmpresa}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Para que aparezcan aquí automáticamente, asigna esta empresa como proveedora al crear o editar tus productos en el Catálogo.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => setState(() => _buscarEnTodoElCatalogo = true),
                icon: const Icon(Icons.search, color: Colors.white, size: 18),
                label: const Text('Buscar en todo el catálogo de la tienda', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      children: [
        // 🚨 SECCIÓN STOCK BAJO / FALTANTES
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: productosFaltantes.isNotEmpty
                ? AppColors.danger.withAlpha(15)
                : AppColors.success.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: productosFaltantes.isNotEmpty
                ? AppColors.danger.withAlpha(40)
                : AppColors.success.withAlpha(40),
            ),
          ),
          child: Row(
            children: [
              Icon(
                productosFaltantes.isNotEmpty ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                color: productosFaltantes.isNotEmpty ? AppColors.danger : AppColors.success,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🚨 Productos por Reabastecer (${productosFaltantes.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: productosFaltantes.isNotEmpty ? AppColors.danger : AppColors.success,
                      ),
                    ),
                    Text(
                      productosFaltantes.isNotEmpty
                          ? 'Artículos que requieren compra al proveedor (descontando almacén)'
                          : 'Existencias suficientes (cubiertas en tienda o almacén)',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (productosFaltantes.isNotEmpty)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    ref.read(carritoComprasProvider.notifier).agregarTodosLosFaltantes(
                          productosFaltantes,
                          unidadesEnAlmacenMap: unidadesEnCajasMap,
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text('Se agregaron ${productosFaltantes.length} productos faltantes a la orden.'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.flash_on, size: 16),
                  label: Text(
                    'Agregar todos (${productosFaltantes.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        if (productosFaltantes.isNotEmpty) ...[
          ...productosFaltantes.map((p) {
            final item = carrito.items.where((i) => i.productoId == p.id).firstOrNull;
            final unidadesEnAlmacen = unidadesEnCajasMap[p.id] ?? 0.0;
            final stockTotal = p.stockActual + unidadesEnAlmacen;
            final faltante = (p.stockMinimo - stockTotal) > 0
                ? (p.stockMinimo - stockTotal)
                : (p.tieneEmpaqueMayorista ? p.unidadesPorEmpaque : 1.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _CardProductoProveedor(
                producto: p,
                itemEnCarrito: item,
                esStockBajo: true,
                unidadesEnAlmacen: unidadesEnAlmacen,
                onAgregar: () {
                  ref.read(carritoComprasProvider.notifier).agregarProducto(p, cantidad: faltante);
                },
                onActualizarCantidad: (cant) {
                  ref.read(carritoComprasProvider.notifier).actualizarCantidad(p.id, cant);
                },
              ),
            );
          }),
          const SizedBox(height: 12),
        ],

        // 📦 SECCIÓN CON STOCK SUFICIENTE
        if (productosConStock.isNotEmpty) ...[
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expandirConStock = !_expandirConStock),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📦 Otros Productos con Stock (${productosConStock.length})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const Text(
                          'Promociones del camión (ej. 10+1), feriados o compra preventiva',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expandirConStock ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          if (_expandirConStock) ...[
            ...productosConStock.map((p) {
              final item = carrito.items.where((i) => i.productoId == p.id).firstOrNull;
              final unidadesEnAlmacen = unidadesEnCajasMap[p.id] ?? 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _CardProductoProveedor(
                  producto: p,
                  itemEnCarrito: item,
                  esStockBajo: false,
                  unidadesEnAlmacen: unidadesEnAlmacen,
                  onAgregar: () {
                    final cant = p.tieneEmpaqueMayorista ? p.unidadesPorEmpaque : 1.0;
                    ref.read(carritoComprasProvider.notifier).agregarProducto(p, cantidad: cant);
                  },
                  onActualizarCantidad: (cant) {
                    ref.read(carritoComprasProvider.notifier).actualizarCantidad(p.id, cant);
                  },
                ),
              );
            }),
          ],
        ],
      ],
    );
  }

  /// Lista de resultados cuando el usuario escribe en el buscador
  Widget _buildListaBusqueda({
    required List<Producto> productos,
    required CarritoComprasState carrito,
  }) {
    final unidadesEnCajasMap = ref.watch(unidadesEnEmpaquesPadreProvider);
    final filtrados = productos.where((p) {
      final n = p.nombre.toLowerCase();
      final b = p.codigoBarras?.toLowerCase() ?? '';
      final c = p.categoria?.toLowerCase() ?? '';
      return n.contains(_filtroTextoProducto) ||
          b.contains(_filtroTextoProducto) ||
          c.contains(_filtroTextoProducto);
    }).toList();

    if (filtrados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 10),
              Text(
                'No se encontraron productos para "$_filtroTextoProducto"',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              if (!_buscarEnTodoElCatalogo && carrito.proveedorSeleccionado != null)
                TextButton.icon(
                  onPressed: () => setState(() => _buscarEnTodoElCatalogo = true),
                  icon: const Icon(Icons.storefront, size: 16),
                  label: const Text('Buscar en todo el catálogo de la tienda'),
                ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: filtrados.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final p = filtrados[index];
        final item = carrito.items.where((i) => i.productoId == p.id).firstOrNull;
        final unidadesEnAlmacen = unidadesEnCajasMap[p.id] ?? 0.0;
        final stockTotal = p.stockActual + unidadesEnAlmacen;
        final esBajo = p.esStockBajo && stockTotal <= p.stockMinimo;
        final faltante = (p.stockMinimo - stockTotal) > 0
            ? (p.stockMinimo - stockTotal)
            : (p.tieneEmpaqueMayorista ? p.unidadesPorEmpaque : 1.0);

        return _CardProductoProveedor(
          producto: p,
          itemEnCarrito: item,
          esStockBajo: esBajo,
          unidadesEnAlmacen: unidadesEnAlmacen,
          onAgregar: () {
            ref.read(carritoComprasProvider.notifier).agregarProducto(p, cantidad: faltante);
          },
          onActualizarCantidad: (cant) {
            ref.read(carritoComprasProvider.notifier).actualizarCantidad(p.id, cant);
          },
        );
      },
    );
  }

  /// Barra flotante inferior fija en el catálogo para ir a revisar la orden
  Widget _buildBarraInferiorOrden({
    required BuildContext context,
    required CarritoComprasState carrito,
    required VoidCallback onVerOrden,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${carrito.items.length} productos (${carrito.totalArticulos.toInt()} uds)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    'Bs. ${carrito.totalCompra.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: onVerOrden,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Revisar Orden', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  /// Sub-Vista 1: Revisión y Pago de la Orden de Compra
  Widget _buildVistaOrdenCompra({
    required BuildContext context,
    required CarritoComprasState carrito,
    required String? cajaTurnoId,
    required double efectivoCajaDisponible,
    required bool tieneProveedor,
  }) {
    if (carrito.estaVacio) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_outlined, size: 70, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'La orden de compra está vacía',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                tieneProveedor
                    ? 'Ve a la pestaña del catálogo de ${carrito.proveedorSeleccionado!.nombreEmpresa} para agregar mercadería.'
                    : 'Explora el catálogo o selecciona un proveedor para abastecer tu inventario.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () => setState(() => _subTabCompra = 0),
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                label: const Text('Ver Catálogo y Faltantes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Barra superior de la orden con botón para regresar al catálogo
        Container(
          color: AppColors.background,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${carrito.items.length} productos en la orden (${carrito.totalArticulos.toInt()} uds)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => setState(() => _subTabCompra = 0),
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: const Text('+ Agregar más productos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Lista de ítems en la orden
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            itemCount: carrito.items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = carrito.items[index];
              return _CardItemCompra(
                item: item,
                onCantidadChanged: (c) => ref
                    .read(carritoComprasProvider.notifier)
                    .actualizarCantidad(item.productoId, c),
                onCostoChanged: (costo) => ref
                    .read(carritoComprasProvider.notifier)
                    .actualizarCosto(item.productoId, costo),
                onPrecioVentaChanged: (pv) => ref
                    .read(carritoComprasProvider.notifier)
                    .actualizarPrecioVenta(item.productoId, pv),
                onEliminar: () => ref
                    .read(carritoComprasProvider.notifier)
                    .eliminarItem(item.productoId),
              );
            },
          ),
        ),

        // Panel de Pago y Confirmación
        _buildPanelInferiorPago(
          context: context,
          carrito: carrito,
          cajaTurnoId: cajaTurnoId,
          efectivoCajaDisponible: efectivoCajaDisponible,
        ),
      ],
    );
  }

  // ==========================================================================
  // PANEL INFERIOR DE PAGO (CAJA vs. BILLETERA/ATM vs. MIXTO)
  // ==========================================================================
  Widget _buildPanelInferiorPago({
    required BuildContext context,
    required CarritoComprasState carrito,
    required String? cajaTurnoId,
    required double efectivoCajaDisponible,
  }) {
    final total = carrito.totalCompra;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Total de la orden
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total a Pagar (${carrito.items.length} artículos):',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                'Bs. ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Selector de Origen de Fondos
          const Text(
            'Origen del Dinero:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ChipMetodoPago(
                  label: '💵 Efectivo de Caja',
                  seleccionado: carrito.metodoPago == 'EFECTIVO_CAJA',
                  onTap: () => ref
                      .read(carritoComprasProvider.notifier)
                      .establecerMetodoPago('EFECTIVO_CAJA', efectivoCajaDisponible: efectivoCajaDisponible),
                ),
                const SizedBox(width: 6),
                _ChipMetodoPago(
                  label: '🏧 Dinero Propio / Cajero',
                  seleccionado: carrito.metodoPago == 'EFECTIVO_EXTERNO_ATM',
                  onTap: () => ref
                      .read(carritoComprasProvider.notifier)
                      .establecerMetodoPago('EFECTIVO_EXTERNO_ATM'),
                ),
                const SizedBox(width: 6),
                _ChipMetodoPago(
                  label: '📱 QR Personal',
                  seleccionado: carrito.metodoPago == 'QR_BANCO',
                  onTap: () => ref
                      .read(carritoComprasProvider.notifier)
                      .establecerMetodoPago('QR_BANCO'),
                ),
                const SizedBox(width: 6),
                _ChipMetodoPago(
                  label: '🔀 Pago Mixto',
                  seleccionado: carrito.metodoPago == 'PAGO_MIXTO',
                  onTap: () {
                    ref.read(carritoComprasProvider.notifier).establecerMetodoPago(
                          'PAGO_MIXTO',
                          efectivoCajaDisponible: efectivoCajaDisponible,
                        );
                    final c = ref.read(carritoComprasProvider);
                    _montoCajaController.text =
                        c.montoCaja > 0 ? c.montoCaja.toStringAsFixed(2) : '';
                    _montoExternoController.text =
                        c.montoExterno > 0 ? c.montoExterno.toStringAsFixed(2) : '';
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Alerta o campos según el método
          if (carrito.metodoPago == 'EFECTIVO_CAJA') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: (cajaTurnoId == null || efectivoCajaDisponible < total)
                    ? AppColors.warning.withAlpha(25)
                    : AppColors.success.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        (cajaTurnoId == null || efectivoCajaDisponible < total)
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        size: 18,
                        color: (cajaTurnoId == null || efectivoCajaDisponible < total)
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          cajaTurnoId == null
                              ? 'No hay caja abierta. Abre un turno o usa dinero propio / cajero.'
                              : 'Efectivo en cajón: Bs. ${efectivoCajaDisponible.toStringAsFixed(2)} ${efectivoCajaDisponible < total ? "(Insuficiente para Bs. ${total.toStringAsFixed(2)})" : "(Suficiente)"}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (cajaTurnoId == null || efectivoCajaDisponible < total)
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (cajaTurnoId != null && efectivoCajaDisponible < total && efectivoCajaDisponible > 0) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.call_split_rounded, size: 16, color: Colors.white),
                        label: Text(
                          'Sugerencia: Usar Pago Mixto (Caja Bs. ${efectivoCajaDisponible.toStringAsFixed(2)} + Externo Bs. ${(total - efectivoCajaDisponible).toStringAsFixed(2)})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        onPressed: () {
                          ref.read(carritoComprasProvider.notifier).establecerMetodoPago(
                                'PAGO_MIXTO',
                                efectivoCajaDisponible: efectivoCajaDisponible,
                              );
                          _montoCajaController.text = efectivoCajaDisponible.toStringAsFixed(2);
                          _montoExternoController.text = (total - efectivoCajaDisponible).toStringAsFixed(2);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (carrito.metodoPago == 'PAGO_MIXTO') ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _montoCajaController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Del Cajón (Caja)',
                      prefixText: 'Bs. ',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      helperText: cajaTurnoId != null
                          ? 'Máx disp: Bs. ${efectivoCajaDisponible.toStringAsFixed(2)}'
                          : 'Sin caja abierta',
                      helperStyle: TextStyle(
                        color: cajaTurnoId != null ? AppColors.textMuted : AppColors.danger,
                        fontSize: 11,
                      ),
                    ),
                    onChanged: (val) {
                      final c = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                      ref.read(carritoComprasProvider.notifier).establecerMontoCaja(c);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _montoExternoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Dinero Personal/ATM',
                      prefixText: 'Bs. ',
                      isDense: true,
                      border: OutlineInputBorder(),
                      helperText: 'Billetera, QR o Cajero',
                      helperStyle: TextStyle(fontSize: 11),
                    ),
                    onChanged: (val) {
                      final ext = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                      ref.read(carritoComprasProvider.notifier).establecerMontoExterno(ext);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Builder(
              builder: (_) {
                final suma = carrito.montoCaja + carrito.montoExterno;
                final diff = total - suma;
                final esExacto = diff.abs() < 0.02;

                if (esExacto) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: AppColors.success),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Suma de pagos exacta: cubre el 100% de la compra.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          diff > 0
                              ? 'Faltan Bs. ${diff.toStringAsFixed(2)} para cubrir el total.'
                              : 'Excede el total por Bs. ${(-diff).toStringAsFixed(2)}.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () {
                          final nuevoExt = (total - carrito.montoCaja) > 0
                              ? (total - carrito.montoCaja)
                              : 0.0;
                          ref
                              .read(carritoComprasProvider.notifier)
                              .establecerMontoExterno(nuevoExt);
                        },
                        child: const Text('Auto-cuadrar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 10),

          // Botón Confirmar Compra
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: carrito.isLoading
                  ? null
                  : () async {
                      // Validación anticipada de sugerencia Pago Mixto
                      if (carrito.metodoPago == 'EFECTIVO_CAJA' &&
                          cajaTurnoId != null &&
                          efectivoCajaDisponible < total) {
                        final aplicarMixto = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Row(
                              children: [
                                Icon(Icons.savings_outlined, color: AppColors.warning),
                                SizedBox(width: 8),
                                Text('Efectivo Insuficiente'),
                              ],
                            ),
                            content: Text(
                              'El cajón solo tiene Bs. ${efectivoCajaDisponible.toStringAsFixed(2)}, insuficiente para cubrir el total de Bs. ${total.toStringAsFixed(2)}.\n\n¿Deseas aplicar Pago Mixto automáticamente usando Bs. ${efectivoCajaDisponible.toStringAsFixed(2)} del cajón y Bs. ${(total - efectivoCajaDisponible).toStringAsFixed(2)} de dinero externo/cajero?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Aplicar Pago Mixto', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );

                        if (aplicarMixto == true) {
                          ref.read(carritoComprasProvider.notifier).establecerMetodoPago(
                                'PAGO_MIXTO',
                                efectivoCajaDisponible: efectivoCajaDisponible,
                              );
                          _montoCajaController.text = efectivoCajaDisponible.toStringAsFixed(2);
                          _montoExternoController.text = (total - efectivoCajaDisponible).toStringAsFixed(2);
                        }
                        return;
                      }

                      final ok = await ref
                          .read(carritoComprasProvider.notifier)
                          .confirmarCompra(
                            cajaTurnoId: cajaTurnoId,
                            efectivoCajaDisponible: efectivoCajaDisponible,
                          );

                      if (context.mounted) {
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.success,
                              content: Text(ref.read(carritoComprasProvider).successMessage ?? '¡Compra registrada!'),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          _tabController.animateTo(2); // Ir al historial
                        } else {
                          final err = ref.read(carritoComprasProvider).errorMessage;
                          if (err != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.danger,
                                content: Text(err),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      }
                    },
              icon: carrito.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline, color: Colors.white, size: 24),
              label: Text(
                carrito.isLoading ? 'Procesando Compra...' : 'Confirmar Ingreso de Mercadería',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // WIDGETS TAB 2: DIRECTORIO DE PROVEEDORES
  // ==========================================================================
  Widget _buildTabDirectorioProveedores(
    BuildContext context,
    AsyncValue<List<ProveedorModel>> proveedoresAsync,
  ) {
    return Column(
      children: [
        // Buscador de Proveedores y Botón Crear
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchProveedorController,
                  decoration: InputDecoration(
                    hintText: 'Buscar proveedor o preventista...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState(() => _filtroTextoProveedor = val.toLowerCase().trim()),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _abrirModalNuevoProveedor(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Nuevo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Lista de Proveedores
        Expanded(
          child: proveedoresAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error al cargar proveedores: $e')),
            data: (proveedores) {
              final filtrados = proveedores.where((p) {
                if (_filtroTextoProveedor.isEmpty) return true;
                final e = p.nombreEmpresa.toLowerCase();
                final c = p.nombreContacto?.toLowerCase() ?? '';
                final t = p.telefono?.toLowerCase() ?? '';
                return e.contains(_filtroTextoProveedor) || c.contains(_filtroTextoProveedor) || t.contains(_filtroTextoProveedor);
              }).toList();

              if (filtrados.isEmpty) {
                return const Center(child: Text('No hay proveedores registrados.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: filtrados.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final p = filtrados[index];
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  p.nombreEmpresa,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_note_rounded, color: AppColors.textSecondary),
                                tooltip: 'Editar Proveedor',
                                onPressed: () => _abrirModalNuevoProveedor(p),
                              ),
                            ],
                          ),
                          if (p.nombreContacto != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(p.nombreContacto!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                          if (p.tieneDiasVisita) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_month_outlined, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Visita: ${p.diasVisita}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (p.telefono != null && p.telefono!.isNotEmpty) ...[
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  onPressed: () => _abrirWhatsApp(p.telefono, p.nombreEmpresa),
                                  icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366), size: 16),
                                  label: Text(p.telefono!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                              ],
                              const Spacer(),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                onPressed: () {
                                  ref.read(carritoComprasProvider.notifier).seleccionarProveedor(p);
                                  setState(() => _subTabCompra = 0);
                                  _tabController.animateTo(0); // Ir a pestaña de nueva compra
                                },
                                icon: const Icon(Icons.add_shopping_cart, size: 16, color: Colors.white),
                                label: const Text('Comprar', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ],
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
    );
  }

  // ==========================================================================
  // WIDGETS TAB 3: HISTORIAL DE COMPRAS
  // ==========================================================================
  Widget _buildTabHistorialCompras(
    BuildContext context,
    AsyncValue<List<ProveedorModel>> proveedoresAsync,
  ) {
    final historialAsync = ref.watch(historialComprasProvider);

    return Column(
      children: [
        // Barra superior con botón refrescar
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Notas de Compra y Entregas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                tooltip: 'Refrescar Historial',
                onPressed: () => ref.invalidate(historialComprasProvider),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Listado de compras pasadas
        Expanded(
          child: historialAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error al cargar historial: $e')),
            data: (compras) {
              if (compras.isEmpty) {
                return const Center(child: Text('No hay compras registradas aún.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: compras.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final c = compras[index];
                  final d = c.fechaCompra;
                  final fechaStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _abrirDetalleCompra(c),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.receipt_long, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.nombreProveedor ?? 'Compra General',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$fechaStr  •  ${c.etiquetaMetodoPago}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Bs. ${c.totalCompra.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Row(
                                  children: [
                                    Text('Ver detalle', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// COMPONENTES AUXILIARES
// ============================================================================

class _ChipMetodoPago extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final VoidCallback onTap;

  const _ChipMetodoPago({
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: seleccionado ? AppColors.primary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: seleccionado ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: seleccionado ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de ítem en la lista de compra con edición de cantidad, costo y nuevo precio de venta
class _CardItemCompra extends StatelessWidget {
  final ItemCompraModel item;
  final ValueChanged<double> onCantidadChanged;
  final ValueChanged<double> onCostoChanged;
  final ValueChanged<double?> onPrecioVentaChanged;
  final VoidCallback onEliminar;

  const _CardItemCompra({
    required this.item,
    required this.onCantidadChanged,
    required this.onCostoChanged,
    required this.onPrecioVentaChanged,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.costoSubio
              ? AppColors.warning
              : (item.costoBajo ? AppColors.secondary : AppColors.border),
          width: (item.costoSubio || item.costoBajo) ? 1.8 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila Superior: Nombre del producto, tipo de empaque y botón eliminar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nombreProducto,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.codigoBarras != null && item.codigoBarras!.isNotEmpty)
                      Text(
                        '#${item.codigoBarras}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.danger, size: 20),
                tooltip: 'Quitar de la compra (ej. camión no trajo stock)',
                onPressed: onEliminar,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fila Media: Controles de Cantidad y Costo Unitario
          Row(
            children: [
              // Controles de cantidad
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                    onPressed: () => onCantidadChanged(item.cantidad - 1),
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 36),
                    alignment: Alignment.center,
                    child: Text(
                      item.cantidad.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 22, color: AppColors.primary),
                    onPressed: () => onCantidadChanged(item.cantidad + 1),
                  ),
                ],
              ),
              const SizedBox(width: 8),

              // Costo Unitario
              Expanded(
                child: TextFormField(
                  initialValue: item.costoUnitario.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Costo Unit. (Bs.)',
                    prefixText: 'Bs. ',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) {
                    final c = double.tryParse(val);
                    if (c != null && c >= 0) onCostoChanged(c);
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Subtotal de la línea
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Subtotal', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  Text(
                    'Bs. ${item.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ],
          ),

          // Alerta de variación de costo y ajuste de precio de mostrador al público
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: item.costoSubio
                  ? AppColors.warning.withAlpha(15)
                  : (item.costoBajo ? AppColors.secondary.withAlpha(15) : AppColors.background),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: item.costoSubio
                    ? AppColors.warning.withAlpha(60)
                    : (item.costoBajo ? AppColors.secondary.withAlpha(60) : AppColors.border.withAlpha(70)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.costoSubio) ...[
                  Row(
                    children: [
                      const Icon(Icons.trending_up, size: 16, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Costo subió: Bs. ${item.costoAnterior.toStringAsFixed(2)} ➔ Bs. ${item.costoUnitario.toStringAsFixed(2)} (+Bs. ${item.deltaCosto.toStringAsFixed(2)})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ] else if (item.costoBajo) ...[
                  Row(
                    children: [
                      const Icon(Icons.trending_down, size: 16, color: AppColors.secondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Costo bajó: Bs. ${item.costoAnterior.toStringAsFixed(2)} ➔ Bs. ${item.costoUnitario.toStringAsFixed(2)} (-Bs. ${(-item.deltaCosto).toStringAsFixed(2)})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.sell_outlined, size: 15, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'P. Venta actual: Bs. ${item.precioVentaActual.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.nuevoPrecioVenta != null && item.nuevoPrecioVenta! > 0
                                ? 'Nuevo margen: ${item.margenEfectivo.toStringAsFixed(1)}%'
                                : 'Margen: ${item.margenConPrecioActual.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: item.margenPeligroso
                                  ? AppColors.danger
                                  : (item.margenEfectivo >= 20 ? AppColors.success : AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 130,
                      child: TextFormField(
                        initialValue: item.nuevoPrecioVenta != null ? item.nuevoPrecioVenta!.toStringAsFixed(2) : '',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Nuevo P. Venta',
                          prefixText: 'Bs. ',
                          hintText: item.precioVentaActual.toStringAsFixed(2),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                        onChanged: (val) {
                          final pv = double.tryParse(val.trim().replaceAll(',', '.'));
                          onPrecioVentaChanged(pv != null && pv > 0 ? pv : null);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de producto del catálogo del proveedor para agregar a la compra
class _CardProductoProveedor extends StatelessWidget {
  final Producto producto;
  final ItemCompraModel? itemEnCarrito;
  final bool esStockBajo;
  final double unidadesEnAlmacen;
  final VoidCallback onAgregar;
  final ValueChanged<double> onActualizarCantidad;

  const _CardProductoProveedor({
    required this.producto,
    required this.itemEnCarrito,
    required this.esStockBajo,
    this.unidadesEnAlmacen = 0.0,
    required this.onAgregar,
    required this.onActualizarCantidad,
  });

  @override
  Widget build(BuildContext context) {
    final stockTotal = producto.stockActual + unidadesEnAlmacen;
    final faltante = (producto.stockMinimo - stockTotal) > 0
        ? (producto.stockMinimo - stockTotal)
        : (producto.tieneEmpaqueMayorista ? producto.unidadesPorEmpaque : 1.0);

    final enOrden = itemEnCarrito != null;
    final cantEnOrden = itemEnCarrito?.cantidad ?? 0.0;

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: enOrden
              ? AppColors.primary
              : (esStockBajo ? AppColors.danger.withAlpha(80) : AppColors.border),
          width: enOrden ? 1.8 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Emoji indicador
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: esStockBajo
                    ? AppColors.danger.withAlpha(20)
                    : AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                Producto.emojiCategoria(producto.categoria),
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 12),

            // Información del Producto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (producto.categoria != null && producto.categoria!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      producto.subcategoria != null && producto.subcategoria!.isNotEmpty
                          ? '${producto.categoria} › ${producto.subcategoria}'
                          : producto.categoria!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 3),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      Text(
                        'Mostrador: ${producto.stockActual.toInt()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: esStockBajo ? AppColors.danger : AppColors.textSecondary,
                        ),
                      ),
                      if (unidadesEnAlmacen > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue.withAlpha(70), width: 0.8),
                          ),
                          child: Text(
                            '📦 +${unidadesEnAlmacen.toInt()} almacén',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      if (esStockBajo)
                        Text(
                          '(Mín. ${producto.stockMinimo.toInt()}) ➔ Faltan ${faltante.toInt()} uds',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger,
                          ),
                        )
                      else if (producto.esStockBajo && unidadesEnAlmacen > 0)
                        const Text(
                          '✅ Cubierto por almacén',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Costo: Bs. ${producto.costoMayorista.toStringAsFixed(2)}  •  P. Venta: Bs. ${producto.precioVenta.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Acción / Controles de Orden
            if (enOrden)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withAlpha(50)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18, color: AppColors.primary),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onActualizarCantidad(cantEnOrden - 1),
                    ),
                    Text(
                      cantEnOrden.toInt().toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onActualizarCantidad(cantEnOrden + 1),
                    ),
                  ],
                ),
              )
            else if (esStockBajo)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onAgregar,
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: Text(
                  '+${faltante.toInt()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onAgregar,
                icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                label: const Text(
                  'Añadir',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Botón estilizado para el selector segmentado de sub-pestañas
class _SegmentoBoton extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final VoidCallback onTap;
  final Color? badgeColor;

  const _SegmentoBoton({
    required this.label,
    required this.seleccionado,
    required this.onTap,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: seleccionado ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: seleccionado ? AppColors.primary : AppColors.border,
            width: seleccionado ? 1.5 : 1.0,
          ),
          boxShadow: seleccionado
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(40),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: seleccionado ? Colors.white : AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

