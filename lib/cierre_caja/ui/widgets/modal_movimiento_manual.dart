import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/supabase_client.dart';
import '../../state/providers/caja_providers.dart';

class ModalMovimientoManual extends ConsumerStatefulWidget {
  final String turnoId;

  const ModalMovimientoManual({
    super.key,
    required this.turnoId,
  });

  @override
  ConsumerState<ModalMovimientoManual> createState() =>
      _ModalMovimientoManualState();
}

class _ModalMovimientoManualState extends ConsumerState<ModalMovimientoManual> {
  String _tipo = 'SALIDA'; // Por defecto los movimientos más comunes son salidas/gastos menores
  final _montoController = TextEditingController();
  final _motivoController = TextEditingController();
  bool _isProcessing = false;
  String? _error;

  @override
  void dispose() {
    _montoController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  void _seleccionarMotivoRapido(String motivo) {
    _motivoController.text = motivo;
    setState(() => _error = null);
  }

  Future<void> _guardar() async {
    final textoMonto = _montoController.text.trim().replaceAll(',', '.');
    final monto = double.tryParse(textoMonto);
    final motivo = _motivoController.text.trim();

    if (monto == null || monto <= 0) {
      setState(() => _error = 'Ingresa un monto válido mayor a 0');
      return;
    }

    if (motivo.isEmpty) {
      setState(() => _error = 'Indica el motivo o concepto del movimiento');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final repo = ref.read(cajaRepositoryProvider);
      await repo.registrarMovimientoManual(
        tenantId: SupabaseConfig.defaultTenantId,
        turnoId: widget.turnoId,
        tipo: _tipo,
        monto: monto,
        motivo: motivo,
      );

      // Refrescar proveedores de resumen y movimientos
      ref.invalidate(resumenCajaTurnoProvider);
      ref.invalidate(movimientosCajaTurnoProvider);

      if (!mounted) return;
      Navigator.pop(context, true);

      final esSalida = _tipo == 'SALIDA';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: esSalida ? AppColors.warning : AppColors.success,
          content: Text(
            '${esSalida ? "Gasto" : "Ingreso"} de Bs. ${monto.toStringAsFixed(2)} registrado ($motivo)',
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
    final esSalida = _tipo == 'SALIDA';

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

              // Selector de Tipo: ENTRADA vs SALIDA
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tipo = 'SALIDA'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: esSalida ? AppColors.danger : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_upward,
                                color: esSalida ? Colors.white : AppColors.textMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Gasto / Salida',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: esSalida ? Colors.white : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tipo = 'ENTRADA'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !esSalida ? AppColors.success : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_downward,
                                color: !esSalida ? Colors.white : AppColors.textMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ingreso Manual',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: !esSalida ? Colors.white : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Campo Monto
              Text(
                esSalida ? 'Monto a retirar del cajón (Bs.)' : 'Monto ingresado al cajón (Bs.)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _montoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: esSalida ? AppColors.danger : AppColors.success,
                ),
                decoration: InputDecoration(
                  prefixText: 'Bs. ',
                  prefixStyle: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: esSalida ? AppColors.danger : AppColors.success,
                  ),
                  hintText: '0.00',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: esSalida ? AppColors.danger : AppColors.success),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 16),

              // Campo Motivo
              const Text(
                'Concepto o Motivo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _motivoController,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: esSalida ? 'Ej. Pago camión de hielo, pan, etc.' : 'Ej. Aporte de cambio sencillo',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Chips de motivos comunes
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: (esSalida
                    ? [
                        'Pago Hielo',
                        'Panadería',
                        'Artículos de Limpieza',
                        'Pago Distribuidor Menor',
                        'Almuerzo / Refrigerio',
                      ]
                    : [
                        'Cambio / Sencillo adicional',
                        'Fondo extra',
                        'Devolución de préstamo',
                      ])
                    .map(
                      (m) => ActionChip(
                        label: Text(m, style: const TextStyle(fontSize: 12)),
                        onPressed: () => _seleccionarMotivoRapido(m),
                        backgroundColor: AppColors.background,
                      ),
                    )
                    .toList(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 24),

              // Botón Guardar
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: esSalida ? AppColors.danger : AppColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isProcessing ? null : _guardar,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Icon(esSalida ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.white),
                  label: Text(
                    _isProcessing
                        ? 'Registrando...'
                        : (esSalida ? 'REGISTRAR SALIDA' : 'REGISTRAR INGRESO'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
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
