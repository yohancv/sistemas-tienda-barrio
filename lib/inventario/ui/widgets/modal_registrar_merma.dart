import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/models/producto_model.dart';
import '../../state/providers/inventario_providers.dart';
import '../../state/providers/movimientos_providers.dart';

class ModalRegistrarMerma extends ConsumerStatefulWidget {
  final Producto? productoInicial;

  const ModalRegistrarMerma({super.key, this.productoInicial});

  @override
  ConsumerState<ModalRegistrarMerma> createState() => _ModalRegistrarMermaState();
}

class _ModalRegistrarMermaState extends ConsumerState<ModalRegistrarMerma> {
  Producto? _productoSeleccionado;
  String _tipoMerma = 'MERMA_ROTURA';
  final _cantidadController = TextEditingController(text: '1');
  final _motivoController = TextEditingController();
  final _busquedaController = TextEditingController();
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _productoSeleccionado = widget.productoInicial;
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _motivoController.dispose();
    _busquedaController.dispose();
    super.dispose();
  }

  double get _cantidad =>
      double.tryParse(_cantidadController.text.replaceAll(',', '.')) ?? 0.0;

  double get _perdidaEstimada {
    if (_productoSeleccionado == null) return 0.0;
    return _productoSeleccionado!.costoMayorista * _cantidad;
  }

  void _seleccionarMotivoRapido(String motivo) {
    _motivoController.text = motivo;
    setState(() => _error = null);
  }

  Future<void> _guardar() async {
    if (_productoSeleccionado == null) {
      setState(() => _error = 'Debes seleccionar el producto afectado');
      return;
    }

    if (_cantidad <= 0) {
      setState(() => _error = 'La cantidad debe ser mayor a 0');
      return;
    }

    if (_cantidad > _productoSeleccionado!.stockActual) {
      setState(() => _error =
          'La cantidad (${_cantidad.toStringAsFixed(1)}) no puede ser mayor al stock actual (${_productoSeleccionado!.stockActual.toStringAsFixed(1)})');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    final exito = await ref.read(movimientosNotifierProvider.notifier).registrarMerma(
          producto: _productoSeleccionado!,
          cantidad: _cantidad,
          tipoMerma: _tipoMerma,
          motivo: _motivoController.text.trim().isEmpty
              ? null
              : _motivoController.text.trim(),
        );

    if (!mounted) return;

    if (exito) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(
            'Merma de ${_cantidad.toStringAsFixed(_productoSeleccionado!.esFraccionable ? 2 : 0)} ${_productoSeleccionado!.nombre} registrada.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else {
      final estado = ref.read(movimientosNotifierProvider);
      setState(() {
        _error = estado.errorMessage ?? 'Error al registrar la merma';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosListProvider);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Indicador de arrastre
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.broken_image, color: AppColors.danger, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registrar Merma / Rotura',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Baja de stock por accidente, rotura o vencimiento',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 26),

              // 1. Selector de Producto
              const Text(
                'Producto Afectado',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              if (_productoSeleccionado != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _productoSeleccionado!.nombre,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              'Stock: ${_productoSeleccionado!.stockActual.toStringAsFixed(_productoSeleccionado!.esFraccionable ? 2 : 0)} | Costo: Bs. ${_productoSeleccionado!.costoMayorista.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Cambiar producto',
                        onPressed: () => setState(() => _productoSeleccionado = null),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                productosAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error al cargar productos: $e'),
                  data: (todos) {
                    final query = _busquedaController.text.toLowerCase().trim();
                    final filtrados = query.isEmpty
                        ? todos.take(5).toList()
                        : todos
                            .where((p) =>
                                p.nombre.toLowerCase().contains(query) ||
                                (p.codigoBarras?.contains(query) ?? false))
                            .take(5)
                            .toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _busquedaController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre o código...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...filtrados.map((p) => ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              tileColor: AppColors.background,
                              title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('Stock: ${p.stockActual.toStringAsFixed(p.esFraccionable ? 2 : 0)}'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                              onTap: () {
                                setState(() {
                                  _productoSeleccionado = p;
                                  _busquedaController.clear();
                                });
                              },
                            )),
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),

              // 2. Tipo de Merma
              const Text(
                'Tipo de Merma',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'MERMA_ROTURA', label: Text('💥 Rotura'), icon: Icon(Icons.broken_image, size: 16)),
                  ButtonSegment(value: 'MERMA_VENCIMIENTO', label: Text('⏳ Vencido'), icon: Icon(Icons.timer_off, size: 16)),
                  ButtonSegment(value: 'MERMA_DETERIORO', label: Text('📦 Dañado'), icon: Icon(Icons.inventory_2, size: 16)),
                ],
                selected: {_tipoMerma},
                onSelectionChanged: (vals) => setState(() => _tipoMerma = vals.first),
              ),
              const SizedBox(height: 16),

              // 3. Cantidad y Tarjeta de Pérdida Financiera
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cantidad a dar de baja',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _cantidadController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.danger),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*[\.,]?\d{0,2}')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pérdida en Costo',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 58,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: AppColors.danger.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.danger.withAlpha(80)),
                          ),
                          child: Text(
                            '- Bs. ${_perdidaEstimada.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4. Motivo / Justificación
              const Text(
                'Motivo u Observación',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _motivoController,
                decoration: InputDecoration(
                  hintText: 'Ej. Se cayó al acomodar el mostrador',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),

              // Chips sugeridos
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  'Caída al limpiar',
                  'Llegó rota de fábrica',
                  'Fecha de vencimiento cumplida',
                  'Empaque dañado',
                ]
                    .map((m) => ActionChip(
                          label: Text(m, style: const TextStyle(fontSize: 11)),
                          onPressed: () => _seleccionarMotivoRapido(m),
                        ))
                    .toList(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
              const SizedBox(height: 22),

              // Botón Guardar Merma
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isProcessing ? null : _guardar,
                  icon: _isProcessing
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check, color: Colors.white),
                  label: Text(
                    _isProcessing ? 'Registrando baja...' : 'CONFIRMAR MERMA Y DESCONTAR',
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
