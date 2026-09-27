import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/models/cliente_model.dart';
import '../../state/providers/clientes_providers.dart';

class ModalRegistrarAbono extends ConsumerStatefulWidget {
  final Cliente cliente;

  const ModalRegistrarAbono({super.key, required this.cliente});

  @override
  ConsumerState<ModalRegistrarAbono> createState() => _ModalRegistrarAbonoState();
}

class _ModalRegistrarAbonoState extends ConsumerState<ModalRegistrarAbono> {
  final _montoController = TextEditingController();
  final _notasController = TextEditingController();

  double _montoAbono = 0.0;
  final String _metodoPago = 'EFECTIVO';
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    // Sugerir por defecto liquidar el total si la deuda es moderada, o dejar vacío
    _montoAbono = widget.cliente.saldoActual;
    _montoController.text = _montoAbono.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _montoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  void _seleccionarMonto(double monto) {
    setState(() {
      _montoAbono = monto;
      _montoController.text = monto.toStringAsFixed(2);
    });
  }

  void _onMontoChanged(String valor) {
    final limpio = valor.replaceAll(',', '.');
    final monto = double.tryParse(limpio) ?? 0.0;
    setState(() {
      _montoAbono = monto;
    });
  }

  void _confirmarAbono() async {
    if (_montoAbono <= 0) return;

    setState(() => _procesando = true);

    final exito = await ref.read(clientesNotifierProvider.notifier).registrarAbono(
          clienteId: widget.cliente.id,
          monto: _montoAbono,
          metodoPago: _metodoPago,
          notas: _notasController.text.trim().isEmpty ? null : _notasController.text.trim(),
        );

    if (mounted) {
      setState(() => _procesando = false);
      if (exito) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final saldoActual = widget.cliente.saldoActual;
    final nuevoSaldo = saldoActual - _montoAbono;
    final nuevoSaldoSeguro = nuevoSaldo < 0 ? 0.0 : nuevoSaldo;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra de arrastre
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Encabezado
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.payments_outlined, color: AppColors.success, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.cliente.nombre,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Deuda pendiente: Bs. ${saldoActual.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Botón rápido para Liquidar Deuda Completa
            if (saldoActual > 0) ...[
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success.withAlpha(25),
                    elevation: 0,
                    side: const BorderSide(color: AppColors.success, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _seleccionarMonto(saldoActual),
                  icon: const Icon(Icons.done_all, color: AppColors.success),
                  label: Text(
                    'Liquidar Deuda Completa (Bs. ${saldoActual.toStringAsFixed(2)})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Input del monto a abonar
            const Text(
              'MONTO DEL ABONO (BS.):',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: Row(
                children: [
                  const Text(
                    'Bs.',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _montoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        border: InputBorder.none,
                      ),
                      onChanged: _onMontoChanged,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Accesos directos a billetes bolivianos comunes
            Row(
              children: [10.0, 20.0, 50.0, 100.0].map((billete) {
                final seleccionado = _montoAbono == billete;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor:
                              seleccionado ? AppColors.primary : AppColors.surfaceMuted,
                          elevation: seleccionado ? 2 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: seleccionado ? AppColors.primary : AppColors.border,
                              width: seleccionado ? 2 : 1,
                            ),
                          ),
                        ),
                        onPressed: () => _seleccionarMonto(billete),
                        child: Text(
                          'Bs. ${billete.toInt()}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: seleccionado ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Tarjeta de Simulación: Antes vs Después
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Debía antes:', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                      Text(
                        'Bs. ${saldoActual.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward, color: AppColors.textMuted),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Nuevo Saldo:', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                      Text(
                        'Bs. ${nuevoSaldoSeguro.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: nuevoSaldoSeguro <= 0.05 ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Botón Masivo de Confirmación (60dp)
            SizedBox(
              height: 58,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _montoAbono > 0 ? AppColors.success : AppColors.surfaceMuted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: (_montoAbono > 0 && !_procesando) ? _confirmarAbono : null,
                icon: _procesando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, color: Colors.white, size: 26),
                label: Text(
                  _procesando
                      ? 'Registrando abono...'
                      : 'Confirmar Abono (Bs. ${_montoAbono.toStringAsFixed(2)})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
