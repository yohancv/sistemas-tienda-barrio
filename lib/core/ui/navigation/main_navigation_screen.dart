import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cierre_caja/state/providers/caja_providers.dart';
import '../../../cierre_caja/ui/screens/cierre_tab_screen.dart';
import '../../../compras/ui/screens/compras_proveedores_screen.dart';
import '../../../cuentas_por_cobrar/state/providers/clientes_providers.dart';
import '../../../cuentas_por_cobrar/ui/screens/fiados_tab_screen.dart';
import '../../../cuentas_por_cobrar/ui/widgets/modal_nuevo_cliente.dart';
import '../../../inventario/state/providers/categorias_providers.dart';
import '../../../inventario/state/providers/inventario_providers.dart';
import '../../../inventario/ui/screens/formulario_producto_screen.dart';
import '../../../inventario/ui/screens/gestion_categorias_screen.dart';
import '../../../inventario/ui/screens/inventario_tab_screen.dart';
import '../../../inventario/ui/screens/kardex_screen.dart';
import '../../../inventario/ui/screens/movimientos_inventario_screen.dart';
import '../../../punto_de_venta/ui/screens/ventas_productos_screen.dart';
import '../../../reportes/state/providers/reportes_providers.dart';
import '../../../reportes/ui/screens/dashboard_reportes_screen.dart';
import '../../../recargas/ui/screens/gestion_recargas_screen.dart';
import '../screens/centro_respaldos_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_provider.dart';
import '../../utils/app_haptics.dart';

/// Pantalla Principal con Navegación Inferior de 4 Pestañas:
/// 1. Productos / Ventas (POS con navegación jerárquica)
/// 2. Inventario (Control de cajas/sueltos y reabastecimiento)
/// 3. Fiados (Cuentas por cobrar y cobranza vecinal)
/// 4. Cierre de Caja & Finanzas (Arqueo, métricas y smart bot)
///
/// Incluye menú global de 3 puntos (⋮) en la esquina superior derecha
/// para acceder a gestiones secundarias: Nuevo Producto, Proveedores,
/// Categorías, Kardex, etc.
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _tabActual = 0;

  final List<Widget> _pantallas = const [
    VentasProductosScreen(),
    InventarioTabScreen(),
    FiadosTabScreen(),
    CierreTabScreen(),
  ];

  void _abrirNuevoProducto() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FormularioProductoScreen(),
      ),
    );
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  void _abrirProveedores() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ComprasProveedoresScreen(),
      ),
    );
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  void _abrirCategorias() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GestionCategoriasScreen(),
      ),
    );
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  void _abrirKardex() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const KardexScreen(),
      ),
    );
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  void _abrirReportesYMetricas() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DashboardReportesScreen(),
      ),
    );
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  void _abrirRecargasYServicios() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GestionRecargasScreen(),
      ),
    );
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  void _abrirMermasYDesempaque() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MovimientosInventarioScreen(),
      ),
    );
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  void _abrirNuevoCliente() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ModalNuevoCliente(),
    );
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  void _abrirCentroRespaldos() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CentroRespaldosScreen(),
      ),
    );
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  void _recargarTodo() {
    ref.invalidate(productosListProvider);
    ref.invalidate(clientesListProvider);
    ref.invalidate(arbolCategoriasProvider);
    ref.invalidate(cajaTurnoActivaProvider);
    ref.invalidate(resumenCajaTurnoProvider);
    ref.invalidate(totalDeudaCalleProvider);
    ref.invalidate(reporteDashboardProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Datos locales de SQLite actualizados correctamente'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _tituloPorTab(int index) {
    switch (index) {
      case 0:
        return 'Punto de Venta';
      case 1:
        return 'Control de Inventario';
      case 2:
        return 'Cuentas por Cobrar (Fiados)';
      case 3:
        return 'Caja & Finanzas';
      default:
        return 'Punto de Venta';
    }
  }

  @override
  Widget build(BuildContext context) {
    final conteoDeudores = ref.watch(conteoDeudoresProvider);
    final esOscuro = ref.watch(esModoOscuroProvider);

    final colorFondoScaffold = esOscuro ? AppColors.darkBackground : AppColors.background;
    final colorAppBar = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final colorTextoAppBar = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final colorIconosAppBar = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final colorBorde = esOscuro ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      backgroundColor: _tabActual == 3 && esOscuro ? AppColors.darkBackground : colorFondoScaffold,
      appBar: AppBar(
        title: Text(
          _tituloPorTab(_tabActual),
          style: TextStyle(
            color: colorTextoAppBar,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: colorAppBar,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: colorBorde,
            height: 1,
          ),
        ),
        actions: [
          // Conmutador rápido de Modo Claro / Modo Oscuro
          IconButton(
            icon: Icon(
              esOscuro ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: esOscuro ? const Color(0xFFFFB800) : AppColors.primary,
            ),
            tooltip: esOscuro ? 'Cambiar a Modo Claro (Pure Clean Retail)' : 'Cambiar a Modo Oscuro (Modern Slate Fintech)',
            onPressed: () {
              AppHaptics.selection();
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),

          // Acceso directo a Ganancias y Métricas
          IconButton(
            icon: Icon(Icons.analytics_rounded, color: colorIconosAppBar),
            tooltip: 'Ganancias y Métricas del Día',
            onPressed: _abrirReportesYMetricas,
          ),

          // Menú de 3 puntos (⋮) con opciones secundarias
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colorIconosAppBar),
            tooltip: 'Opciones y Administración',
            color: esOscuro ? const Color(0xFF1E293B) : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorBorde),
            ),
            onSelected: (valor) {
              switch (valor) {
                case 'reportes':
                  _abrirReportesYMetricas();
                  break;
                case 'recargas_servicios':
                  _abrirRecargasYServicios();
                  break;
                case 'nuevo_producto':
                  _abrirNuevoProducto();
                  break;
                case 'proveedores':
                  _abrirProveedores();
                  break;
                case 'categorias':
                  _abrirCategorias();
                  break;
                case 'kardex':
                  _abrirKardex();
                  break;
                case 'mermas':
                  _abrirMermasYDesempaque();
                  break;
                case 'nuevo_cliente':
                  _abrirNuevoCliente();
                  break;
                case 'respaldos':
                  _abrirCentroRespaldos();
                  break;
                case 'recargar':
                  _recargarTodo();
                  break;
              }
            },
            itemBuilder: (context) {
              final colorItem = esOscuro ? Colors.white : AppColors.textPrimary;
              return [
                PopupMenuItem(
                  value: 'reportes',
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_rounded, color: Color(0xFF00E676), size: 20),
                      const SizedBox(width: 12),
                      Text('Ganancias y Métricas', style: TextStyle(color: colorItem, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'recargas_servicios',
                  child: Row(
                    children: [
                      const Icon(Icons.phone_android_rounded, color: Color(0xFF38BDF8), size: 20),
                      const SizedBox(width: 12),
                      Text('Recargas & Paquetes', style: TextStyle(color: colorItem, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                PopupMenuItem(
                  value: 'nuevo_producto',
                  child: Row(
                    children: [
                      const Icon(Icons.add_box_rounded, color: Color(0xFF00E676), size: 20),
                      const SizedBox(width: 12),
                      Text('Nuevo Producto', style: TextStyle(color: colorItem)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'proveedores',
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping_rounded, color: Color(0xFF38BDF8), size: 20),
                      const SizedBox(width: 12),
                      Text('Proveedores y Compras', style: TextStyle(color: colorItem)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'categorias',
                  child: Row(
                    children: [
                      const Icon(Icons.category_rounded, color: Color(0xFFFFB800), size: 20),
                      const SizedBox(width: 12),
                      Text('Categorías y Marcas', style: TextStyle(color: colorItem)),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                PopupMenuItem(
                  value: 'kardex',
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, color: Color(0xFFB388FF), size: 20),
                      const SizedBox(width: 12),
                      Text('Kardex de Movimientos', style: TextStyle(color: colorItem)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'mermas',
                  child: Row(
                    children: [
                      const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFFF5252), size: 20),
                      const SizedBox(width: 12),
                      Text('Mermas y Bajas', style: TextStyle(color: colorItem)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'nuevo_cliente',
                  child: Row(
                    children: [
                      const Icon(Icons.person_add_rounded, color: Color(0xFF64B5F6), size: 20),
                      const SizedBox(width: 12),
                      Text('Nuevo Vecino / Cliente', style: TextStyle(color: colorItem)),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                PopupMenuItem(
                  value: 'respaldos',
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_sync_rounded, color: Color(0xFF38BDF8), size: 20),
                      const SizedBox(width: 12),
                      Text('Copias & Restauración (Backup)', style: TextStyle(color: colorItem, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 1),
                PopupMenuItem(
                  value: 'recargar',
                  child: Row(
                    children: [
                      Icon(Icons.sync_rounded, color: esOscuro ? Colors.white70 : AppColors.textMuted, size: 20),
                      const SizedBox(width: 12),
                      Text('Recargar Base Local SQLite', style: TextStyle(color: esOscuro ? Colors.white70 : AppColors.textMuted)),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabActual,
        children: _pantallas,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: esOscuro ? AppColors.darkSurface : AppColors.surface,
          border: Border(
            top: BorderSide(
              color: esOscuro ? AppColors.darkBorder : AppColors.border,
              width: 1,
            ),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: esOscuro ? AppColors.darkSurface : AppColors.surface,
            indicatorColor: esOscuro ? const Color(0x2638BDF8) : const Color(0xFFEFF6FF),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(
                  color: esOscuro ? AppColors.darkAccent : AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                );
              }
              return TextStyle(
                color: esOscuro ? AppColors.darkTextMuted : AppColors.textMuted,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return IconThemeData(
                  color: esOscuro ? AppColors.darkAccent : AppColors.primary,
                  size: 24,
                );
              }
              return IconThemeData(
                color: esOscuro ? AppColors.darkTextMuted : AppColors.textMuted,
                size: 22,
              );
            }),
          ),
          child: NavigationBar(
            elevation: 0,
            backgroundColor: esOscuro ? AppColors.darkSurface : AppColors.surface,
            selectedIndex: _tabActual,
            onDestinationSelected: (index) {
              AppHaptics.selection();
              setState(() => _tabActual = index);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'Ventas',
                tooltip: '',
              ),
              const NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2_rounded),
                label: 'Inventario',
                tooltip: '',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: conteoDeudores > 0,
                  label: Text(
                    conteoDeudores.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                  backgroundColor: const Color(0xFFE11D48),
                  child: const Icon(Icons.people_outline_rounded),
                ),
                selectedIcon: Badge(
                  isLabelVisible: conteoDeudores > 0,
                  label: Text(
                    conteoDeudores.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                  backgroundColor: const Color(0xFFE11D48),
                  child: const Icon(Icons.people_rounded),
                ),
                label: 'Fiados',
                tooltip: '',
              ),
              const NavigationDestination(
                icon: Icon(Icons.point_of_sale_outlined),
                selectedIcon: Icon(Icons.point_of_sale_rounded),
                label: 'Caja & Finanzas',
                tooltip: '',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
