import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../data/models/item_carrito_model.dart';
import '../../state/providers/carrito_providers.dart';
import '../../../inventario/state/providers/inventario_providers.dart';
import '../../../core/theme/theme_provider.dart';
import 'cobro_screen.dart';

class TicketScreen extends ConsumerWidget {
  const TicketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsCarrito = ref.watch(carritoProvider);
    final totalMonto = ref.watch(totalCarritoProvider);
    final esOscuro = ref.watch(esModoOscuroProvider);

    final bgColor = esOscuro ? AppColors.darkBackground : AppColors.background;
    final appBarBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final border = esOscuro ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Ticket en Espera',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: appBarBg,
        foregroundColor: textPrimary,
        elevation: 0,
        actions: [
          if (itemsCarrito.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, size: 26, color: AppColors.danger),
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
                color: appBarBg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(esOscuro ? 45 : 12),
                    offset: const Offset(0, -2),
                    blurRadius: 4,
                  ),
                ],
                border: Border(
                  top: BorderSide(color: border, width: 1.2),
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
                      Text(
                        'TOTAL A COBRAR:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Bs. ${totalMonto.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: esOscuro ? AppColors.darkSuccessBright : AppColors.retailGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Botón masivo para proceder al cobro
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: esOscuro ? AppColors.darkSuccess : AppColors.retailBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CobroScreen(totalAPagar: totalMonto),
                          ),
                        );
                      },
                      icon: Icon(Icons.payment, color: esOscuro ? AppColors.darkSuccessDark : Colors.white, size: 26),
                      label: Text(
                        'PROCEDER AL COBRO',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: esOscuro ? AppColors.darkSuccessDark : Colors.white,
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
}

/// Fila del ticket con botones táctiles masivos (+ y - de 40px)
class _ItemTicketTile extends ConsumerWidget {
  final ItemCarrito item;

  const _ItemTicketTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool esEmpaque = item.modoVenta == ModoVenta.porEmpaqueMayorista;
    final bool esSuelta = item.modoVenta == ModoVenta.suelta;
    final bool esFraccionable = item.producto.esFraccionable ||
        item.modoVenta == ModoVenta.porPeso ||
        item.modoVenta == ModoVenta.porDinero;

    final double step = (esEmpaque || esSuelta || !esFraccionable) ? 1.0 : 0.5;

    // Para venta suelta, la cantidad del usuario es cantidadSuelta (ej. 2 cigarros)
    final double cantidadActual = esSuelta ? item.cantidadSuelta : item.cantidad;

    final String cantidadFormateada = esFraccionable
        ? cantidadActual.toStringAsFixed(2)
        : cantidadActual.toInt().toString();

    final String unidadTexto = esEmpaque
        ? (item.cantidad == 1
            ? item.producto.nombreEmpaqueCorto
            : item.producto.nombreEmpaquePlural.toLowerCase())
        : (esSuelta
            ? item.producto.nombreUnidadSuelta
            : (esFraccionable ? 'kg' : 'uds'));

    final esOscuro = ref.watch(esModoOscuroProvider);
    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = esOscuro ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final btnBg = esOscuro ? AppColors.darkSurfaceMuted : AppColors.surfaceMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: esEmpaque
              ? AppColors.secondary
              : (esSuelta ? const Color(0xFFD97706) : cardBorder),
          width: (esEmpaque || esSuelta) ? 1.8 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Información del producto y precios
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (esEmpaque) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '📦 ${item.producto.nombreEmpaqueLegible}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ] else if (esSuelta) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(35),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '🚬 Suelto',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        item.producto.nombre,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  esEmpaque
                      ? '${item.producto.nombreEmpaqueLegible} (${item.producto.unidadesPorEmpaque.toInt()} uds): Bs. ${item.producto.precioVentaEmpaqueEfectivo.toStringAsFixed(2)}'
                      : (esSuelta
                          ? 'Suelto (${item.producto.nombreUnidadSuelta}): Bs. ${item.producto.precioVentaSuelta.toStringAsFixed(2)} c/u'
                          : (esFraccionable
                              ? 'Precio: Bs. ${item.producto.precioVenta.toStringAsFixed(2)} / ${item.producto.unidadMedida}'
                              : 'Unitario: Bs. ${item.producto.precioVenta.toStringAsFixed(2)}')),
                  style: TextStyle(fontSize: 14, color: textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Subtotal: Bs. ${item.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.retailGreen,
                  ),
                ),
              ],
            ),
          ),

          // Botonera táctil masiva (+ y - con íconos de 38px)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón Disminuir (-)
              IconButton(
                iconSize: 36,
                padding: const EdgeInsets.all(6),
                style: IconButton.styleFrom(
                  backgroundColor: btnBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                tooltip: 'Reducir cantidad',
                onPressed: () {
                  ref.read(carritoProvider.notifier).ajustarCantidadItem(
                        item,
                        cantidadActual - step,
                      );
                },
              ),

              // Indicador de Cantidad Grande
              Container(
                constraints: const BoxConstraints(minWidth: 46),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cantidadFormateada,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      unidadTexto,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: (esEmpaque || esSuelta) ? FontWeight.bold : FontWeight.normal,
                        color: esEmpaque
                            ? AppColors.secondary
                            : (esSuelta ? const Color(0xFFD97706) : textSecondary),
                      ),
                    ),
                  ],
                ),
              ),

              // Botón Aumentar (+)
              IconButton(
                iconSize: 36,
                padding: const EdgeInsets.all(6),
                style: IconButton.styleFrom(
                  backgroundColor: btnBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_circle, color: AppColors.retailGreen),
                tooltip: 'Aumentar cantidad',
                onPressed: () {
                  final unidadesEnCajasMap = ref.read(unidadesEnEmpaquesPadreProvider);
                  final double unidadesEnCajas = unidadesEnCajasMap[item.producto.id] ?? 0.0;
                  final double stockTotalDisponible = item.producto.stockActual + unidadesEnCajas;

                  if (esEmpaque) {
                    final double udsPorEmpaque = item.producto.unidadesPorEmpaque > 0
                        ? item.producto.unidadesPorEmpaque
                        : 1.0;
                    final double udsNecesarias = (item.cantidad + 1) * udsPorEmpaque;
                    if (udsNecesarias > stockTotalDisponible && stockTotalDisponible > 0) {
                      final maxEmpaques = (stockTotalDisponible ~/ udsPorEmpaque);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.danger,
                          content: Text(
                            'Stock máximo alcanzado: Solo hay $maxEmpaques ${item.producto.nombreEmpaquePlural.toLowerCase()} disponibles (${stockTotalDisponible.toInt()} uds totales).',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                  } else if (esSuelta) {
                    final double udsPorEmpaqueVenta = item.producto.unidadesEnEmpaqueVenta > 0
                        ? item.producto.unidadesEnEmpaqueVenta
                        : 1.0;
                    final double fraccionNecesaria = (item.cantidadSuelta + 1) / udsPorEmpaqueVenta;
                    if (fraccionNecesaria > stockTotalDisponible && stockTotalDisponible > 0) {
                      final maxSueltas = (stockTotalDisponible * udsPorEmpaqueVenta).toInt();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.danger,
                          content: Text(
                            'Stock máximo alcanzado: Solo hay $maxSueltas ${item.producto.nombreUnidadSuelta}s disponibles.',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                  } else {
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
                  }

                  ref.read(carritoProvider.notifier).ajustarCantidadItem(
                        item,
                        cantidadActual + step,
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
