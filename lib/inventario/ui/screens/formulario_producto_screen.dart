import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../data/models/producto_model.dart';
import '../../state/providers/inventario_providers.dart';

enum TipoProductoUi { unidad, granel, dual }

class FormularioProductoScreen extends ConsumerStatefulWidget {
  final Producto? productoParaEditar;

  const FormularioProductoScreen({
    super.key,
    this.productoParaEditar,
  });

  @override
  ConsumerState<FormularioProductoScreen> createState() =>
      _FormularioProductoScreenState();
}

class _FormularioProductoScreenState
    extends ConsumerState<FormularioProductoScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreController;
  late final TextEditingController _codigoBarrasController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _costoMayoristaController;
  late final TextEditingController _precioVentaController;
  late final TextEditingController _stockActualController;
  late final TextEditingController _stockMinimoController;

  // Venta Dual
  late final TextEditingController _nombreUnidadSueltaController;
  late final TextEditingController _unidadesEnEmpaqueVentaController;
  late final TextEditingController _precioVentaSueltaController;

  // Empaque Mayorista / Caja Padre
  bool _esEmpaqueMayorista = false;
  String _tipoEmpaque = 'CAJA';
  late final TextEditingController _unidadesPorEmpaqueController;
  late final TextEditingController _costoPorEmpaqueController;
  String? _productoHijoSeleccionadoId;

  TipoProductoUi _tipoProducto = TipoProductoUi.unidad;
  bool _guardando = false;

  // FocusNodes para soporte de pistola lectora de barras (Fase 2)
  late final FocusNode _codigoBarrasFocusNode;
  late final FocusNode _nombreFocusNode;

  // Validación de código de barras duplicado (Fase 1)
  Producto? _productoConflicto;
  bool _verificandoCodigo = false;

  // Valores iniciales para detección de cambios sin guardar (Fase 4 - PopScope)
  late final String _inicialNombre;
  late final String _inicialCodigo;
  late final String _inicialDescripcion;
  late final String _inicialCosto;
  late final String _inicialPrecio;
  late final String _inicialStockActual;
  late final String _inicialStockMinimo;

  bool get _esEdicion => widget.productoParaEditar != null;

  @override
  void initState() {
    super.initState();
    final p = widget.productoParaEditar;

    _nombreController = TextEditingController(text: p?.nombre ?? '');
    _codigoBarrasController = TextEditingController(text: p?.codigoBarras ?? '');
    _descripcionController = TextEditingController(text: p?.descripcion ?? '');
    _costoMayoristaController = TextEditingController(
      text: p != null ? p.costoMayorista.toStringAsFixed(2) : '',
    );
    _precioVentaController = TextEditingController(
      text: p != null ? p.precioVenta.toStringAsFixed(2) : '',
    );
    _stockActualController = TextEditingController(
      text: p != null
          ? (p.stockActual.truncateToDouble() == p.stockActual
              ? p.stockActual.toInt().toString()
              : p.stockActual.toStringAsFixed(2))
          : '0',
    );
    _stockMinimoController = TextEditingController(
      text: p != null
          ? (p.stockMinimo.truncateToDouble() == p.stockMinimo
              ? p.stockMinimo.toInt().toString()
              : p.stockMinimo.toStringAsFixed(2))
          : '5',
    );

    // Venta Dual
    _nombreUnidadSueltaController = TextEditingController(
      text: p?.nombreUnidadSuelta ?? 'unidad',
    );
    _unidadesEnEmpaqueVentaController = TextEditingController(
      text: p != null && p.unidadesEnEmpaqueVenta > 0
          ? p.unidadesEnEmpaqueVenta.toInt().toString()
          : '20',
    );
    _precioVentaSueltaController = TextEditingController(
      text: p != null && p.precioVentaSuelta > 0
          ? p.precioVentaSuelta.toStringAsFixed(2)
          : '',
    );

    // Empaque mayorista
    _esEmpaqueMayorista = p != null && p.tipoEmpaque != 'UNIDAD';
    _tipoEmpaque = p != null && p.tipoEmpaque != 'UNIDAD' ? p.tipoEmpaque : 'CAJA';
    _unidadesPorEmpaqueController = TextEditingController(
      text: p != null && p.unidadesPorEmpaque > 0
          ? p.unidadesPorEmpaque.toInt().toString()
          : '12',
    );
    _costoPorEmpaqueController = TextEditingController(
      text: p != null && p.costoPorEmpaque > 0
          ? p.costoPorEmpaque.toStringAsFixed(2)
          : '',
    );
    _productoHijoSeleccionadoId = p?.productoHijoId;

    // Determinar Tipo UI
    if (p != null) {
      if (p.esFraccionable) {
        _tipoProducto = TipoProductoUi.granel;
      } else if (p.permiteVentaSuelta) {
        _tipoProducto = TipoProductoUi.dual;
      } else {
        _tipoProducto = TipoProductoUi.unidad;
      }
    }

    // FocusNodes para pistola de barras
    _codigoBarrasFocusNode = FocusNode();
    _nombreFocusNode = FocusNode();

    // Guardar valores iniciales para detección de cambios sin guardar (PopScope)
    _inicialNombre = _nombreController.text;
    _inicialCodigo = _codigoBarrasController.text;
    _inicialDescripcion = _descripcionController.text;
    _inicialCosto = _costoMayoristaController.text;
    _inicialPrecio = _precioVentaController.text;
    _inicialStockActual = _stockActualController.text;
    _inicialStockMinimo = _stockMinimoController.text;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _codigoBarrasController.dispose();
    _descripcionController.dispose();
    _costoMayoristaController.dispose();
    _precioVentaController.dispose();
    _stockActualController.dispose();
    _stockMinimoController.dispose();
    _nombreUnidadSueltaController.dispose();
    _unidadesEnEmpaqueVentaController.dispose();
    _precioVentaSueltaController.dispose();
    _unidadesPorEmpaqueController.dispose();
    _costoPorEmpaqueController.dispose();
    _codigoBarrasFocusNode.dispose();
    _nombreFocusNode.dispose();
    super.dispose();
  }

  double _parse(TextEditingController ctrl) {
    final clean = ctrl.text.trim().replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }

  /// Detecta si hay campos modificados respecto a los valores iniciales (Fase 4)
  bool get _tieneCambiosSinGuardar {
    return _nombreController.text != _inicialNombre ||
        _codigoBarrasController.text != _inicialCodigo ||
        _descripcionController.text != _inicialDescripcion ||
        _costoMayoristaController.text != _inicialCosto ||
        _precioVentaController.text != _inicialPrecio ||
        _stockActualController.text != _inicialStockActual ||
        _stockMinimoController.text != _inicialStockMinimo;
  }

  /// Validación de código de barras contra duplicados en la base de datos (Fase 1)
  Future<void> _verificarCodigoBarras(String codigo) async {
    if (codigo.trim().isEmpty) {
      setState(() {
        _productoConflicto = null;
        _verificandoCodigo = false;
      });
      return;
    }

    setState(() => _verificandoCodigo = true);

    final conflicto = await ref
        .read(productoOperacionProvider.notifier)
        .verificarCodigoBarras(
          codigo,
          excluirProductoId: widget.productoParaEditar?.id,
        );

    if (!mounted) return;
    setState(() {
      _productoConflicto = conflicto;
      _verificandoCodigo = false;
    });
  }

  /// Callback para pistola lectora: al enviar Enter, verifica código y salta al nombre (Fase 2)
  void _onCodigoBarrasSubmitted(String valor) {
    _verificarCodigoBarras(valor);
    if (_productoConflicto == null) {
      _nombreFocusNode.requestFocus();
    }
  }

  void _guardar() async {
    // Bloquear guardado si hay código de barras duplicado
    if (_productoConflicto != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(
            'El código de barras "${_codigoBarrasController.text}" ya pertenece a "${_productoConflicto!.nombre}". Cámbialo o edita ese producto.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final costo = _parse(_costoMayoristaController);
      final precio = _parse(_precioVentaController);
      final stockActual = _parse(_stockActualController);
      final stockMinimo = _parse(_stockMinimoController);

      final p = widget.productoParaEditar;

      final productoAGuardar = Producto(
        id: p?.id ?? '',
        tenantId: p?.tenantId ?? SupabaseConfig.defaultTenantId,
        codigoBarras: _codigoBarrasController.text.trim().isEmpty
            ? null
            : _codigoBarrasController.text.trim(),
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim().isEmpty
            ? null
            : _descripcionController.text.trim(),
        tipoUnidad: _tipoProducto == TipoProductoUi.granel ? 'FRACCIONABLE' : 'UNIDAD',
        stockActual: stockActual,
        stockMinimo: stockMinimo,
        costoMayorista: costo,
        precioVenta: precio,
        estadoActivo: true,
        createdAt: p?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),

        // Empaque Mayorista
        tipoEmpaque: _esEmpaqueMayorista ? _tipoEmpaque : 'UNIDAD',
        unidadesPorEmpaque: _esEmpaqueMayorista ? _parse(_unidadesPorEmpaqueController) : 1.0,
        costoPorEmpaque: _esEmpaqueMayorista ? _parse(_costoPorEmpaqueController) : 0.0,
        productoHijoId: _esEmpaqueMayorista ? _productoHijoSeleccionadoId : null,

        // Venta Dual
        permiteVentaSuelta: _tipoProducto == TipoProductoUi.dual,
        nombreUnidadSuelta: _nombreUnidadSueltaController.text.trim().isEmpty
            ? 'unidad'
            : _nombreUnidadSueltaController.text.trim(),
        unidadesEnEmpaqueVenta: _tipoProducto == TipoProductoUi.dual
            ? _parse(_unidadesEnEmpaqueVentaController)
            : 1.0,
        precioVentaSuelta: _tipoProducto == TipoProductoUi.dual
            ? _parse(_precioVentaSueltaController)
            : 0.0,
      );

      // Fase 5: Pasar stockAnterior para auditoría inmutable
      final resultado = await ref
          .read(productoOperacionProvider.notifier)
          .guardarProducto(
            productoAGuardar,
            stockAnterior: _esEdicion ? p!.stockActual : null,
          );

      if (!mounted) return;
      setState(() => _guardando = false);

      if (resultado != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              _esEdicion
                  ? '¡Producto "${resultado.nombre}" actualizado!'
                  : '¡Producto "${resultado.nombre}" guardado con éxito!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        );
        Navigator.pop(context, resultado);
      } else {
        final err = ref.read(productoOperacionProvider).errorMessage ?? 'Error desconocido';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.danger, content: Text(err)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.danger, content: Text('Error: $e')),
      );
    }
  }

  void _confirmarDesactivar() async {
    final p = widget.productoParaEditar;
    if (p == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Retirar este producto?'),
        content: Text(
          'El producto "${p.nombre}" dejará de aparecer en el catálogo y punto de venta. Los registros históricos de ventas anteriores no se verán afectados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, retirar producto', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      setState(() => _guardando = true);
      final exito = await ref
          .read(productoOperacionProvider.notifier)
          .desactivarProducto(p.id, p.nombre);

      if (!mounted) return;
      setState(() => _guardando = false);

      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.warning,
            content: Text('Producto "${p.nombre}" retirado del inventario.'),
          ),
        );
        Navigator.pop(context, null);
      }
    }
  }

  /// Diálogo de confirmación para salir con cambios sin guardar (Fase 4)
  Future<bool> _confirmarDescartarCambios() async {
    if (!_tieneCambiosSinGuardar) return true;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.warning),
        title: const Text('¿Descartar cambios?'),
        content: const Text(
          'Tienes información sin guardar que se perderá si sales ahora.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar editando', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );

    return confirmar ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final todosLosProductos = ref.watch(productosListProvider).maybeWhen(
          data: (l) => l.where((item) => item.id != widget.productoParaEditar?.id).toList(),
          orElse: () => <Producto>[],
        );

    final costo = _parse(_costoMayoristaController);
    final precio = _parse(_precioVentaController);
    final ganancia = precio - costo;
    // Fase 3: Doble cálculo de rentabilidad
    final markup = costo > 0 ? (ganancia / costo) * 100 : 0.0;
    final margenBruto = precio > 0 ? (ganancia / precio) * 100 : 0.0;

    // Fase 4: PopScope para prevenir salir sin guardar
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final puedeIrse = await _confirmarDescartarCambios();
        if (puedeIrse && mounted) {
          // ignore: use_build_context_synchronously
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            _esEdicion ? 'Editar Producto' : 'Nuevo Producto',
            style: AppTypography.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppColors.primary,
          elevation: 0,
          actions: [
            if (_esEdicion)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 28, color: Colors.white),
                tooltip: 'Retirar producto',
                onPressed: _guardando ? null : _confirmarDesactivar,
              ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. SECCIÓN BÁSICA
                  _buildCard(
                    titulo: '📦 Información Básica',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nombreController,
                          focusNode: _nombreFocusNode,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            labelText: 'Nombre del Producto *',
                            hintText: 'Ej. Cerveza Paceña 710ml, Pollo Sofía',
                            prefixIcon: Icon(Icons.label_outline, color: AppColors.primary),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'El nombre del producto es obligatorio';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        // Fase 1 y 2: Campo de código de barras con validación y soporte de pistola
                        TextFormField(
                          controller: _codigoBarrasController,
                          focusNode: _codigoBarrasFocusNode,
                          style: const TextStyle(fontSize: 16),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: _onCodigoBarrasSubmitted,
                          onChanged: (valor) {
                            setState(() {});
                            // Verificar duplicados después de un breve delay al escribir manualmente
                            Future.delayed(const Duration(milliseconds: 500), () {
                              if (mounted && _codigoBarrasController.text == valor) {
                                _verificarCodigoBarras(valor);
                              }
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Código de Barras (Opcional)',
                            hintText: 'Ej. 777123456789',
                            prefixIcon: const Icon(Icons.qr_code_scanner, color: AppColors.textSecondary),
                            border: const OutlineInputBorder(),
                            suffixIcon: _verificandoCodigo
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.auto_fix_high, color: AppColors.primary),
                                    tooltip: 'Generar código rápido',
                                    onPressed: () {
                                      final cod = DateTime.now().millisecondsSinceEpoch.toString().substring(3);
                                      _codigoBarrasController.text = cod;
                                      _verificarCodigoBarras(cod);
                                      setState(() {});
                                    },
                                  ),
                          ),
                          validator: (v) {
                            if (_productoConflicto != null) {
                              return 'Este código ya pertenece a "${_productoConflicto!.nombre}"';
                            }
                            return null;
                          },
                        ),

                        // Fase 1: Banner de advertencia de código duplicado
                        if (_productoConflicto != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.warning, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '⚠️ Código ya registrado en: "${_productoConflicto!.nombre}"',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Cambia el código o edita el producto existente.',
                                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.open_in_new, color: AppColors.primary),
                                  tooltip: 'Abrir producto existente',
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FormularioProductoScreen(
                                          productoParaEditar: _productoConflicto!,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _descripcionController,
                          style: const TextStyle(fontSize: 15),
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Descripción / Categoría (Opcional)',
                            hintText: 'Ej. Licores, Abarrotes, Limpieza...',
                            prefixIcon: Icon(Icons.description_outlined, color: AppColors.textSecondary),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. SECCIÓN TIPO DE VENTA
                  _buildCard(
                    titulo: '⚖️ Modo de Venta al Público',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('🛒 Por Unidad', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              selected: _tipoProducto == TipoProductoUi.unidad,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: _tipoProducto == TipoProductoUi.unidad ? Colors.white : AppColors.textPrimary,
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _tipoProducto = TipoProductoUi.unidad);
                              },
                            ),
                            ChoiceChip(
                              label: const Text('⚖️ Granel / Kilo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              selected: _tipoProducto == TipoProductoUi.granel,
                              selectedColor: AppColors.secondary,
                              labelStyle: TextStyle(
                                color: _tipoProducto == TipoProductoUi.granel ? Colors.white : AppColors.textPrimary,
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _tipoProducto = TipoProductoUi.granel);
                              },
                            ),
                            ChoiceChip(
                              label: const Text('🚬 Venta Dual (Sueltos)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              selected: _tipoProducto == TipoProductoUi.dual,
                              selectedColor: AppColors.warning,
                              labelStyle: TextStyle(
                                color: _tipoProducto == TipoProductoUi.dual ? Colors.white : AppColors.textPrimary,
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _tipoProducto = TipoProductoUi.dual);
                              },
                            ),
                          ],
                        ),

                        if (_tipoProducto == TipoProductoUi.dual) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.warning.withAlpha(80)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Configuración de Venta Suelta / Individual:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.warning),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _nombreUnidadSueltaController,
                                        decoration: const InputDecoration(
                                          labelText: 'Nombre suelto',
                                          hintText: 'cigarrillo, rollo...',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _unidadesEnEmpaqueVentaController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Uds por empaque',
                                          hintText: 'Ej. 20',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _precioVentaSueltaController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success),
                                  decoration: const InputDecoration(
                                    labelText: 'Precio de la Unidad Suelta (Bs.)',
                                    hintText: 'Ej. 1.00',
                                    prefixText: 'Bs. ',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. SECCIÓN PRECIOS Y GANANCIA — Fase 3: Doble métrica de rentabilidad
                  _buildCard(
                    titulo: '💵 Precios y Ganancia Comercial (Bs.)',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _costoMayoristaController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  labelText: 'Costo Mayorista *',
                                  hintText: '0.00',
                                  prefixText: 'Bs. ',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Requerido';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _precioVentaController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.success),
                                decoration: const InputDecoration(
                                  labelText: 'Precio Venta *',
                                  hintText: '0.00',
                                  prefixText: 'Bs. ',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Requerido';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Tarjeta de Ganancia en Tiempo Real con Margen y Markup
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: ganancia >= 0 ? AppColors.success.withAlpha(20) : AppColors.danger.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: ganancia >= 0 ? AppColors.success : AppColors.danger,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Fila principal: Ganancia en Bs.
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    ganancia >= 0 ? 'Ganancia Unitaria:' : 'Pérdida detectada:',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: ganancia >= 0 ? AppColors.success : AppColors.danger,
                                    ),
                                  ),
                                  Text(
                                    '${ganancia >= 0 ? '+' : ''}Bs. ${ganancia.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: ganancia >= 0 ? AppColors.success : AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                              if (costo > 0 || precio > 0) ...[
                                const Divider(height: 14),
                                // Fase 3: Fila de doble porcentaje (Margen Bruto + Markup)
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricaPill(
                                        label: 'Margen Bruto',
                                        tooltip: 'Sobre precio de venta',
                                        valor: '${margenBruto.toStringAsFixed(1)}%',
                                        color: AppColors.info,
                                        icon: Icons.storefront,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildMetricaPill(
                                        label: 'Markup',
                                        tooltip: 'Sobre costo de compra',
                                        valor: '${markup.toStringAsFixed(1)}%',
                                        color: AppColors.secondary,
                                        icon: Icons.trending_up,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. SECCIÓN STOCK — Fase 5: Aviso de auditoría si cambia stock en edición
                  _buildCard(
                    titulo: '📊 Control de Stock e Inventario',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _stockActualController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText: _esEdicion ? 'Stock Actual *' : 'Stock Inicial *',
                                  hintText: '0',
                                  suffixText: _tipoProducto == TipoProductoUi.granel ? 'kg' : 'uds',
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Requerido';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _stockMinimoController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontSize: 18),
                                decoration: InputDecoration(
                                  labelText: 'Stock Mínimo (Alerta) *',
                                  hintText: '5',
                                  suffixText: _tipoProducto == TipoProductoUi.granel ? 'kg' : 'uds',
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Requerido';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        // Fase 5: Aviso visual de que el cambio de stock quedará registrado en auditoría
                        if (_esEdicion &&
                            _parse(_stockActualController) != widget.productoParaEditar!.stockActual) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.info.withAlpha(15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.info.withAlpha(60)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.history, size: 20, color: AppColors.info),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Cambio de stock: ${widget.productoParaEditar!.stockActual.toStringAsFixed(0)} → ${_parse(_stockActualController).toStringAsFixed(0)} uds. Se registrará como ajuste de inventario.',
                                    style: const TextStyle(fontSize: 13, color: AppColors.info),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. SECCIÓN EMPAQUE MAYORISTA / CAJAS
                  _buildCard(
                    titulo: '📦 Empaque Mayorista / Cajas de Almacén',
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            '¿Este producto es una Caja o Bulto cerrado?',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Actívalo si compras cajas de cerveza, fardos de arroz o paquetes para abrir botellas sueltas.',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          value: _esEmpaqueMayorista,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) => setState(() => _esEmpaqueMayorista = val),
                        ),

                        if (_esEmpaqueMayorista) ...[
                          const Divider(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _tipoEmpaque,
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo de Empaque',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'CAJA', child: Text('Caja')),
                                    DropdownMenuItem(value: 'PAQUETE', child: Text('Paquete')),
                                    DropdownMenuItem(value: 'FARDO', child: Text('Fardo')),
                                    DropdownMenuItem(value: 'BOLSA', child: Text('Bolsa')),
                                    DropdownMenuItem(value: 'TIRA', child: Text('Tira')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _tipoEmpaque = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _unidadesPorEmpaqueController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Uds por caja *',
                                    hintText: 'Ej. 12',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _costoPorEmpaqueController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Costo total de la caja cerrada (Bs.)',
                              hintText: 'Ej. 126.00',
                              prefixText: 'Bs. ',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Selector de Producto Hijo para Auto-Desempaque
                          DropdownButtonFormField<String>(
                            initialValue: _productoHijoSeleccionadoId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Vincular a producto suelto (para desempaque)',
                              hintText: 'Selecciona la botella suelta que contiene',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Ninguno (Solo caja sin vincular)'),
                              ),
                              ...todosLosProductos.map((prod) {
                                return DropdownMenuItem<String>(
                                  value: prod.id,
                                  child: Text(
                                    prod.nombre,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() => _productoHijoSeleccionadoId = val);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Botón Masivo Inferior para Guardar (60dp)
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(20), offset: const Offset(0, -4), blurRadius: 10),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Icon(Icons.save_rounded, color: Colors.white, size: 28),
              label: Text(
                _guardando ? 'Guardando...' : (_esEdicion ? 'Actualizar Producto' : 'Guardar Producto'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Pastilla de métrica de rentabilidad para la Fase 3
  Widget _buildMetricaPill({
    required String label,
    required String tooltip,
    required String valor,
    required Color color,
    required IconData icon,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    valor,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String titulo, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
