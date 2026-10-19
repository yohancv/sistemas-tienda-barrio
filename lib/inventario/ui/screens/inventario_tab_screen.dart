import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compras/ui/screens/compras_proveedores_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/models/producto_model.dart';
import '../../state/providers/inventario_providers.dart';
import '../widgets/modal_ajuste_rapido_producto.dart';
import 'formulario_producto_screen.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirModalAjuste(BuildContext context, Producto producto) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalAjusteRapidoProducto(producto: producto),
    );
  }

  void _abrirNuevoProducto(BuildContext context) {
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
    final query = _searchController.text.trim().toLowerCase();

    return Scaffold(
      backgroundColor: AppColors.background,
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
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  children: [
                    // Resumen Financiero del Negocio (Cuánto vale la tienda hoy)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withAlpha(210),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(30),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Bs. ${capitalTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(35),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${todosLosProductos.length} productos',
                                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (conteoFaltantes > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withAlpha(220),
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
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Buscar en inventario...',
                                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.primary),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: AppColors.surfaceMuted,
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
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
                              color: AppColors.secondary.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.secondary.withAlpha(70)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, color: AppColors.secondary, size: 18),
                                SizedBox(width: 4),
                                Text(
                                  'Nuevo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.secondary,
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
                              color: AppColors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary.withAlpha(60)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 18),
                                SizedBox(width: 4),
                                Text(
                                  'Compras',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.primary,
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
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: !_soloFaltantes ? Colors.white : AppColors.textPrimary,
                          ),
                          onSelected: (_) => setState(() => _soloFaltantes = false),
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
                          backgroundColor: AppColors.danger.withAlpha(15),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _soloFaltantes ? Colors.white : AppColors.danger,
                          ),
                          onSelected: (val) => setState(() => _soloFaltantes = val),
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
                            Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _soloFaltantes
                                  ? '¡Excelente! No hay productos con stock faltante'
                                  : 'No se encontraron productos',
                              style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                        itemCount: filtrados.length,
                        itemBuilder: (context, index) {
                          final prod = filtrados[index];
                          return _buildTarjetaTresPartes(context, prod);
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
  Widget _buildTarjetaTresPartes(BuildContext context, Producto producto) {
    final bultos = producto.empaquesCompletos;
    final sueltas = producto.unidadesSueltasRestantes;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: producto.esStockBajo
            ? BorderSide(color: AppColors.danger.withAlpha(120), width: 1.5)
            : BorderSide.none,
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
                      color: producto.esStockBajo ? AppColors.danger.withAlpha(20) : AppColors.success.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          producto.esStockBajo ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                          size: 14,
                          color: producto.esStockBajo ? AppColors.danger : AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          producto.esStockBajo ? 'STOCK BAJO (Mín: ${producto.stockMinimo.toInt()})' : 'STOCK NORMAL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: producto.esStockBajo ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chip para cambiar precio rápidamente
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withAlpha(50), width: 0.8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'P. Venta: Bs. ${producto.precioVenta.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_outlined, size: 12, color: AppColors.primary),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${producto.categoria ?? "General"} • ${producto.subcategoria ?? ""}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                        if (producto.codigoBarras != null && producto.codigoBarras!.isNotEmpty)
                          Text(
                            'Cód: #${producto.codigoBarras}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ),

                  Container(
                    width: 1,
                    height: 44,
                    color: Colors.grey.shade300,
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
                            color: bultos == 0 && producto.tieneEmpaqueMayorista ? AppColors.danger : AppColors.primary,
                          ),
                        ),
                        Text(
                          producto.tieneEmpaqueMayorista ? producto.nombreEmpaquePlural : 'Sin Empaque',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    width: 1,
                    height: 44,
                    color: Colors.grey.shade300,
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
                            color: producto.stockActual == 0 ? AppColors.danger : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          producto.esFraccionable ? producto.unidadMedida : 'Sueltas',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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
