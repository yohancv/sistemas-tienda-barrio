import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cierre_caja/state/providers/caja_providers.dart';
import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/models/operadora_model.dart';
import '../../data/models/recarga_model.dart';
import '../../state/providers/recargas_providers.dart';

class ModalRegistroRecargaRapida extends ConsumerStatefulWidget {
  const ModalRegistroRecargaRapida({super.key});

  @override
  ConsumerState<ModalRegistroRecargaRapida> createState() =>
      _ModalRegistroRecargaRapidaState();
}

class _ModalRegistroRecargaRapidaState
    extends ConsumerState<ModalRegistroRecargaRapida> {
  OperadoraModel? _operadora;
  double _monto = 10.0;
  bool _montoPersonalizado = false;
  final TextEditingController _montoCustomController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  TipoRecarga _tipo = TipoRecarga.credito;
  MetodoPagoRecarga _metodoPago = MetodoPagoRecarga.efectivo;
  bool _guardando = false;

  final List<double> _montosRapidos = [5.0, 10.0, 15.0, 20.0, 30.0, 50.0];

  @override
  void dispose() {
    _montoCustomController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Color _obtenerColorOperadora(String id) {
    switch (id.toUpperCase()) {
      case 'ENTEL':
        return const Color(0xFF005CA9);
      case 'TIGO':
        return const Color(0xFF00377B);
      case 'VIVA':
        return const Color(0xFF7DB637);
      default:
        return const Color(0xFF4F46E5);
    }
  }

  Future<void> _guardarRecarga(OperadoraModel op) async {
    final montoFinal = _montoPersonalizado
        ? double.tryParse(_montoCustomController.text.replaceAll(',', '.')) ?? 0.0
        : _monto;

    if (montoFinal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa un monto válido mayor a 0 Bs.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final repo = ref.read(recargasRepositoryProvider);
      final turno = ref.read(cajaTurnoActivaProvider).valueOrNull;

      await repo.registrarVentaRecarga(
        tenantId: SupabaseConfig.defaultTenantId,
        operadora: op,
        tipo: _tipo,
        monto: montoFinal,
        metodoPago: _metodoPago,
        numeroTelefono: _telefonoController.text,
        cajaTurnoId: turno?.id,
      );

      // Refrescar estado reactivo
      ref.invalidate(operadorasListProvider);
      ref.invalidate(recargasTurnoProvider);
      ref.invalidate(resumenRecargasTurnoProvider);
      ref.invalidate(resumenCajaTurnoProvider);
      ref.invalidate(movimientosCajaTurnoProvider);

      if (!mounted) return;
      Navigator.of(context).pop();

      final ganancia = montoFinal * (op.comisionPorcentaje / 100.0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Recarga de Bs. ${montoFinal.toStringAsFixed(2)} a ${op.nombre} registrada (Ganancia: Bs. ${ganancia.toStringAsFixed(2)})',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar recarga: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final operadorasAsync = ref.watch(operadorasActivasProvider);
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Slate oscuro elegante
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + (isKeyboardOpen ? MediaQuery.of(context).viewInsets.bottom : 12),
      ),
      child: operadorasAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error cargando operadoras: $e', style: const TextStyle(color: Colors.redAccent)),
        ),
        data: (operadoras) {
          if (operadoras.isEmpty) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                const Icon(Icons.signal_cellular_connected_no_internet_0_bar_rounded,
                    color: Colors.amber, size: 48),
                const SizedBox(height: 14),
                const Text(
                  'No hay operadoras activas',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Activa Entel, Tigo o Viva desde el menú superior (⋮) > Recargas & Servicios.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155)),
                  child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }

          // Seleccionar la primera operadora por defecto si no hay seleccionada
          _operadora ??= operadoras.first;
          final op = _operadora!;
          final colorOp = _obtenerColorOperadora(op.id);

          final montoCalculo = _montoPersonalizado
              ? double.tryParse(_montoCustomController.text.replaceAll(',', '.')) ?? 0.0
              : _monto;
          final gananciaEstimada = montoCalculo * (op.comisionPorcentaje / 100.0);
          final costoEstimado = montoCalculo - gananciaEstimada;

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra superior de arrastre
                Center(
                  child: Container(
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Cabecera Modal
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorOp.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorOp.withValues(alpha: 0.4)),
                      ),
                      child: Icon(Icons.phone_android_rounded, color: colorOp, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registro Rápido de Recarga',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'El cliente pagó y se transfiere el saldo en tienda',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. Selector de Operadora (Botones con color de marca)
                const Text(
                  '1. SELECCIONA LA LÍNEA',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                ),
                const SizedBox(height: 8),
                Row(
                  children: operadoras.map<Widget>((OperadoraModel item) {
                    final isSel = item.id == op.id;
                    final itemColor = _obtenerColorOperadora(item.id);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () => setState(() => _operadora = item),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSel ? itemColor : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? Colors.white : Colors.white12,
                                width: isSel ? 2 : 1,
                              ),
                              boxShadow: isSel
                                  ? [BoxShadow(color: itemColor.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(0, 1))]
                                  : null,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  item.nombre,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: isSel ? FontWeight.w900 : FontWeight.bold,
                                  ),
                                ),
                                if (item.saldoActual > 0)
                                  Text(
                                    'Bs. ${item.saldoActual.toStringAsFixed(0)} disp.',
                                    style: TextStyle(
                                      color: isSel ? Colors.white70 : const Color(0xFF64748B),
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 2. Selector de Monto (Botones Rápidos)
                const Text(
                  '2. MONTO RECARGADO',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._montosRapidos.map((m) {
                      final isSel = !_montoPersonalizado && _monto == m;
                      return ChoiceChip(
                        label: Text(
                          'Bs. ${m.toInt()}',
                          style: TextStyle(
                            color: isSel ? Colors.white : const Color(0xFFCBD5E1),
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                        selected: isSel,
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFF1E293B),
                        side: BorderSide(color: isSel ? const Color(0xFF60A5FA) : Colors.white10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _monto = m;
                              _montoPersonalizado = false;
                            });
                          }
                        },
                      );
                    }),
                    ChoiceChip(
                      label: Text(
                        'Otro monto',
                        style: TextStyle(
                          color: _montoPersonalizado ? Colors.white : const Color(0xFFCBD5E1),
                          fontWeight: _montoPersonalizado ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                      selected: _montoPersonalizado,
                      selectedColor: const Color(0xFF2563EB),
                      backgroundColor: const Color(0xFF1E293B),
                      side: BorderSide(color: _montoPersonalizado ? const Color(0xFF60A5FA) : Colors.white10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      onSelected: (val) {
                        setState(() {
                          _montoPersonalizado = true;
                        });
                      },
                    ),
                  ],
                ),

                if (_montoPersonalizado) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _montoCustomController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+[\.,]?\d{0,2}'))],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Ingresa el monto (ej. 12.50)',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      prefixText: 'Bs. ',
                      prefixStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // 3. Tipo de Recarga & Medio de Cobro
                Row(
                  children: [
                    // Tipo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TIPO',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _tipo = TipoRecarga.credito),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _tipo == TipoRecarga.credito ? const Color(0xFF334155) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Crédito',
                                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _tipo = TipoRecarga.paqueteInternet),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _tipo == TipoRecarga.paqueteInternet ? const Color(0xFF334155) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'Internet',
                                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Cobro
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PAGO DEL CLIENTE',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _metodoPago = MetodoPagoRecarga.efectivo),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _metodoPago == MetodoPagoRecarga.efectivo
                                            ? const Color(0xFF065F46)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '💵 Efectivo',
                                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _metodoPago = MetodoPagoRecarga.qr),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _metodoPago == MetodoPagoRecarga.qr
                                            ? const Color(0xFF0369A1)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '📱 QR',
                                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4. Teléfono del cliente (OPCIONAL)
                TextField(
                  controller: _telefonoController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Número de celular del cliente (Opcional)',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                    prefixIcon: const Icon(Icons.dialpad_rounded, color: Color(0xFF94A3B8), size: 18),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Card informativo de ganancia neta
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1B2A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E3A5F)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on_outlined, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ganancia neta: Bs. ${gananciaEstimada.toStringAsFixed(2)} (${op.comisionPorcentaje.toStringAsFixed(0)}%) • Costo saldo: Bs. ${costoEstimado.toStringAsFixed(2)}',
                          style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 6. Botón de Confirmación en 1 toque
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorOp,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _guardando ? null : () => _guardarRecarga(op),
                    child: _guardando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'REGISTRAR RECARGA • BS. ${montoCalculo.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
