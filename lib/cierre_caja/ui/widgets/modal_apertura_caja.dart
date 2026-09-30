import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../state/providers/caja_providers.dart';

class ModalAperturaCaja extends ConsumerStatefulWidget {
  const ModalAperturaCaja({super.key});

  @override
  ConsumerState<ModalAperturaCaja> createState() => _ModalAperturaCajaState();
}

class _ModalAperturaCajaState extends ConsumerState<ModalAperturaCaja> {
  final _montoController = TextEditingController(text: '100.00');
  bool _isProcessing = false;
  String? _error;

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  void _agregarSugerencia(double cantidad) {
    final actual = double.tryParse(_montoController.text.replaceAll(',', '.')) ?? 0.0;
    final nuevo = actual + cantidad;
    _montoController.text = nuevo.toStringAsFixed(2);
    setState(() => _error = null);
  }

  Future<void> _abrirCaja() async {
    final texto = _montoController.text.trim().replaceAll(',', '.');
    final monto = double.tryParse(texto);

    if (monto == null || monto < 0) {
      setState(() => _error = 'Ingresa un monto válido en Bs. (ej. 100.00)');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final turnoExistente = ref.read(cajaTurnoActivaProvider).value;
      if (turnoExistente != null && turnoExistente.estaAbierta) {
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primary,
            content: Text(
              'Ya cuentas con un turno de caja abierto.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        );
        return;
      }

      await ref.read(cajaTurnoActivaProvider.notifier).abrirTurno(monto);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            '¡Turno de caja abierto con Bs. ${monto.toStringAsFixed(2)} de fondo inicial!',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra superior del modal
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.point_of_sale, color: AppColors.primary, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Apertura de Turno de Caja',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'Ingresa el efectivo inicial para dar cambio',
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 30),

              // Campo de Monto Inicial Grande
              const Text(
                'Fondo Inicial en Efectivo (Bs.)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _montoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 1.0,
                ),
                decoration: InputDecoration(
                  prefixText: 'Bs. ',
                  prefixStyle: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  hintText: '0.00',
                  errorText: _error,
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2.5),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 14),

              // Botones de sugerencias rápidas
              const Text(
                'Sugerencias rápidas:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _ChipMonto(label: '+ Bs. 50', onTap: () => _agregarSugerencia(50)),
                  _ChipMonto(label: '+ Bs. 100', onTap: () => _agregarSugerencia(100)),
                  _ChipMonto(label: '+ Bs. 200', onTap: () => _agregarSugerencia(200)),
                  _ChipMonto(
                    label: 'Cero (0.00)',
                    onTap: () {
                      _montoController.text = '0.00';
                      setState(() => _error = null);
                    },
                    esNeutral: true,
                  ),
                ],
              ),
              const SizedBox(height: 26),

              // Botón de Confirmación
              SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                  onPressed: _isProcessing ? null : _abrirCaja,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Icon(Icons.lock_open, color: Colors.white, size: 26),
                  label: Text(
                    _isProcessing ? 'Iniciando turno...' : 'INICIAR TURNO DE CAJA',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipMonto extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool esNeutral;

  const _ChipMonto({
    required this.label,
    required this.onTap,
    this.esNeutral = false,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      backgroundColor: esNeutral ? Colors.grey[200] : AppColors.primary.withAlpha(20),
      side: BorderSide(
        color: esNeutral ? Colors.grey[400]! : AppColors.primary.withAlpha(80),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: esNeutral ? AppColors.textPrimary : AppColors.primary,
        ),
      ),
    );
  }
}
