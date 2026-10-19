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
  // 'EFECTIVO_CAJA' o 'BANCO_QR'
  String _origen = 'EFECTIVO_CAJA';

  // 'SALIDA' o 'ENTRADA'
  String _tipo = 'SALIDA';

  // Categorías: 'GASTO_TIENDA', 'RETIRO_PERSONAL', 'MERCADERIA_FUTURA', 'AHORRO', 'PAGO_AYUDANTE', 'CAMBIO_SENCILLO', 'OTRO'
  String _categoria = 'GASTO_TIENDA';

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

  void _seleccionarCategoria(String cat, String motivoSugerido) {
    setState(() {
      _categoria = cat;
      if (_motivoController.text.trim().isEmpty) {
        _motivoController.text = motivoSugerido;
      }
      _error = null;
    });
  }

  void _sumarMonto(double delta) {
    final actual = double.tryParse(_montoController.text.replaceAll(',', '.')) ?? 0.0;
    final nuevo = actual + delta;
    _montoController.text = nuevo.toStringAsFixed(0);
    setState(() => _error = null);
  }

  Future<void> _guardar() async {
    final textoMonto = _montoController.text.trim().replaceAll(',', '.');
    final monto = double.tryParse(textoMonto);
    String motivo = _motivoController.text.trim();

    if (monto == null || monto <= 0) {
      setState(() => _error = 'Ingresa un monto válido mayor a Bs. 0');
      return;
    }

    if (motivo.isEmpty) {
      // Asignar motivo por defecto según categoría
      switch (_categoria) {
        case 'MERCADERIA_FUTURA':
          motivo = 'Apartado para mercadería futura';
          break;
        case 'RETIRO_PERSONAL':
          motivo = 'Retiro personal / gastos de casa';
          break;
        case 'AHORRO':
          motivo = 'Ahorro / Fondo de reserva';
          break;
        case 'PAGO_AYUDANTE':
          motivo = 'Pago de sueldo o jornal a ayudante';
          break;
        case 'CAMBIO_SENCILLO':
          motivo = 'Cambio y sencillo para el cajón';
          break;
        case 'GASTO_TIENDA':
          motivo = 'Gasto operativo de la tienda';
          break;
        default:
          motivo = 'Movimiento registrado';
      }
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
        origenDinero: _origen,
        categoria: _categoria,
      );

      // Refrescar proveedores de resumen y movimientos
      ref.invalidate(resumenCajaTurnoProvider);
      ref.invalidate(movimientosCajaTurnoProvider);

      if (!mounted) return;
      Navigator.pop(context, true);

      final esSalida = _tipo == 'SALIDA';
      final origenEtiqueta = _origen == 'BANCO_QR' ? 'del Banco QR' : 'del Cajón';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: esSalida ? AppColors.warning : AppColors.success,
          content: Text(
            '${esSalida ? "Retiro" : "Ingreso"} de Bs. ${monto.toStringAsFixed(2)} $origenEtiqueta registrado ($motivo)',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
    final esQr = _origen == 'BANCO_QR';

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              const SizedBox(height: 14),

              const Text(
                'Registrar Movimiento / Retiro',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),

              // 1. SELECTOR DE ORIGEN: CAJÓN FÍSICO VS BANCO / QR (ATM)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _origen = 'EFECTIVO_CAJA';
                          if (_categoria == 'CAMBIO_SENCILLO') {
                            _categoria = 'GASTO_TIENDA';
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !esQr ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.payments_outlined,
                                color: !esQr ? Colors.white : AppColors.textMuted,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '💵 Del Cajón Físico',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: !esQr ? Colors.white : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _origen = 'BANCO_QR'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: esQr ? Colors.blue[700] : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.atm,
                                color: esQr ? Colors.white : AppColors.textMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '📱 Del QR (Cajero ATM)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: esQr ? Colors.white : AppColors.textMuted,
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
              const SizedBox(height: 12),

              // 2. SELECTOR DE TIPO: SALIDA VS ENTRADA
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: esSalida ? AppColors.danger.withAlpha(20) : Colors.transparent,
                        side: BorderSide(
                          color: esSalida ? AppColors.danger : AppColors.border,
                          width: esSalida ? 2 : 1,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => setState(() => _tipo = 'SALIDA'),
                      icon: Icon(Icons.arrow_upward, color: esSalida ? AppColors.danger : AppColors.textMuted, size: 18),
                      label: Text(
                        'Salida / Retiro',
                        style: TextStyle(
                          color: esSalida ? AppColors.danger : AppColors.textMuted,
                          fontWeight: esSalida ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: !esSalida ? AppColors.success.withAlpha(20) : Colors.transparent,
                        side: BorderSide(
                          color: !esSalida ? AppColors.success : AppColors.border,
                          width: !esSalida ? 2 : 1,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => setState(() => _tipo = 'ENTRADA'),
                      icon: Icon(Icons.arrow_downward, color: !esSalida ? AppColors.success : AppColors.textMuted, size: 18),
                      label: Text(
                        'Ingreso / Aporte',
                        style: TextStyle(
                          color: !esSalida ? AppColors.success : AppColors.textMuted,
                          fontWeight: !esSalida ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. CAMPO MONTO
              Text(
                esSalida
                    ? (esQr ? 'Monto retirado del Banco/QR (Bs.)' : 'Monto a sacar del cajón (Bs.)')
                    : 'Monto a ingresar (Bs.)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _montoController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: esSalida ? (esQr ? Colors.blue[800] : AppColors.danger) : AppColors.success,
                ),
                decoration: InputDecoration(
                  prefixText: 'Bs. ',
                  prefixStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: esSalida ? (esQr ? Colors.blue[800] : AppColors.danger) : AppColors.success,
                  ),
                  hintText: '0.00',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 8),

              // Atajos rápidos de monto (+10, +20, +50, +100)
              Row(
                children: [
                  for (final val in [10.0, 20.0, 50.0, 100.0, 200.0])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _sumarMonto(val),
                          child: Text('+${val.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. CATEGORÍA / DESTINO DEL DINERO (1 TOQUE)
              Row(
                children: [
                  Text(
                    esSalida ? '¿Para qué es este retiro?' : '¿Origen del ingreso?',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    _categoria == 'RETIRO_PERSONAL'
                        ? '🏠 Uso Personal'
                        : (_categoria == 'MERCADERIA_FUTURA' ? '📦 Mercadería' : '🏬 Negocio'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _categoria == 'RETIRO_PERSONAL' ? Colors.orange[800] : AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (esSalida) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ChipCategoria(
                      emoji: '📦',
                      titulo: 'Mercadería Futura',
                      subtitulo: 'Para repartidor/camión',
                      isSelected: _categoria == 'MERCADERIA_FUTURA',
                      onTap: () => _seleccionarCategoria('MERCADERIA_FUTURA', 'Apartado para repartidor de mercadería'),
                    ),
                    _ChipCategoria(
                      emoji: '🧹',
                      titulo: 'Gasto de la Tienda',
                      subtitulo: 'Luz, bolsas, hielo, limpieza',
                      isSelected: _categoria == 'GASTO_TIENDA',
                      onTap: () => _seleccionarCategoria('GASTO_TIENDA', 'Gasto operativo de tienda'),
                    ),
                    _ChipCategoria(
                      emoji: '🧑‍🤝‍🧑',
                      titulo: 'Pago a Ayudante',
                      subtitulo: 'Sueldo o jornal',
                      isSelected: _categoria == 'PAGO_AYUDANTE',
                      onTap: () => _seleccionarCategoria('PAGO_AYUDANTE', 'Pago de jornal a ayudante'),
                    ),
                    _ChipCategoria(
                      emoji: '🏦',
                      titulo: 'Ahorro / Colchón',
                      subtitulo: 'Reserva de emergencia',
                      isSelected: _categoria == 'AHORRO',
                      onTap: () => _seleccionarCategoria('AHORRO', 'Ahorro reserva de emergencia'),
                    ),
                    _ChipCategoria(
                      emoji: '💰',
                      titulo: 'Retiro Personal',
                      subtitulo: 'Gastos de casa / Dueño',
                      isSelected: _categoria == 'RETIRO_PERSONAL',
                      onTap: () => _seleccionarCategoria('RETIRO_PERSONAL', 'Retiro de ganancia para la casa'),
                    ),
                    if (esQr)
                      _ChipCategoria(
                        emoji: '💵',
                        titulo: 'Sencillo a Caja',
                        subtitulo: 'Cajero ATM a gaveta',
                        isSelected: _categoria == 'CAMBIO_SENCILLO',
                        onTap: () => _seleccionarCategoria('CAMBIO_SENCILLO', 'Sencillo retirado de ATM para cajón'),
                      ),
                    _ChipCategoria(
                      emoji: '📝',
                      titulo: 'Otro motivo',
                      subtitulo: 'Especificar abajo',
                      isSelected: _categoria == 'OTRO',
                      onTap: () => _seleccionarCategoria('OTRO', ''),
                    ),
                  ],
                ),
              ] else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ChipCategoria(
                      emoji: '💵',
                      titulo: 'Cambio Sencillo',
                      subtitulo: 'Monedas / Billetes chicos',
                      isSelected: _categoria == 'CAMBIO_SENCILLO',
                      onTap: () => _seleccionarCategoria('CAMBIO_SENCILLO', 'Cambio o sencillo adicional'),
                    ),
                    _ChipCategoria(
                      emoji: '💰',
                      titulo: 'Fondo Extra Dueño',
                      subtitulo: 'Inyección de capital',
                      isSelected: _categoria == 'OTRO',
                      onTap: () => _seleccionarCategoria('OTRO', 'Aporte de capital propio'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),

              // Notificación especial si es Retiro QR para Sencillo a Caja
              if (esQr && _categoria == 'CAMBIO_SENCILLO' && esSalida) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.sync_alt, color: Colors.blue),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '💡 Este retiro de tu cuenta QR se sumará automáticamente a tu cajón físico en efectivo.',
                          style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 5. MOTIVO / DETALLE OPCIONAL
              const Text(
                'Detalle / Nota rápida (opcional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _motivoController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ej. Bolsas plásticas, Coca-Cola distribuidor, pan...',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),

              // 6. BOTÓN CONFIRMAR
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: esSalida
                        ? (esQr ? Colors.blue[800] : AppColors.danger)
                        : AppColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isProcessing ? null : _guardar,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Icon(esSalida ? Icons.check_circle_outline : Icons.add_circle_outline, color: Colors.white),
                  label: Text(
                    _isProcessing
                        ? 'Registrando...'
                        : (esSalida
                            ? (esQr ? 'REGISTRAR RETIRO QR / ATM' : 'REGISTRAR SALIDA DEL CAJÓN')
                            : 'REGISTRAR INGRESO'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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

class _ChipCategoria extends StatelessWidget {
  final String emoji;
  final String titulo;
  final String subtitulo;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChipCategoria({
    required this.emoji,
    required this.titulo,
    required this.subtitulo,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(20) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitulo,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? AppColors.primary.withAlpha(200) : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
