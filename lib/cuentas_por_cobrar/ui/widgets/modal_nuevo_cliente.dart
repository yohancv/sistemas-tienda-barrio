import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../state/providers/clientes_providers.dart';

class ModalNuevoCliente extends ConsumerStatefulWidget {
  const ModalNuevoCliente({super.key});

  @override
  ConsumerState<ModalNuevoCliente> createState() => _ModalNuevoClienteState();
}

class _ModalNuevoClienteState extends ConsumerState<ModalNuevoCliente> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _limiteController = TextEditingController(text: '100');

  double _limiteSeleccionado = 100.0;
  bool _guardando = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _limiteController.dispose();
    super.dispose();
  }

  void _seleccionarLimite(double limite) {
    setState(() {
      _limiteSeleccionado = limite;
      _limiteController.text = limite.toInt().toString();
    });
  }

  void _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    final limite = double.tryParse(_limiteController.text) ?? 100.0;
    final nuevoCliente = await ref.read(clientesNotifierProvider.notifier).crearCliente(
          nombre: _nombreController.text,
          telefono: _telefonoController.text,
          limiteCredito: limite,
        );

    if (mounted) {
      setState(() => _guardando = false);
      if (nuevoCliente != null) {
        Navigator.pop(context, nuevoCliente);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '➕ Registrar Nuevo Vecino / Cliente',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nombre (Obligatorio)
              TextFormField(
                controller: _nombreController,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Nombre Completo o Apodo *',
                  hintText: 'Ej. Don Carlos, Doña Martha...',
                  prefixIcon: const Icon(Icons.person, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa el nombre del vecino';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Teléfono / WhatsApp (Opcional)
              TextFormField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  labelText: 'Celular / WhatsApp (Opcional)',
                  hintText: 'Ej. 71234567',
                  prefixIcon: const Icon(Icons.phone, color: AppColors.secondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Límite de Crédito
              const Text(
                'LÍMITE MÁXIMO DE FIADO (BS.):',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),

              // Campo de texto editable para cualquier monto personalizado
              TextFormField(
                controller: _limiteController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Monto Límite de Fiado *',
                  hintText: 'Ej. 100, 500, 1000...',
                  prefixText: 'Bs. ',
                  prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  prefixIcon: const Icon(Icons.credit_card, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) {
                  final parsed = double.tryParse(val.trim().replaceAll(',', '.'));
                  setState(() {
                    _limiteSeleccionado = parsed ?? 0.0;
                  });
                },
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa un monto límite';
                  }
                  final n = double.tryParse(val.replaceAll(',', '.'));
                  if (n == null || n < 0) {
                    return 'Ingresa un número válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Chips sugeridos rápidos (Wrap responsivo sin desbordamiento)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [50.0, 100.0, 150.0, 200.0, 300.0, 500.0, 1000.0].map((limite) {
                  final seleccionado = (_limiteSeleccionado == limite);
                  return ChoiceChip(
                    label: Text('Bs. ${limite.toInt()}'),
                    selected: seleccionado,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: seleccionado ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    onSelected: (_) => _seleccionarLimite(limite),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              const Text(
                '💡 Puedes escribir cualquier monto personalizado en el cuadro o tocar un botón rápido.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),

              const SizedBox(height: 24),

              // Botón Masivo Guardar (60dp)
              SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.check, color: Colors.white, size: 26),
                  label: Text(
                    _guardando ? 'Guardando...' : 'Guardar Cliente',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
