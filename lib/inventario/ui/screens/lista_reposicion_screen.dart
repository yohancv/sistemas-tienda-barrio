import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../data/models/item_reposicion_model.dart';
import '../../state/providers/inventario_providers.dart';
import '../../state/providers/reposicion_providers.dart';
import '../../utils/pedido_formatter.dart';

class ListaReposicionScreen extends ConsumerWidget {
  const ListaReposicionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reposicionState = ref.watch(reposicionProvider);
    final productosBajos = ref.watch(productosStockBajoListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Lista de Reposición',
          style: AppTypography.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt, size: 28, color: Colors.white),
            tooltip: 'Restaurar cantidades sugeridas',
            onPressed: () {
              ref
                  .read(reposicionProvider.notifier)
                  .restaurarSugeridos(productosBajos);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cantidades restauradas según el stock mínimo.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner superior de inversión requerida
            _ResumenPresupuestoHeader(
              totalInversion: reposicionState.totalInversion,
              totalArticulos: reposicionState.totalArticulos,
              totalProductos: reposicionState.totalProductosDistintos,
            ),

            const Divider(height: 1, thickness: 1, color: AppColors.border),

            // Contenido principal: Lista de productos o estado vacío
            Expanded(
              child: reposicionState.estaVacia
                  ? _buildEmptyState(context)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      itemCount: reposicionState.items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = reposicionState.items[index];
                        return _ItemReposicionCard(item: item);
                      },
                    ),
            ),

            // Barra inferior con botones de acción masivos
            if (!reposicionState.estaVacia)
              _BarraAccionesPedido(
                items: reposicionState.items,
                totalInversion: reposicionState.totalInversion,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 56,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '¡Inventario al Día!',
              style: AppTypography.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'No hay productos que hayan alcanzado o superado el stock mínimo de reposición.',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(220, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              label: Text('Volver al Catálogo', style: AppTypography.buttonText),
            ),
          ],
        ),
      ),
    );
  }
}

/// Encabezado con el presupuesto estimado a invertir
class _ResumenPresupuestoHeader extends StatelessWidget {
  final double totalInversion;
  final double totalArticulos;
  final int totalProductos;

  const _ResumenPresupuestoHeader({
    required this.totalInversion,
    required this.totalArticulos,
    required this.totalProductos,
  });

  @override
  Widget build(BuildContext context) {
    final unidadesStr = totalArticulos
        .toStringAsFixed(totalArticulos.truncateToDouble() == totalArticulos ? 0 : 2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PRESUPUESTO ESTIMADO',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalProductos productos',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Bs. ${totalInversion.toStringAsFixed(2)}',
                style: AppTypography.headlineLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '($unidadesStr unidades)',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta accesible para cada ítem sugerido a comprar
class _ItemReposicionCard extends ConsumerWidget {
  final ItemReposicion item;

  const _ItemReposicionCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(reposicionProvider.notifier);
    final unidad = item.esFraccionable
        ? (item.producto.tipoEmpaque == 'LIBRA' ? 'libras' : 'kilos')
        : 'uds';
    const paso = 1.0;
    final etiquetaCompra = item.esEmpaqueado ? item.etiquetaUnidadCompra : '';

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila Superior: Nombre del producto y botón de descartar
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.nombre,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted, size: 26),
                tooltip: 'Quitar de la lista de compra',
                onPressed: () => notifier.descartarProducto(item.id),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Indicador de Stock Actual vs Mínimo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.danger.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.danger.withAlpha(70)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 20, color: AppColors.danger),
                const SizedBox(width: 6),
                Text(
                  'Stock actual: ${item.stockActual.toStringAsFixed(item.esFraccionable ? 2 : 0)} $unidad  •  Mínimo: ${item.stockMinimo.toStringAsFixed(item.esFraccionable ? 2 : 0)} $unidad',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Fila Inferior: Precios y Controles de Cantidad Masivos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Información de Costos Mayoristas
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.esEmpaqueado) ...[
                    Text(
                      'Costo: Bs. ${item.costoPorUnidadCompra.toStringAsFixed(2)} / ${etiquetaCompra.toLowerCase()}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Costo: Bs. ${item.costoMayorista.toStringAsFixed(2)} c/u',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    'Subtotal: Bs. ${item.subtotalEstimado.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                  if (item.esEmpaqueado) ...[
                    const SizedBox(height: 2),
                    Text(
                      '(= ${item.equivalenciaUnidadesSueltas.toStringAsFixed(0)} uds)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),

              // Controles de Cantidad con touch targets ≥ 56dp
              Row(
                children: [
                  // Botón Disminuir (-)
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: const BorderSide(color: AppColors.borderStrong, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => notifier.decrementarCantidad(item.id, paso),
                      child: const Icon(Icons.remove, size: 28, color: AppColors.textPrimary),
                    ),
                  ),

                  // Número Central Grande
                  Container(
                    constraints: const BoxConstraints(minWidth: 54),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.cantidadAComprar.toInt().toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (item.esEmpaqueado)
                          Text(
                            etiquetaCompra,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          )
                        else if (item.esFraccionable)
                          Text(
                            unidad,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Botón Aumentar (+)
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => notifier.incrementarCantidad(item.id, paso),
                      child: const Icon(Icons.add, size: 28, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Barra inferior pegada con botones de alta accesibilidad para compartir y copiar
class _BarraAccionesPedido extends StatelessWidget {
  final List<ItemReposicion> items;
  final double totalInversion;

  const _BarraAccionesPedido({
    required this.items,
    required this.totalInversion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón Verde WhatsApp Masivo
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366), // Verde oficial WhatsApp
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                final texto = PedidoFormatter.formatearPedido(
                  items: items,
                  totalInversion: totalInversion,
                );

                final exito = await PedidoFormatter.compartirPorWhatsApp(texto);
                if (!context.mounted) return;

                if (!exito) {
                  // Fallback: Si WhatsApp no abre directamente, copia al portapapeles
                  await PedidoFormatter.copiarAlPortapapeles(texto);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.primary,
                      content: Text(
                        'WhatsApp no disponible. ¡Pedido copiado al portapapeles para pegar donde quieras!',
                        style: TextStyle(fontSize: 16),
                      ),
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.send, color: Colors.white, size: 26),
              label: const Text(
                'Compartir por WhatsApp',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Botón Copiar al Portapapeles
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.borderStrong, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                final texto = PedidoFormatter.formatearPedido(
                  items: items,
                  totalInversion: totalInversion,
                );
                await PedidoFormatter.copiarAlPortapapeles(texto);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 24),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '¡Pedido copiado al portapapeles con éxito!',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy, color: AppColors.textPrimary, size: 22),
              label: const Text(
                'Copiar Pedido al Portapapeles',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
