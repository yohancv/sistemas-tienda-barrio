import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../data/models/compra_model.dart';
import '../../data/models/item_compra_model.dart';
import '../../state/providers/compras_providers.dart';

/// Modal para ver el detalle completo de una compra histórica
class ModalDetalleCompra extends ConsumerWidget {
  final CompraModel compra;

  const ModalDetalleCompra({
    super.key,
    required this.compra,
  });

  String _formatearFecha(DateTime fecha) {
    final d = fecha.day.toString().padLeft(2, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    final y = fecha.year;
    final h = fecha.hour.toString().padLeft(2, '0');
    final min = fecha.minute.toString().padLeft(2, '0');
    return '$d/$m/$y  $h:$min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(comprasRepositoryProvider);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBg = esOscuro ? AppColors.darkBackground : AppColors.surfaceMuted;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textMuted = esOscuro ? AppColors.darkTextMuted : AppColors.textMuted;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de cabecera
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        compra.nombreProveedor ?? 'Compra a Proveedor',
                        style: AppTypography.headlineSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        _formatearFecha(compra.fechaCompra),
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Resumen financiero de la compra
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total de la Compra:',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    Text(
                      'Bs. ${compra.totalCompra.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Divider(height: 14, color: cardBorder),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      compra.etiquetaMetodoPago,
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                    if (compra.numeroComprobante != null)
                      Text(
                        'Comprobante: #${compra.numeroComprobante}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                  ],
                ),
                if (compra.montoPagadoCaja > 0 || compra.montoPagadoExterno > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (compra.montoPagadoCaja > 0)
                        Text(
                          'Caja: Bs. ${compra.montoPagadoCaja.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      if (compra.montoPagadoExterno > 0)
                        Text(
                          'Billetera/QR: Bs. ${compra.montoPagadoExterno.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                    ],
                  ),
                ],
                if (compra.observaciones != null && compra.observaciones!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Nota: ${compra.observaciones}',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Mercadería Recibida:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Lista de ítems ingresados
          Expanded(
            child: FutureBuilder<List<ItemCompraModel>>(
              future: repo.obtenerDetalleCompra(compra.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error al cargar detalle: ${snapshot.error}', style: TextStyle(color: textPrimary)),
                  );
                }

                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return Center(
                    child: Text('No hay ítems registrados en esta compra.', style: TextStyle(color: textMuted)),
                  );
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: cardBorder),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.nombreProducto,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.tieneEmpaqueMayorista
                                      ? '${item.cantidadEmpaques.toStringAsFixed(item.cantidadEmpaques % 1 == 0 ? 0 : 1)} ${item.nombreEmpaquePlural} (${item.cantidad.toInt()} uds)  x  Bs. ${item.costoPorEmpaque.toStringAsFixed(2)}'
                                      : '${item.cantidad.toStringAsFixed(0)} uds  x  Bs. ${item.costoUnitario.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: textSecondary,
                                  ),
                                ),
                                if (item.nuevoPrecioVenta != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Nuevo P. Venta: Bs. ${item.nuevoPrecioVenta!.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            'Bs. ${item.subtotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
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
      ),
    );
  }
}
