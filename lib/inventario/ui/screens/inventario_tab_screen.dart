import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compras/ui/screens/compras_proveedores_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/models/producto_model.dart';
import '../../state/providers/inventario_providers.dart';
import '../widgets/modal_ajuste_rapido_producto.dart';
import 'formulario_producto_screen.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/theme/theme_provider.dart';

/// Apartado 2: Inventario & Administración de la Tienda
///
/// Pantalla optimizada para control del capital del negocio y ajuste rápido de precios:
/// 1. Banner superior: Capital total invertido en mercadería (Bs.), conteo de productos y faltantes.
/// 2. Buscador rápido y filtros de stock bajo.
/// 3. Tarjeta en 3 partes limpias (Nombre | Cajas | Sueltas) con toque interactivo para
///    ajustar precios de venta, ver margen de ganancia o reportar mermas al instante.
class InventarioTabScreen extends ConsumerStatefulWidget {
  const InventarioTabScreen({super.key});

  @override
  ConsumerState<InventarioTabScreen> createState() => _InventarioTabScreenState();
}

class _InventarioTabScreenState extends ConsumerState<InventarioTabScreen> {
  bool _soloFaltantes = false;
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer = Debouncer(milliseconds: 220);
  String _debouncedQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _abrirModalAjuste(BuildContext context, Producto producto) {
    AppHaptics.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalAjusteRapidoProducto(producto: producto),
    );
  }

  void _abrirNuevoProducto(BuildContext context) {
    AppHaptics.medium();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FormularioProductoScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosListProvider);
    final esOscuro = ref.watch(esModoOscuroProvider);
    final query = _debouncedQuery;

    final bgColor = esOscuro ? AppColors.darkBackground : AppColors.background;
    final headerBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final headerBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final inputBg = esOscuro ? AppColors.darkBackground : AppColors.surfaceMuted;
    final inputBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textMuted = esOscuro ? AppColors.darkTextMuted : AppColors.textMuted;

    return Scaffold(
      backgroundColor: bgColor,
      body: productosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error al cargar inventario: $err', style: const TextStyle(color: AppColors.danger)),
        ),
        data: (todosLosProductos) {
          // Filtrado
          var filtrados = todosLosProductos.where((p) {
            if (_soloFaltantes && !p.esStockBajo) return false;
            if (query.isNotEmpty) {
              final n = p.nombre.toLowerCase();
              final c = (p.categoria ?? '').toLowerCase();
              final s = (p.subcategoria ?? '').toLowerCase();
              final b = (p.codigoBarras ?? '').toLowerCase();
              return n.contains(query) || c.contains(query) || s.contains(query) || b.contains(query);
            }
            return true;
          }).toList();

          final conteoFaltantes = todosLosProductos.where((p) => p.esStockBajo).length;
          final capitalTotal = todosLosProductos.fold<double>(
            0.0,
            (acc, p) => acc + (p.stockActual * p.costoMayorista),
          );

          return Column(
            children: [
              // 1. Cabecera con Métricas de Capital y Controles
              Container(
                decoration: BoxDecoration(
                  color: headerBg,
                  border: Border(bottom: BorderSide(color: headerBorder, width: 1.0)),
                ),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  children: [
                    // Resumen Financiero del Negocio (Banner Pure Clean Retail)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0F172A),
                            Color(0xFF1E293B),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF334155)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CAPITAL EN MERCADERÍA',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Bs. ${capitalTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withAlpha(25)),
                                ),
                                child: Text(
                                  '${todosLosProductos.length} productos',
                                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (conteoFaltantes > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withAlpha(230),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '⚠️ $conteoFaltantes por pedir',
                                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Fila: Buscador rápido + Botón Nuevo + Botón Compras
                    Row(
                      children: [
                        // Buscador
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                _debouncer.run(() {
                                  if (mounted) setState(() => _debouncedQuery = val.trim().toLowerCase());
                                });
                              },
                              style: TextStyle(fontSize: 14, color: textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Buscar en inventario...',
                                hintStyle: TextStyle(fontSize: 13, color: textMuted),
                                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.retailBlue),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear, size: 18, color: textMuted),
                                        onPressed: () {
                                          _searchController.clear();
                                          _debouncer.run(() {});
                                          setState(() => _debouncedQuery = '');
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: inputBg,
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: inputBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.retailBlue, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Botón Nuevo Producto
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _abrirNuevoProducto(context),
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: esOscuro ? AppColors.darkSurfaceMuted : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: esOscuro ? AppColors.darkBorderStrong : const Color(0xFFBFDBFE)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, color: AppColors.retailBlue, size: 18),
                                SizedBox(width: 4),
                                Text(
                                  'Nuevo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.retailBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Acceso directo a Compras
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            AppHaptics.medium();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ComprasProveedoresScreen(tabInicial: 0),
                              ),
                            );
                          },
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: esOscuro ? AppColors.darkSurfaceMuted : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: esOscuro ? AppColors.darkBorderStrong : AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_shipping_outlined, color: textPrimary, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  'Compras',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Chips de filtrado rápido
                    Row(
                      children: [
                        FilterChip(
                          visualDensity: VisualDensity.compact,
                          label: Text('Todos (${todosLosProductos.length})'),
                          selected: !_soloFaltantes,
                          selectedColor: esOscuro ? AppColors.darkAccent : AppColors.retailBlue,
                          backgroundColor: esOscuro ? AppColors.darkSurfaceMuted : const Color(0xFFF1F5F9),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: !_soloFaltantes ? Colors.white : textMuted,
                          ),
                          onSelected: (_) {
                            AppHaptics.selection();
                            setState(() => _soloFaltantes = false);
                          },
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          visualDensity: VisualDensity.compact,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: _soloFaltantes ? Colors.white : AppColors.danger,
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Text('Faltante o Por Faltar ($conteoFaltantes)'),
                            ],
                          ),
                          selected: _soloFaltantes,
                          selectedColor: AppColors.danger,
                          backgroundColor: esOscuro ? const Color(0xFF2D1219) : const Color(0xFFFEF2F2),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _soloFaltantes ? Colors.white : AppColors.danger,
                          ),
                          onSelected: (val) {
                            AppHaptics.selection();
                            setState(() => _soloFaltantes = val);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Lista de Tarjetas de Producto Táctiles
              Expanded(
                child: filtrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 60, color: textMuted),
                            const SizedBox(height: 12),
                            Text(
                              _soloFaltantes
                                  ? '¡Excelente! No hay productos con stock faltante'
                                  : 'No se encontraron productos',
                              style: TextStyle(fontSize: 15, color: textMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                        itemCount: filtrados.length,
                        itemBuilder: (context, index) {
                          final prod = filtrados[index];
                          return _buildTarjetaTresPartes(context, prod, esOscuro);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Tarjeta de Inventario interactiva dividida en 3 partes claras:
  /// Parte 1: Nombre del producto, precio de venta y botón de ajuste
  /// Parte 2: Número de cajas / paquetes
  /// Parte 3: Cantidad de sueltos
  Widget _buildTarjetaTresPartes(BuildContext context, Producto producto, bool esOscuro) {
    final bultos = producto.empaquesCompletos;
    final sueltas = producto.unidadesSueltasRestantes;

    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = producto.esStockBajo
        ? AppColors.danger.withAlpha(140)
        : (esOscuro ? AppColors.darkBorder : AppColors.border);
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textMuted = esOscuro ? AppColors.darkTextSecondary : AppColors.textMuted;
    final dividerColor = esOscuro ? AppColors.darkBorder : AppColors.border;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cardBorder,
          width: producto.esStockBajo ? 1.5 : 1.0,
        ),
      ),
      color: cardBg,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _abrirModalAjuste(context, producto),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Fila superior: Estado de stock y Precio de venta con chip de ajuste
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: producto.esStockBajo
                          ? (esOscuro ? const Color(0xFF2D1219) : const Color(0xFFFEF2F2))
                          : (esOscuro ? const Color(0xFF0F291E) : const Color(0xFFF0FDF4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          producto.esStockBajo ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                          size: 14,
                          color: producto.esStockBajo ? AppColors.danger : AppColors.retailGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          producto.esStockBajo ? 'STOCK BAJO (Mín: ${producto.stockMinimo.toInt()})' : 'STOCK NORMAL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: producto.esStockBajo ? AppColors.danger : AppColors.retailGreen,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chip para cambiar precio rápidamente
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: esOscuro ? AppColors.darkSurfaceMuted : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: esOscuro ? AppColors.darkBorderStrong : const Color(0xFFBFDBFE),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'P. Venta: Bs. ${producto.precioVenta.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.retailBlue,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_outlined, size: 12, color: AppColors.retailBlue),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Divider(height: 1, color: dividerColor),
              const SizedBox(height: 8),

              // CUADRO EN 3 PARTES:
              // [ 1. Nombre / Código ] | [ 2. Cajas / Paquetes ] | [ 3. Cantidad de Sueltos ]
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // PARTE 1: Nombre del producto
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          producto.nombre,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${producto.categoria ?? "General"} • ${producto.subcategoria ?? ""}',
                          style: TextStyle(fontSize: 11, color: textMuted),
                        ),
                        if (producto.codigoBarras != null && producto.codigoBarras!.isNotEmpty)
                          Text(
                            'Cód: #${producto.codigoBarras}',
                            style: TextStyle(fontSize: 11, color: textMuted),
                          ),
                      ],
                    ),
                  ),

                  Container(
                    width: 1,
                    height: 44,
                    color: dividerColor,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),

                  // PARTE 2: Número de Cajas / Paquetes
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Text(
                          producto.tieneEmpaqueMayorista ? '$bultos' : '—',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: bultos == 0 && producto.tieneEmpaqueMayorista ? AppColors.danger : AppColors.retailBlue,
                          ),
                        ),
                        Text(
                          producto.tieneEmpaqueMayorista ? producto.nombreEmpaquePlural : 'Sin Empaque',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: textMuted),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    width: 1,
                    height: 44,
                    color: dividerColor,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),

                  // PARTE 3: Cantidad de sueltos
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        Text(
                          producto.esFraccionable
                              ? producto.stockActual.toStringAsFixed(2)
                              : (producto.tieneEmpaqueMayorista ? '${sueltas.toInt()}' : '${producto.stockActual.toInt()}'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: producto.stockActual == 0 ? AppColors.danger : textPrimary,
                          ),
                        ),
                        Text(
                          producto.esFraccionable ? producto.unidadMedida : 'Sueltas',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
