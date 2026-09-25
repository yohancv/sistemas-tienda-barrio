import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/config/supabase_client.dart';
import '../../data/models/venta_models.dart';
import '../../state/providers/carrito_providers.dart';
import '../../state/providers/pago_providers.dart';
import '../../state/providers/venta_providers.dart';

class CobroScreen extends ConsumerStatefulWidget {
  final double totalAPagar;

  const CobroScreen({
    super.key,
    required this.totalAPagar,
  });

  @override
  ConsumerState<CobroScreen> createState() => _CobroScreenState();
}

class _CobroScreenState extends ConsumerState<CobroScreen> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(efectivoRecibidoProvider.notifier).corregir();
    });
  }

  Future<void> _confirmarVenta() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final efectivoRecibido = ref.read(efectivoRecibidoProvider);
      final vuelto = ((efectivoRecibido - widget.totalAPagar) * 100).round() / 100.0;
      final itemsCarrito = ref.read(carritoProvider);
      const tenantId = SupabaseConfig.defaultTenantId;

      // 1. Construir cabecera de Venta
      final venta = Venta(
        tenantId: tenantId,
        totalVenta: widget.totalAPagar,
        metodoPago: 'EFECTIVO',
        montoRecibido: efectivoRecibido,
        cambioEntregado: vuelto >= 0 ? vuelto : 0.0,
        fechaVenta: DateTime.now(),
      );

      // 2. Construir detalles de venta con costo congelado
      final detalles = itemsCarrito.map((item) {
        return DetalleVenta(
          productoId: item.producto.id,
          cantidad: item.cantidad,
          precioUnitario: item.producto.precioVenta,
          costoUnitario: item.producto.costoMayorista,
          subtotal: item.subtotal,
        );
      }).toList();

      // 3. Construir desglose de pago en efectivo
      final pagos = [
        PagoVenta(
          tenantId: tenantId,
          metodo: 'EFECTIVO',
          monto: widget.totalAPagar,
          createdAt: DateTime.now(),
        ),
      ];

      // 4. Guardar en Supabase y descontar stock
      await ref.read(ventaRepositoryProvider).registrarTransaccionCompleta(
            venta: venta,
            detalles: detalles,
            pagos: pagos,
          );

      // 5. Limpiar carrito y estado
      ref.read(carritoProvider.notifier).limpiarCarrito();
      ref.read(efectivoRecibidoProvider.notifier).corregir();

      if (!mounted) return;

      // 6. Diálogo de éxito visual con el cambio para el cliente
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 36),
              SizedBox(width: 10),
              Text('¡Venta Exitosa!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total cobrado: \$${widget.totalAPagar.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 8),
              Text('Recibido: \$${efectivoRecibido.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20)),
              const Divider(height: 24, thickness: 1.5),
              Text(
                'VUELTO: \$${vuelto.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.success),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () {
                  Navigator.pop(context); // Cierra diálogo
                  Navigator.popUntil(context, (route) => route.isFirst); // Regresa al catálogo
                },
                child: const Text('NUEVA VENTA', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Error al registrar venta: $e', style: const TextStyle(fontSize: 18)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final efectivoRecibido = ref.watch(efectivoRecibidoProvider);
    final diferencia = efectivoRecibido - widget.totalAPagar;
    final bool saldoSuficiente = diferencia >= -0.001; // Tolerancia de redondeo

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cobro en Caja',
          style: AppTypography.headlineSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Bloque superior gigante: Vuelto o Faltante
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              color: saldoSuficiente
                  ? AppColors.success.withAlpha(25)
                  : AppColors.danger.withAlpha(25),
              child: Column(
                children: [
                  Text(
                    'TOTAL DE LA CUENTA: \$${widget.totalAPagar.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Recibido: \$${efectivoRecibido.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  if (!saldoSuficiente)
                    Text(
                      'FALTAN: \$${(-diferencia).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.danger),
                    )
                  else
                    Text(
                      'VUELTO: \$${diferencia.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: AppColors.success),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 2, color: AppColors.border),

            // Botonera de denominaciones rápidas y corrección
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Botón de Pago Exacto para agilidad máxima
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: AppColors.surface,
                        ),
                        onPressed: () {
                          ref.read(efectivoRecibidoProvider.notifier).fijarMontoExacto(widget.totalAPagar);
                        },
                        icon: const Icon(Icons.flash_on, color: AppColors.primary, size: 28),
                        label: Text(
                          'PAGO EXACTO (\$${widget.totalAPagar.toStringAsFixed(2)})',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Grilla táctil de billetes
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.25,
                        children: [
                          const _BotonBillete(monto: 10),
                          const _BotonBillete(monto: 20),
                          const _BotonBillete(monto: 50),
                          const _BotonBillete(monto: 100),
                          const _BotonBillete(monto: 200),
                          // Botón Masivo de Corregir (Reset)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              ref.read(efectivoRecibidoProvider.notifier).corregir();
                            },
                            icon: const Icon(Icons.backspace, color: Colors.white, size: 24),
                            label: const Text('BORRAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Botón Confirmar Venta anclado en la base
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(20), offset: const Offset(0, -4), blurRadius: 10),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: saldoSuficiente ? AppColors.success : Colors.grey.shade400,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: saldoSuficiente ? 4 : 0,
            ),
            onPressed: saldoSuficiente && !_isProcessing ? _confirmarVenta : null,
            child: _isProcessing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'CONFIRMAR VENTA',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Widget de botón de billete con toques cómodos
class _BotonBillete extends ConsumerWidget {
  final double monto;

  const _BotonBillete({required this.monto});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 2,
        side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        ref.read(efectivoRecibidoProvider.notifier).sumar(monto);
      },
      child: Text(
        '+\$${monto.toInt()}',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary),
      ),
    );
  }
}
