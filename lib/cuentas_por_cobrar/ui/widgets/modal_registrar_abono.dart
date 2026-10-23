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
  String _metodoPago = 'EFECTIVO';
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
    final montoSeguro = monto > widget.cliente.saldoActual ? widget.cliente.saldoActual : monto;
    setState(() {
      _montoAbono = montoSeguro;
      _montoController.text = montoSeguro.toStringAsFixed(2);
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
    if (_montoAbono > widget.cliente.saldoActual + 0.001) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El abono no puede ser mayor al saldo deudor actual.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

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

    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBg = esOscuro ? AppColors.darkBackground : AppColors.surfaceMuted;
    final inputBg = esOscuro ? AppColors.darkBackground : AppColors.background;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textMuted = esOscuro ? AppColors.darkTextMuted : AppColors.textMuted;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: cardBorder,
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
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
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
                  icon: Icon(Icons.close, color: textMuted),
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
            Text(
              'MONTO DEL ABONO (BS.):',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: inputBg,
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
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: textPrimary),
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
                              seleccionado ? AppColors.primary : cardBg,
                          elevation: seleccionado ? 2 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: seleccionado ? AppColors.primary : cardBorder,
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
                            color: seleccionado ? Colors.white : textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Selector de Método de Pago: Efectivo vs QR / Banco
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _metodoPago = 'EFECTIVO'),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _metodoPago == 'EFECTIVO' ? AppColors.retailGreen : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              size: 19,
                              color: _metodoPago == 'EFECTIVO' ? Colors.white : textPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Efectivo',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _metodoPago == 'EFECTIVO' ? Colors.white : textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _metodoPago = 'QR'),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: _metodoPago == 'QR' ? AppColors.retailBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_rounded,
                              size: 19,
                              color: _metodoPago == 'QR' ? Colors.white : textPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'QR / Banco',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _metodoPago == 'QR' ? Colors.white : textPrimary,
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

            const SizedBox(height: 16),

            // Tarjeta de Simulación: Antes vs Después
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder, width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Debía antes:', style: TextStyle(fontSize: 13, color: textMuted)),
                      Text(
                        'Bs. ${saldoActual.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_forward, color: textMuted),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Nuevo Saldo:', style: TextStyle(fontSize: 13, color: textMuted)),
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
                  backgroundColor: _montoAbono > 0 ? AppColors.success : (esOscuro ? AppColors.darkBorder : AppColors.surfaceMuted),
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
