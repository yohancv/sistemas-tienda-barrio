import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/config/supabase_client.dart';
import '../../data/models/cierre_caja_model.dart';
import '../../state/providers/cierre_caja_providers.dart';

class CierreCajaScreen extends ConsumerStatefulWidget {
  const CierreCajaScreen({super.key});

  @override
  ConsumerState<CierreCajaScreen> createState() => _CierreCajaScreenState();
}

class _CierreCajaScreenState extends ConsumerState<CierreCajaScreen> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cajaProvider.notifier).reiniciar();
    });
  }

  /// Procesa el cierre ciego definitivo
  Future<void> _declararEfectivo() async {
    if (_isProcessing) return;

    final cajaState = ref.read(cajaProvider);
    final montoDeclarado = cajaState.granTotal;

    setState(() => _isProcessing = true);

    try {
      const tenantId = SupabaseConfig.defaultTenantId;
      final repo = ref.read(cierreCajaRepositoryProvider);

      // 1. Obtener el monto esperado en efectivo del sistema
      final montoEsperado = await repo.calcularMontoEsperadoEnEfectivo(
        tenantId,
        fondoFijo: 0.0,
      );

      // 2. Calcular descuadre (Declarado - Esperado)
      final descuadre = ((montoDeclarado - montoEsperado) * 100).round() / 100.0;
      final bool estaCuadrado = descuadre.abs() <= 1.0; // Tolerancia de 1 Bs
      final bool hayFaltante = descuadre < -1.0;

      // 3. Registrar el cierre en Supabase (Inmutable)
      final cierre = CierreCaja(
        tenantId: tenantId,
        fondoFijo: 0.0,
        montoDeclarado: montoDeclarado,
        montoEsperado: montoEsperado,
        descuadre: descuadre,
        estado: 'COMPLETADO',
        notas: estaCuadrado ? 'Caja cuadrada correctamente' : (hayFaltante ? 'Faltante de efectivo' : 'Sobrante de efectivo'),
        fechaCierre: DateTime.now(),
      );

      await repo.registrarCierre(cierre);
      ref.read(cajaProvider.notifier).reiniciar();

      if (!mounted) return;

      // 4. Revelar el arqueo en un Diálogo Semáforo de alto impacto visual
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                estaCuadrado ? Icons.check_circle : (hayFaltante ? Icons.cancel : Icons.warning_amber_rounded),
                color: estaCuadrado ? AppColors.success : (hayFaltante ? AppColors.danger : AppColors.warning),
                size: 38,
              ),
              const SizedBox(width: 12),
              Text(
                estaCuadrado ? '¡Caja Cuadrada!' : (hayFaltante ? '¡Faltante en Caja!' : '¡Sobrante en Caja!'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Declarado en físico: Bs. ${montoDeclarado.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 6),
              Text('Esperado por ventas: Bs. ${montoEsperado.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18)),
              const Divider(height: 24, thickness: 1.5),
              Text(
                'DIFERENCIA: ${descuadre >= 0 ? '+' : ''}Bs. ${descuadre.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: estaCuadrado ? AppColors.success : (hayFaltante ? AppColors.danger : AppColors.warning),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                estaCuadrado
                    ? 'El arqueo fue completado exitosamente.'
                    : 'Se registró la diferencia en el acta de auditoría.',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Regresa a pantalla anterior
                },
                child: const Text('FINALIZAR TURNO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
          content: Text('Error al registrar cierre: $e', style: const TextStyle(fontSize: 18)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Posponer el cierre para ir a descansar
  Future<void> _posponerCierre() async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bedtime, color: AppColors.textSecondary, size: 32),
            SizedBox(width: 10),
            Text('¿Posponer arqueo?'),
          ],
        ),
        content: const Text(
          'Se registrará el turno como POSPUESTO sin exigir conteo para que puedas ir a descansar tranquilamente. Podrás realizar el arqueo mañana.',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver a contar', style: TextStyle(fontSize: 18)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, posponer y descansar', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isProcessing = true);

    try {
      const tenantId = SupabaseConfig.defaultTenantId;
      final repo = ref.read(cierreCajaRepositoryProvider);

      final cierrePospuesto = CierreCaja(
        tenantId: tenantId,
        fondoFijo: 0.0,
        montoDeclarado: null,
        montoEsperado: null,
        descuadre: null,
        estado: 'POSPUESTO',
        notas: 'Cierre pospuesto por cansancio del cajero',
        fechaCierre: DateTime.now(),
      );

      await repo.registrarCierre(cierrePospuesto);
      ref.read(cajaProvider.notifier).reiniciar();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.blueGrey,
          duration: Duration(seconds: 2),
          content: Text('Turno pospuesto. ¡Buen descanso!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.danger, content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cajaState = ref.watch(cajaProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cierre de Caja Ciego',
          style: AppTypography.headlineSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 28, color: Colors.white),
            tooltip: 'Reiniciar conteo',
            onPressed: () => ref.read(cajaProvider.notifier).reiniciar(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 140), // Espacio para el panel inferior
          itemCount: Denominacion.values.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final denom = Denominacion.values[index];
            final cantidad = cajaState.cantidades[denom] ?? 0;
            final subtotal = denom.valor * cantidad;

            return _DenominacionRow(
              denom: denom,
              cantidad: cantidad,
              subtotal: subtotal,
            );
          },
        ),
      ),

      // Panel inferior anclado con el gran total y los botones masivos
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(25), offset: const Offset(0, -4), blurRadius: 10),
          ],
          border: const Border(top: BorderSide(color: AppColors.border, width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gran Total Declarado Gigante
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL CONTADO:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  'Bs. ${cajaState.granTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Botón Verde Masivo: Declarar Efectivo
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
                onPressed: !_isProcessing ? _declararEfectivo : null,
                icon: const Icon(Icons.verified, color: Colors.white, size: 28),
                label: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'DECLARAR EFECTIVO',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                      ),
              ),
            ),
            const SizedBox(height: 8),

            // Botón Gris Masivo: Cansado - Posponer
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blueGrey, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: !_isProcessing ? _posponerCierre : null,
                icon: const Icon(Icons.bedtime, color: Colors.blueGrey, size: 22),
                label: const Text(
                  'CANSADO - POSPONER CIERRE',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de Denominación con botones táctiles masivos y subtotal visual
class _DenominacionRow extends ConsumerWidget {
  final Denominacion denom;
  final int cantidad;
  final double subtotal;

  const _DenominacionRow({
    required this.denom,
    required this.cantidad,
    required this.subtotal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cantidad > 0 ? AppColors.primary : AppColors.border,
          width: cantidad > 0 ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Icono según tipo (Billete o Moneda)
          Icon(
            denom.esBillete ? Icons.money : Icons.toll,
            color: denom.esBillete ? AppColors.primary : Colors.amber.shade800,
            size: 32,
          ),
          const SizedBox(width: 10),

          // Etiqueta de Denominación
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  denom.etiqueta,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  '= Bs. ${subtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: subtotal > 0 ? AppColors.success : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Botón Disminuir (-) Masivo
          IconButton(
            iconSize: 34,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceMuted,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.remove, color: AppColors.danger),
            onPressed: () => ref.read(cajaProvider.notifier).decrementar(denom),
          ),

          // Cantidad física contada
          Container(
            constraints: const BoxConstraints(minWidth: 46),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$cantidad',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            ),
          ),

          // Botón Aumentar (+) Masivo
          IconButton(
            iconSize: 34,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceMuted,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add, color: AppColors.success),
            onPressed: () => ref.read(cajaProvider.notifier).incrementar(denom),
          ),
        ],
      ),
    );
  }
}
