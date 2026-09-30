import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../data/models/item_carrito_model.dart';
import '../../state/providers/carrito_providers.dart';
import '../../../inventario/state/providers/inventario_providers.dart';
import '../../../cierre_caja/state/providers/caja_providers.dart';
import '../../../cierre_caja/ui/screens/cierre_caja_screen.dart';
import 'cobro_screen.dart';

class TicketScreen extends ConsumerWidget {
  const TicketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsCarrito = ref.watch(carritoProvider);
    final totalMonto = ref.watch(totalCarritoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ticket en Espera',
          style: AppTypography.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          if (itemsCarrito.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, size: 30, color: Colors.white),
              tooltip: 'Vaciar Ticket',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('¿Vaciar el ticket?'),
                    content: const Text(
                      'Se borrarán todos los productos de este ticket.',
                      style: TextStyle(fontSize: 18),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                        onPressed: () {
                          ref.read(carritoProvider.notifier).limpiarCarrito();
                          Navigator.pop(context);
                        },
                        child: const Text('Vaciar', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: itemsCarrito.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.remove_shopping_cart, size: 70, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      const Text(
                        'El ticket está vacío',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Agrega productos desde el catálogo para continuar.',
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(220, 56),
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                        label: Text('Ir al Catálogo', style: AppTypography.buttonText),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: itemsCarrito.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = itemsCarrito[index];
                  return _ItemTicketTile(item: item);
                },
              ),
      ),

      // Bloque inferior de Resumen anclado y de alto contraste
      bottomNavigationBar: itemsCarrito.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
                border: const Border(
                  top: BorderSide(color: AppColors.border, width: 2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Monto Total Gigante para alta visibilidad
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text(
                        'TOTAL A COBRAR:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Bs. ${totalMonto.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 34, // Fuente gigante requerida
                          fontWeight: FontWeight.w900,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Botón masivo para proceder al cobro
                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () {
                        final hayCaja = ref.read(hayCajaAbiertaProvider);
                        if (!hayCaja) {
                          _mostrarAlertaCajaCerrada(context);
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CobroScreen(totalAPagar: totalMonto),
                          ),
                        );
                      },
                      icon: const Icon(Icons.payment, color: Colors.white, size: 30),
                      label: const Text(
                        'PROCEDER AL COBRO',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  void _mostrarAlertaCajaCerrada(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.point_of_sale, color: AppColors.warning, size: 30),
            SizedBox(width: 10),
            Text('Caja Cerrada', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Debes abrir un turno de caja con el fondo inicial en efectivo antes de registrar cobros y ventas.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CierreCajaScreen(),
                ),
              );
            },
            icon: const Icon(Icons.lock_open, color: Colors.white),
            label: const Text(
              'Abrir Caja Ahora',
              style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila del ticket con botones táctiles masivos (+ y - de 40px)
class _ItemTicketTile extends ConsumerWidget {
  final ItemCarrito item;

  const _ItemTicketTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double step = item.producto.esFraccionable ? 0.5 : 1.0;
    final String cantidadFormateada = item.cantidad.toStringAsFixed(
      item.producto.esFraccionable ? 2 : 0,
    );
    final String unidadTexto = item.producto.esFraccionable ? 'kg' : 'uds';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Información del producto y precios
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.producto.nombre,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Unitario: Bs. ${item.producto.precioVenta.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Subtotal: Bs. ${item.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),

          // Botonera táctil masiva (+ y - con íconos de 40px)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón Disminuir (-)
              IconButton(
                iconSize: 40,
                padding: const EdgeInsets.all(8),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceMuted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.remove_circle, color: AppColors.danger),
                tooltip: 'Reducir cantidad',
                onPressed: () {
                  ref.read(carritoProvider.notifier).ajustarCantidad(
                        item.producto.id,
                        item.cantidad - step,
                      );
                },
              ),

              // Indicador de Cantidad Grande
              Container(
                constraints: const BoxConstraints(minWidth: 50),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cantidadFormateada,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      unidadTexto,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),

              // Botón Aumentar (+)
              IconButton(
                iconSize: 40,
                padding: const EdgeInsets.all(8),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceMuted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_circle, color: AppColors.success),
                tooltip: 'Aumentar cantidad',
                onPressed: () {
                  final unidadesEnCajasMap = ref.read(unidadesEnEmpaquesPadreProvider);
                  final double unidadesEnCajas = unidadesEnCajasMap[item.producto.id] ?? 0.0;
                  final double stockTotalDisponible = item.producto.stockActual + unidadesEnCajas;

                  if (stockTotalDisponible > 0 && (item.cantidad + step) > stockTotalDisponible) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.danger,
                        content: Text(
                          'Stock máximo alcanzado: Solo hay ${stockTotalDisponible.toInt()} unidades disponibles.',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  ref.read(carritoProvider.notifier).ajustarCantidad(
                        item.producto.id,
                        item.cantidad + step,
                      );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
