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
  void initState() {
    super.initState();
    _montoController.addListener(_onMontoChanged);
  }

  void _onMontoChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _montoController.removeListener(_onMontoChanged);
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
    final ultimoTurnoAsync = ref.watch(ultimoTurnoCerradoProvider);
    final montoIngresado = double.tryParse(_montoController.text.replaceAll(',', '.'));

    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final inputBg = esOscuro ? AppColors.darkBackground : AppColors.background;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textMuted = esOscuro ? AppColors.darkTextMuted : AppColors.textMuted;
    final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: cardBorder,
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
                        Text(
                          'Apertura de Turno de Caja',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        Text(
                          'Ingresa el efectivo inicial para dar cambio',
                          style: TextStyle(fontSize: 13, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Divider(height: 24, color: cardBorder),

              // TARJETA INTELIGENTE DEL TURNO ANTERIOR
              ultimoTurnoAsync.maybeWhen(
                data: (ultimoTurno) {
                  if (ultimoTurno == null) return const SizedBox.shrink();
                  final ultimoMonto =
                      ultimoTurno.montoRealContado ?? ultimoTurno.montoEsperadoEfectivo;
                  if (ultimoMonto <= 0) return const SizedBox.shrink();

                  final diferencia = montoIngresado != null
                      ? ((ultimoMonto - montoIngresado) * 100).round() / 100.0
                      : 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: esOscuro ? AppColors.darkBackground : Colors.blue[50],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: esOscuro ? cardBorder : Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history_toggle_off, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Turno anterior cerró con: Bs. ${ultimoMonto.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: esOscuro ? textPrimary : Colors.blue[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Botones de acción rápida basados en el turno anterior
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: esOscuro ? surfaceColor : Colors.white,
                                  side: BorderSide(color: esOscuro ? cardBorder : Colors.blue[300]!),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  _montoController.text = ultimoMonto.toStringAsFixed(2);
                                  setState(() => _error = null);
                                },
                                child: Text(
                                  'Dejar todo (Bs. ${ultimoMonto.toStringAsFixed(0)})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: esOscuro ? textPrimary : Colors.blue[900],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: esOscuro ? surfaceColor : Colors.white,
                                  side: BorderSide(color: esOscuro ? cardBorder : Colors.blue[300]!),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  _montoController.text = '100.00';
                                  setState(() => _error = null);
                                },
                                child: const Text(
                                  'Solo sencillo (Bs. 100)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Nota explicativa en tiempo real
                        if (montoIngresado != null) ...[
                          const SizedBox(height: 8),
                          if (diferencia > 0) ...[
                            Text(
                              '💡 Si dejas Bs. ${montoIngresado.toStringAsFixed(2)}, te estás llevando Bs. ${diferencia.toStringAsFixed(2)} a tu casa/bolsillo.',
                              style: TextStyle(
                                fontSize: 11,
                                color: esOscuro ? textSecondary : Colors.blueGrey[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ] else if (diferencia == 0) ...[
                            const Text(
                              '👌 Estás dejando exactamente todo el dinero del cierre en el cajón.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ] else ...[
                            Text(
                              '➕ Estás agregando Bs. ${(-diferencia).toStringAsFixed(2)} extra de tu bolsillo para cambio.',
                              style: TextStyle(
                                fontSize: 11,
                                color: esOscuro ? Colors.lightBlueAccent : Colors.blue[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),

              // Campo de Monto Inicial Grande
              Text(
                'Fondo Inicial en Efectivo (Bs.)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
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
                  prefixStyle: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                  hintText: '0.00',
                  errorText: _error,
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cardBorder, width: 1.5),
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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted),
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
              const SizedBox(height: 24),

              // Botón de Confirmación
              SizedBox(
                height: 56,
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
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final cardBorder = esOscuro ? AppColors.darkBorder : Colors.grey[400]!;
    final neutralBg = esOscuro ? AppColors.darkBackground : Colors.grey[200];
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return ActionChip(
      onPressed: onTap,
      backgroundColor: esNeutral ? neutralBg : AppColors.primary.withAlpha(20),
      side: BorderSide(
        color: esNeutral ? cardBorder : AppColors.primary.withAlpha(80),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: esNeutral ? textPrimary : AppColors.primary,
        ),
      ),
    );
  }
}
