import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/app_haptics.dart';
import '../../data/models/caja_turno_model.dart';
import '../../data/models/resumen_caja_model.dart';
import '../../state/providers/caja_providers.dart';
import 'dialogo_ticket_arqueo.dart';

/// Modal simplificado de Corte de Caja Diario para el Dueño (Fricción Cero)
///
/// Diseñado para tiendas atendidas por sus propios dueños:
/// - 1 Solo Toque: Sin preguntas de cuánto dinero deja en gaveta.
/// - Cero conteo ciego o estrés nocturno.
/// - Presenta de inmediato los totales reales cobrados en gaveta y banco QR.
/// - El nuevo turno de mañana arranca en Bs. 0.00 de forma inmediata para seguir vendiendo.
class ModalCorteDiario extends ConsumerStatefulWidget {
  final CajaTurnoModel turno;
  final ResumenCajaModel resumen;

  const ModalCorteDiario({
    super.key,
    required this.turno,
    required this.resumen,
  });

  @override
  ConsumerState<ModalCorteDiario> createState() => _ModalCorteDiarioState();
}

class _ModalCorteDiarioState extends ConsumerState<ModalCorteDiario> {
  final TextEditingController _observacionesController = TextEditingController();
  bool _isProcessing = false;
  String? _error;

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _confirmarCorte() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      AppHaptics.medium();
      // Corte directo con fondo 0.0 Bs: el siguiente turno queda listo al instante
      final turnoCerrado = await ref.read(cajaTurnoActivaProvider.notifier).hacerCorteDiario(
            resumen: widget.resumen,
            fondoParaManana: 0.0,
            observaciones: _observacionesController.text.trim(),
          );

      // Refrescar métricas financieras reactivamente
      ref.invalidate(resumenCajaTurnoProvider);
      ref.invalidate(movimientosCajaTurnoProvider);
      ref.invalidate(historialTurnosCajaProvider);
      ref.invalidate(ventasTurnoProvider);

      if (!mounted) return;
      Navigator.pop(context, true);

      // Mostrar ticket o acta final del turno cerrado
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => DialogoTicketArqueo(turno: turnoCerrado),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _error = 'Error al realizar el corte: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final esOscuro = ref.watch(esModoOscuroProvider);
    final bgColor = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textMuted = esOscuro ? AppColors.darkTextMuted : AppColors.textMuted;

    final r = widget.resumen;
    final totalDineroReal = r.montoEsperadoEfectivo + r.saldoNetoQr;
    final totalVentas = r.totalVentasEfectivo + r.totalVentasQr;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra de arrastre superior
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: esOscuro ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Corte de Caja Diario',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Guarda las ventas de hoy y deja la caja lista para mañana',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Tarjeta destacada de Dinero Total de Hoy
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL DINERO COBRADO HOY',
                    style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bs. ${totalDineroReal.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('💵 En Gaveta (Efectivo)', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                'Bs. ${r.montoEsperadoEfectivo.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('📱 En Banco / QR', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                'Bs. ${r.saldoNetoQr.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Resumen de Operaciones del Día
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: esOscuro ? const Color(0xFF1E293B) : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                children: [
                  _FilaResumen(
                    icono: Icons.shopping_bag_outlined,
                    label: 'Ventas Totales Cobradas:',
                    valor: 'Bs. ${totalVentas.toStringAsFixed(2)}',
                    colorValor: AppColors.retailGreen,
                    esOscuro: esOscuro,
                  ),
                  const SizedBox(height: 6),
                  _FilaResumen(
                    icono: Icons.payments_outlined,
                    label: 'Cobros de Fiados (Abonos):',
                    valor: 'Bs. ${(r.totalFiadosCobradosEfectivo + r.totalFiadosCobradosQr).toStringAsFixed(2)}',
                    colorValor: AppColors.retailGreen,
                    esOscuro: esOscuro,
                  ),
                  if (r.totalSalidasTienda > 0) ...[
                    const SizedBox(height: 6),
                    _FilaResumen(
                      icono: Icons.storefront_outlined,
                      label: 'Gastos Tienda (Luz, bolsas, etc.):',
                      valor: '- Bs. ${r.totalSalidasTienda.toStringAsFixed(2)}',
                      colorValor: const Color(0xFFE11D48),
                      esOscuro: esOscuro,
                    ),
                  ],
                  if (r.totalSalidasPersonal > 0) ...[
                    const SizedBox(height: 6),
                    _FilaResumen(
                      icono: Icons.person_outline,
                      label: 'Retiros del Dueño registrados:',
                      valor: '- Bs. ${r.totalSalidasPersonal.toStringAsFixed(2)}',
                      colorValor: Colors.orange[800],
                      esOscuro: esOscuro,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Banner informativo: Continuidad inmediata sin fricción
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: esOscuro ? const Color(0xFF0F2E22) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: esOscuro ? const Color(0xFF059669).withValues(alpha: 0.4) : const Color(0xFFA7F3D0),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on_rounded, size: 20, color: Color(0xFF10B981)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tu siguiente turno iniciará en Bs. 0.00 automáticamente para que sigas vendiendo sin frenar.',
                      style: TextStyle(
                        fontSize: 12,
                        color: esOscuro ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Observaciones opcionales (por si quiere anotar algo rápido)
            TextField(
              controller: _observacionesController,
              maxLines: 2,
              style: TextStyle(fontSize: 13, color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Notas del día / Observaciones (opcional)',
                labelStyle: TextStyle(fontSize: 12, color: textMuted),
                filled: true,
                fillColor: esOscuro ? const Color(0xFF0F172A) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder),
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            ],

            const SizedBox(height: 20),

            // Botón Principal de 1 Solo Toque
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _isProcessing ? null : _confirmarCorte,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 22),
                label: Text(
                  _isProcessing ? 'Guardando corte del día...' : '🌙 Guardar Corte del Día e Ir a Descansar',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Botón Cancelar
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Volver sin cerrar',
                style: TextStyle(color: textMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaResumen extends StatelessWidget {
  final IconData icono;
  final String label;
  final String valor;
  final Color? colorValor;
  final bool esOscuro;

  const _FilaResumen({
    required this.icono,
    required this.label,
    required this.valor,
    this.colorValor,
    required this.esOscuro,
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = esOscuro ? AppColors.darkTextMuted : AppColors.textMuted;

    return Row(
      children: [
        Icon(icono, size: 16, color: textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: colorValor ?? (esOscuro ? Colors.white : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
