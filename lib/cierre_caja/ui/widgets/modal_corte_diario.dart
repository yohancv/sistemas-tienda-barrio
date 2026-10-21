import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/app_haptics.dart';
import '../../data/models/caja_turno_model.dart';
import '../../data/models/resumen_caja_model.dart';
import '../../state/providers/caja_providers.dart';
import 'dialogo_ticket_arqueo.dart';

/// Modal simplificado de Corte de Caja Diario para el Dueño
///
/// Diseñado para tiendas atendidas por sus propios dueños:
/// - No exige contar billete por billete (sin conteo ciego innecesario).
/// - Presenta de inmediato los totales reales en gaveta y banco.
/// - Permite definir con 1 toque cuánto cambio queda para mañana.
/// - Cierra la jornada en SQLite y reactiva la caja continua sin fricción.
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
  late final TextEditingController _fondoMananaController;
  final TextEditingController _observacionesController = TextEditingController();
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Sugerencia inteligente de fondo para mañana:
    // Si hay suficiente efectivo en gaveta, sugerimos 100 Bs de cambio o el total
    final esperado = widget.resumen.montoEsperadoEfectivo;
    final sugerido = esperado >= 100.0 ? 100.0 : (esperado > 0 ? esperado : 0.0);
    _fondoMananaController = TextEditingController(text: sugerido.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _fondoMananaController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  void _fijarFondo(double valor) {
    AppHaptics.selection();
    setState(() {
      _fondoMananaController.text = valor.toStringAsFixed(2);
      _error = null;
    });
  }

  Future<void> _confirmarCorte() async {
    final fondoTexto = _fondoMananaController.text.trim().replaceAll(',', '.');
    final fondo = double.tryParse(fondoTexto);

    if (fondo == null || fondo < 0) {
      setState(() => _error = 'Ingresa un monto válido para el fondo de mañana (ej. 100.00)');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      AppHaptics.medium();
      final turnoCerrado = await ref.read(cajaTurnoActivaProvider.notifier).hacerCorteDiario(
            resumen: widget.resumen,
            fondoParaManana: fondo,
            observaciones: _observacionesController.text.trim(),
          );

      // Refrescar métricas financieras
      ref.invalidate(resumenCajaTurnoProvider);
      ref.invalidate(movimientosCajaTurnoProvider);
      ref.invalidate(historialTurnosCajaProvider);

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
                        'Cierra los números de hoy y prepara la caja para mañana',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Tarjeta destacada de Dinero Total
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
                    'TOTAL DINERO DISPONIBLE HOY',
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
                  const SizedBox(height: 6),
                  _FilaResumen(
                    icono: Icons.storefront_outlined,
                    label: 'Gastos Tienda (Luz, bolsas, etc.):',
                    valor: '- Bs. ${r.totalSalidasTienda.toStringAsFixed(2)}',
                    colorValor: const Color(0xFFE11D48),
                    esOscuro: esOscuro,
                  ),
                  const SizedBox(height: 6),
                  _FilaResumen(
                    icono: Icons.person_outline,
                    label: 'Retiros Personales (Plata para ti):',
                    valor: '- Bs. ${r.totalSalidasPersonal.toStringAsFixed(2)}',
                    colorValor: Colors.orange[800],
                    esOscuro: esOscuro,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Fondo para la siguiente jornada
            Text(
              '¿Cuánto efectivo dejas en la gaveta para mañana?',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Este dinero será el fondo de cambio con el que empezará tu caja mañana.',
              style: TextStyle(fontSize: 11.5, color: textMuted),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _fondoMananaController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
              decoration: InputDecoration(
                prefixText: 'Bs. ',
                prefixStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                hintText: '100.00',
                filled: true,
                fillColor: esOscuro ? const Color(0xFF0F172A) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Chips de sugerencia rápida
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildChip(50, 'Bs. 50', esOscuro),
                _buildChip(100, 'Bs. 100', esOscuro),
                _buildChip(200, 'Bs. 200', esOscuro),
                _buildChip(r.montoEsperadoEfectivo, 'Dejar Todo (Bs. ${r.montoEsperadoEfectivo.toStringAsFixed(0)})', esOscuro),
                _buildChip(0, 'Bs. 0', esOscuro),
              ],
            ),
            const SizedBox(height: 14),

            // Observaciones opcionales
            TextField(
              controller: _observacionesController,
              maxLines: 2,
              style: TextStyle(fontSize: 13, color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Notas del día / Observaciones (opcional)',
                labelStyle: TextStyle(fontSize: 12, color: textMuted),
                hintText: 'Ej. Jornada tranquila, se compraron 2 paquetes de hielo...',
                hintStyle: TextStyle(fontSize: 12, color: textMuted),
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

            // Botón Principal Confirmar Corte
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
                  _isProcessing ? 'Guardando corte del día...' : 'Confirmar Corte y Preparar Mañana',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

  Widget _buildChip(double valor, String etiqueta, bool esOscuro) {
    return ActionChip(
      label: Text(etiqueta, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
      backgroundColor: esOscuro ? const Color(0xFF1E293B) : Colors.white,
      side: BorderSide(color: esOscuro ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      onPressed: () => _fijarFondo(valor),
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
