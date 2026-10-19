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
import '../../theme/app_colors.dart';

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

  void _abrirNuevoProducto() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FormularioProductoScreen(),
      ),
    );
  }

  void _abrirProveedores() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ComprasProveedoresScreen(),
      ),
    );
  }

  void _abrirCategorias() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GestionCategoriasScreen(),
      ),
    );
  }

  void _abrirKardex() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const KardexScreen(),
      ),
    );
  }

  void _abrirMermasYDesempaque() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MovimientosInventarioScreen(),
      ),
    );
  }

  void _abrirNuevoCliente() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ModalNuevoCliente(),
    );
  }

  void _recargarTodo() {
    ref.invalidate(productosListProvider);
    ref.invalidate(clientesListProvider);
    ref.invalidate(arbolCategoriasProvider);
    ref.invalidate(cajaTurnoActivaProvider);
    ref.invalidate(resumenCajaTurnoProvider);
    ref.invalidate(totalDeudaCalleProvider);

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
        return 'LicorPOS • Ventas';
      case 1:
        return 'Control de Inventario';
      case 2:
        return 'Cuentas por Cobrar (Fiados)';
      case 3:
        return 'Arqueo & Finanzas';
      default:
        return 'LicorPOS';
    }
  }

  Color _colorBarraPorTab(int index) {
    if (index == 3) {
      return const Color(0xFF090D1A);
    }
    return AppColors.primaryDark;
  }

  @override
  Widget build(BuildContext context) {
    final conteoDeudores = ref.watch(conteoDeudoresProvider);

    return Scaffold(
      backgroundColor: _tabActual == 3 ? const Color(0xFF090D1A) : AppColors.background,
      appBar: AppBar(
        title: Text(
          _tituloPorTab(_tabActual),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: _colorBarraPorTab(_tabActual),
        elevation: 0,
        actions: [
          // Menú de 3 puntos (⋮) con opciones secundarias
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'Opciones y Administración',
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (valor) {
              switch (valor) {
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
                case 'recargar':
                  _recargarTodo();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'nuevo_producto',
                child: Row(
                  children: [
                    Icon(Icons.add_box_rounded, color: Color(0xFF00E676), size: 20),
                    SizedBox(width: 12),
                    Text('Nuevo Producto', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'proveedores',
                child: Row(
                  children: [
                    Icon(Icons.local_shipping_rounded, color: Color(0xFF00D2FF), size: 20),
                    SizedBox(width: 12),
                    Text('Proveedores y Compras', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'categorias',
                child: Row(
                  children: [
                    Icon(Icons.category_rounded, color: Color(0xFFFFB800), size: 20),
                    SizedBox(width: 12),
                    Text('Categorías y Marcas', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(
                value: 'kardex',
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, color: Color(0xFFB388FF), size: 20),
                    SizedBox(width: 12),
                    Text('Kardex de Movimientos', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'mermas',
                child: Row(
                  children: [
                    Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFFF5252), size: 20),
                    SizedBox(width: 12),
                    Text('Mermas y Bajas', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'nuevo_cliente',
                child: Row(
                  children: [
                    Icon(Icons.person_add_rounded, color: Color(0xFF64B5F6), size: 20),
                    SizedBox(width: 12),
                    Text('Nuevo Vecino / Cliente', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(
                value: 'recargar',
                child: Row(
                  children: [
                    Icon(Icons.sync_rounded, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text('Recargar Base Local SQLite', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabActual,
        children: _pantallas,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF090D1A),
          border: Border(
            top: BorderSide(color: Color(0xFF1E2844), width: 1),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: const Color(0xFF090D1A),
            indicatorColor: const Color(0xFF272A4E),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                );
              }
              return const TextStyle(
                color: Color(0xFF8B9CB5),
                fontWeight: FontWeight.w500,
                fontSize: 11,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Color(0xFF00D2FF), size: 24);
              }
              return const IconThemeData(color: Color(0xFF8B9CB5), size: 22);
            }),
          ),
          child: NavigationBar(
            selectedIndex: _tabActual,
            onDestinationSelected: (index) {
              setState(() => _tabActual = index);
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'Ventas & Voz',
              ),
              const NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2_rounded),
                label: 'Inventario',
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
              ),
              const NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart_rounded),
                label: 'Cierre & IA',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
