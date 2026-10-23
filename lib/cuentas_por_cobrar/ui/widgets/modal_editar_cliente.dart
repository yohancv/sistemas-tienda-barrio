import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/app_haptics.dart';
import '../../data/models/cliente_model.dart';
import '../../state/providers/clientes_providers.dart';

/// Modal para editar el Límite de Fiado y datos de un cliente/vecino
class ModalEditarCliente extends ConsumerStatefulWidget {
  final Cliente cliente;

  const ModalEditarCliente({
    super.key,
    required this.cliente,
  });

  @override
  ConsumerState<ModalEditarCliente> createState() => _ModalEditarClienteState();
}

class _ModalEditarClienteState extends ConsumerState<ModalEditarCliente> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _telefonoController;
  late final TextEditingController _limiteController;
  late final TextEditingController _notasController;

  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.cliente.nombre);
    _telefonoController = TextEditingController(text: widget.cliente.telefono ?? '');
    _limiteController = TextEditingController(
      text: widget.cliente.limiteCredito % 1 == 0
          ? widget.cliente.limiteCredito.toInt().toString()
          : widget.cliente.limiteCredito.toStringAsFixed(2),
    );
    _notasController = TextEditingController(text: widget.cliente.notas ?? '');

    _limiteController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _limiteController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  void _seleccionarLimite(double limite) {
    AppHaptics.selection();
    setState(() {
      _limiteController.text = limite % 1 == 0 ? limite.toInt().toString() : limite.toStringAsFixed(2);
      _error = null;
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final limiteTexto = _limiteController.text.trim().replaceAll(',', '.');
    final limite = double.tryParse(limiteTexto);

    if (limite == null || limite < 0) {
      setState(() => _error = 'Ingresa un límite válido en Bs. mayor o igual a 0');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      AppHaptics.medium();
      final clienteActualizado = await ref.read(clientesNotifierProvider.notifier).actualizarCliente(
            clienteId: widget.cliente.id,
            nombre: _nombreController.text.trim(),
            telefono: _telefonoController.text.trim(),
            limiteCredito: limite,
            notas: _notasController.text.trim(),
          );

      if (!mounted) return;
      setState(() => _guardando = false);

      if (clienteActualizado != null) {
        Navigator.pop(context, clienteActualizado);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              '¡Límite de fiado para "${clienteActualizado.nombre}" actualizado a Bs. ${clienteActualizado.limiteCredito.toStringAsFixed(2)}!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'Error al actualizar: $e';
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

    final saldoActual = widget.cliente.saldoActual;
    final nuevoLimite = double.tryParse(_limiteController.text.trim().replaceAll(',', '.')) ?? widget.cliente.limiteCredito;
    final disponibleResultante = nuevoLimite - saldoActual;
    final limiteMenorADeuda = nuevoLimite < saldoActual;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de arrastre
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
              const SizedBox(height: 14),

              // Cabecera
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 24),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Editar Límite de Fiado',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tarjeta Resumen Deuda Actual
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: esOscuro ? const Color(0xFF1E293B) : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CLIENTE / VECINO:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          widget.cliente.nombre,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('DEUDA ACTUAL:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          'Bs. ${saldoActual.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: saldoActual > 0 ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Campo 1: Límite de Fiado (Destacado)
              Text(
                'Límite Máximo de Fiado (Crédito):',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Monto máximo en Bs. que este vecino puede acumular en deuda.',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _limiteController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                decoration: InputDecoration(
                  prefixText: 'Bs. ',
                  prefixStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                  labelText: 'Límite de Fiado *',
                  filled: true,
                  fillColor: esOscuro ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ingresa un límite en Bs.';
                  final n = double.tryParse(val.replaceAll(',', '.'));
                  if (n == null || n < 0) return 'Monto inválido';
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Chips de selección rápida
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildChip(50, 'Bs. 50', esOscuro),
                  _buildChip(100, 'Bs. 100', esOscuro),
                  _buildChip(150, 'Bs. 150', esOscuro),
                  _buildChip(200, 'Bs. 200', esOscuro),
                  _buildChip(300, 'Bs. 300', esOscuro),
                  _buildChip(500, 'Bs. 500', esOscuro),
                  _buildChip(1000, 'Bs. 1,000', esOscuro),
                ],
              ),
              const SizedBox(height: 12),

              // Indicador dinámico de disponible / advertencia
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: limiteMenorADeuda
                      ? Colors.orange.withValues(alpha: 0.15)
                      : const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: limiteMenorADeuda ? Colors.orange : const Color(0xFF10B981),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      limiteMenorADeuda ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      color: limiteMenorADeuda ? Colors.orange[800] : const Color(0xFF10B981),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        limiteMenorADeuda
                            ? 'El nuevo límite es menor a la deuda actual (Bs. ${saldoActual.toStringAsFixed(2)}). El cliente no podrá fiar más hasta que abone.'
                            : 'Crédito disponible para fiar: Bs. ${disponibleResultante.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: limiteMenorADeuda ? Colors.orange[900] : (esOscuro ? const Color(0xFF6EE7B7) : const Color(0xFF065F46)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Campo 2: Nombre Completo
              TextFormField(
                controller: _nombreController,
                style: TextStyle(fontSize: 15, color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nombre del Vecino / Cliente *',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: esOscuro ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'El nombre no puede estar vacío';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Campo 3: Teléfono WhatsApp
              TextFormField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                style: TextStyle(fontSize: 15, color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Teléfono / WhatsApp (opcional)',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  filled: true,
                  fillColor: esOscuro ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Campo 4: Notas / Dirección
              TextFormField(
                controller: _notasController,
                maxLines: 2,
                style: TextStyle(fontSize: 13, color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Notas / Dirección (opcional)',
                  filled: true,
                  fillColor: esOscuro ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

              // Botón Guardar
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 20),
                  label: Text(
                    _guardando ? 'Guardando cambios...' : 'Guardar Cambios de Límite',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(double valor, String etiqueta, bool esOscuro) {
    return ActionChip(
      label: Text(etiqueta, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      backgroundColor: esOscuro ? const Color(0xFF1E293B) : Colors.white,
      side: BorderSide(color: esOscuro ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      onPressed: () => _seleccionarLimite(valor),
    );
  }
}
