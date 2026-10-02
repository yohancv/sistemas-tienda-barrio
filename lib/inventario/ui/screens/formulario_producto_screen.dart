import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../compras/data/models/proveedor_model.dart';
import '../../../compras/state/providers/compras_providers.dart';
import '../../../compras/ui/widgets/modal_nuevo_proveedor.dart';
import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../data/models/categoria_model.dart';
import '../../data/models/producto_model.dart';
import '../../state/providers/categorias_providers.dart';
import '../../state/providers/inventario_providers.dart';
import 'gestion_categorias_screen.dart';

/// 4 Modos de Venta al Público intuitivos para la tienda de barrio
enum ModoVentaUi {
  unidadSimple,   // 🏷️ Por Unidad / Simple (coca machucada por bolsita, productos de prueba, etc.)
  paqueteCaja,    // 📦 Paquete / Caja (cervezas, fardos de soda, galletas, chicles)
  sueltoCigarro,  // 🚬 Sueltos 3 Niveles (rueda -> cajetilla -> cigarro suelto / pastillas)
  granelBalanza,  // ⚖️ A Granel / Balanza (coca tradicional por libra, pollo, queso, carne por kg)
}

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

  // 1. Datos Básicos Generales
  late final TextEditingController _nombreController;
  late final TextEditingController _codigoBarrasController;
  late final TextEditingController _descripcionController;
  String? _proveedorSeleccionadoId;

  // 2. Categoría y Subcategoría
  late final TextEditingController _categoriaController;
  late final TextEditingController _subcategoriaController;

  // 3. Modo de Venta Activo
  ModoVentaUi _modoVenta = ModoVentaUi.unidadSimple;
  String _unidadMedidaPeso = 'kg'; // 'kg' o 'lb'

  // Controladores de Precios, Costos y Stock
  late final TextEditingController _costoMayoristaController; // Costo unitario o costo base
  late final TextEditingController _precioVentaController; // Precio venta unitario o en balanza
  late final TextEditingController _stockActualController; // Stock en unidades o en kg/lb
  late final TextEditingController _stockMinimoController; // Stock mínimo de alerta

  // Preferencia de Unidad para la Alerta de Stock Mínimo
  String _unidadAlertaPaquete = 'EMPAQUE'; // 'EMPAQUE' (cajas/fardos) o 'UNIDAD' (botellas/latas)
  String _unidadAlertaCigarro = 'CAJETILLA'; // 'CAJETILLA' o 'RUEDA'

  // Específico para Modo Paquete / Caja
  late final TextEditingController _unidadesPorEmpaqueController; // ej. 24 latas
  late final TextEditingController _costoPorEmpaqueController; // ej. Bs. 120 por fardo
  late final TextEditingController _precioEmpaqueMayoristaController; // Opcional, ej. Bs. 140
  late final TextEditingController _stockEmpaquesController; // Cajas cerradas en almacén
  String _tipoEmpaque = 'CAJA';

  // Específico para Modo Suelto 3 Niveles (Cigarros / Blísters)
  late final TextEditingController _nombreUnidadSueltaController; // ej. 'cigarro', 'pastilla'
  late final TextEditingController _unidadesEnEmpaqueVentaController; // ej. 20 cigarros por cajetilla
  late final TextEditingController _precioVentaSueltaController; // ej. Bs. 1.50 por cigarro

  // Estado del formulario
  bool _guardando = false;

  // FocusNodes y validación de código de barras
  late final FocusNode _codigoBarrasFocusNode;
  late final FocusNode _nombreFocusNode;
  Producto? _productoConflicto;
  bool _verificandoCodigo = false;

  // Snapshot inicial para detección de cambios sin guardar (PopScope)
  late final String _inicialNombre;
  late final String _inicialCodigo;
  late final String _inicialDescripcion;
  late final String _inicialCosto;
  late final String _inicialPrecio;
  late final String _inicialStock;
  String? _inicialProveedor;
  String? _inicialCategoria;
  String? _inicialSubcategoria;

  bool get _esEdicion => widget.productoParaEditar != null;

  @override
  void initState() {
    super.initState();
    final p = widget.productoParaEditar;

    _nombreController = TextEditingController(text: p?.nombre ?? '');
    _codigoBarrasController = TextEditingController(text: p?.codigoBarras ?? '');
    _descripcionController = TextEditingController(text: p?.descripcion ?? '');
    _proveedorSeleccionadoId = p?.proveedorId;

    _categoriaController = TextEditingController(text: p?.categoria ?? '');
    _subcategoriaController = TextEditingController(text: p?.subcategoria ?? '');

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

    // Paquete / Caja
    _unidadesPorEmpaqueController = TextEditingController(
      text: p != null && p.unidadesPorEmpaque > 0 ? p.unidadesPorEmpaque.toInt().toString() : '24',
    );
    _costoPorEmpaqueController = TextEditingController(
      text: p != null && p.costoPorEmpaque > 0 ? p.costoPorEmpaque.toStringAsFixed(2) : '',
    );
    _precioEmpaqueMayoristaController = TextEditingController(
      text: p != null && p.precioEmpaqueMayorista != null && p.precioEmpaqueMayorista! > 0
          ? p.precioEmpaqueMayorista!.toStringAsFixed(2)
          : '',
    );
    _stockEmpaquesController = TextEditingController(text: '0');
    _tipoEmpaque = p != null && p.tipoEmpaque != 'UNIDAD' ? p.tipoEmpaque : 'CAJA';

    // Suelto 3 Niveles (Cigarros)
    _nombreUnidadSueltaController = TextEditingController(
      text: p?.nombreUnidadSuelta ?? 'cigarro',
    );
    _unidadesEnEmpaqueVentaController = TextEditingController(
      text: p != null && p.unidadesEnEmpaqueVenta > 0 ? p.unidadesEnEmpaqueVenta.toInt().toString() : '20',
    );
    _precioVentaSueltaController = TextEditingController(
      text: p != null && p.precioVentaSuelta > 0 ? p.precioVentaSuelta.toStringAsFixed(2) : '',
    );

    // Determinar Modo de Venta Inicial y Unidades de Alerta de Stock Mínimo
    if (p != null) {
      if (p.esFraccionable) {
        _modoVenta = ModoVentaUi.granelBalanza;
        _unidadMedidaPeso = p.unidadMedida.toLowerCase().contains('lb') ? 'lb' : 'kg';
      } else if (p.permiteVentaSuelta) {
        _modoVenta = ModoVentaUi.sueltoCigarro;
        final cajPorRueda = p.unidadesPorEmpaque > 0 ? p.unidadesPorEmpaque : 10.0;
        if (p.stockMinimo >= cajPorRueda && p.stockMinimo % cajPorRueda == 0) {
          _unidadAlertaCigarro = 'RUEDA';
          _stockMinimoController.text = (p.stockMinimo ~/ cajPorRueda).toString();
        } else {
          _unidadAlertaCigarro = 'CAJETILLA';
        }
      } else if (p.tieneEmpaqueMayorista) {
        _modoVenta = ModoVentaUi.paqueteCaja;
        if (p.unidadesPorEmpaque > 1 && p.stockMinimo > 0 && p.stockMinimo % p.unidadesPorEmpaque == 0) {
          _unidadAlertaPaquete = 'EMPAQUE';
          _stockMinimoController.text = (p.stockMinimo ~/ p.unidadesPorEmpaque).toString();
        } else {
          _unidadAlertaPaquete = 'UNIDAD';
        }
      } else {
        _modoVenta = ModoVentaUi.unidadSimple;
      }
    } else {
      _unidadAlertaPaquete = 'EMPAQUE';
      _unidadAlertaCigarro = 'CAJETILLA';
      _stockMinimoController.text = '2'; // Sugerencia inicial amigable (2 cajas)
    }

    _codigoBarrasFocusNode = FocusNode();
    _nombreFocusNode = FocusNode();

    // Snapshot para detectar cambios
    _inicialNombre = _nombreController.text;
    _inicialCodigo = _codigoBarrasController.text;
    _inicialDescripcion = _descripcionController.text;
    _inicialCosto = _costoMayoristaController.text;
    _inicialPrecio = _precioVentaController.text;
    _inicialStock = _stockActualController.text;
    _inicialProveedor = _proveedorSeleccionadoId;
    _inicialCategoria = _categoriaController.text;
    _inicialSubcategoria = _subcategoriaController.text;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _codigoBarrasController.dispose();
    _descripcionController.dispose();
    _categoriaController.dispose();
    _subcategoriaController.dispose();
    _costoMayoristaController.dispose();
    _precioVentaController.dispose();
    _stockActualController.dispose();
    _stockMinimoController.dispose();
    _unidadesPorEmpaqueController.dispose();
    _costoPorEmpaqueController.dispose();
    _precioEmpaqueMayoristaController.dispose();
    _stockEmpaquesController.dispose();
    _nombreUnidadSueltaController.dispose();
    _unidadesEnEmpaqueVentaController.dispose();
    _precioVentaSueltaController.dispose();
    _codigoBarrasFocusNode.dispose();
    _nombreFocusNode.dispose();
    super.dispose();
  }

  double _parse(TextEditingController ctrl) {
    final clean = ctrl.text.trim().replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }

  bool get _tieneCambiosSinGuardar {
    return _nombreController.text != _inicialNombre ||
        _codigoBarrasController.text != _inicialCodigo ||
        _descripcionController.text != _inicialDescripcion ||
        _costoMayoristaController.text != _inicialCosto ||
        _precioVentaController.text != _inicialPrecio ||
        _stockActualController.text != _inicialStock ||
        _categoriaController.text != _inicialCategoria ||
        _subcategoriaController.text != _inicialSubcategoria ||
        _proveedorSeleccionadoId != _inicialProveedor;
  }

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

  void _onCodigoBarrasSubmitted(String valor) {
    _verificarCodigoBarras(valor);
    if (_productoConflicto == null) {
      _nombreFocusNode.requestFocus();
    }
  }

  void _guardar() async {
    if (_productoConflicto != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(
            'El código de barras "${_codigoBarrasController.text}" ya pertenece a "${_productoConflicto!.nombre}".',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final p = widget.productoParaEditar;

      // Variables adaptadas según el modo de venta seleccionado
      double costoMayorista = 0.0;
      double precioVenta = 0.0;
      double stockActual = _parse(_stockActualController);
      double stockMinimo = _parse(_stockMinimoController);

      String tipoUnidad = 'UNIDAD';

      // Empaque mayorista
      String tipoEmpaque = 'UNIDAD';
      double unidadesPorEmpaque = 1.0;
      double costoPorEmpaque = 0.0;
      double? precioEmpaqueMayorista;

      // Venta suelta (Dual / 3 niveles)
      bool permiteVentaSuelta = false;
      String nombreUnidadSuelta = 'unidad';
      double unidadesEnEmpaqueVenta = 1.0;
      double precioVentaSuelta = 0.0;

      switch (_modoVenta) {
        case ModoVentaUi.unidadSimple:
          tipoUnidad = 'UNIDAD';
          costoMayorista = _parse(_costoMayoristaController);
          precioVenta = _parse(_precioVentaController);
          break;

        case ModoVentaUi.paqueteCaja:
          tipoUnidad = 'UNIDAD';
          tipoEmpaque = _tipoEmpaque;
          unidadesPorEmpaque = _parse(_unidadesPorEmpaqueController);
          if (unidadesPorEmpaque <= 0) unidadesPorEmpaque = 1.0;

          costoPorEmpaque = _parse(_costoPorEmpaqueController);
          costoMayorista = costoPorEmpaque > 0 ? (costoPorEmpaque / unidadesPorEmpaque) : _parse(_costoMayoristaController);

          precioVenta = _parse(_precioVentaController);
          final pEmpaque = _parse(_precioEmpaqueMayoristaController);
          precioEmpaqueMayorista = pEmpaque > 0 ? pEmpaque : null;

          final cajasAlmacen = _parse(_stockEmpaquesController);
          stockActual = _parse(_stockActualController) + (cajasAlmacen * unidadesPorEmpaque);

          // Si el usuario configuró alerta en Cajas/Empaque, convertir a unidades base
          if (_unidadAlertaPaquete == 'EMPAQUE') {
            stockMinimo = _parse(_stockMinimoController) * unidadesPorEmpaque;
          } else {
            stockMinimo = _parse(_stockMinimoController);
          }
          break;

        case ModoVentaUi.sueltoCigarro:
          tipoUnidad = 'UNIDAD';
          permiteVentaSuelta = true;
          nombreUnidadSuelta = _nombreUnidadSueltaController.text.trim().isEmpty ? 'cigarro' : _nombreUnidadSueltaController.text.trim();
          unidadesEnEmpaqueVenta = _parse(_unidadesEnEmpaqueVentaController);
          if (unidadesEnEmpaqueVenta <= 0) unidadesEnEmpaqueVenta = 1.0;

          precioVentaSuelta = _parse(_precioVentaSueltaController);
          precioVenta = _parse(_precioVentaController);

          // Si especificó rueda / empaque grande
          final cajetillasPorRueda = _parse(_unidadesPorEmpaqueController);
          final costoRueda = _parse(_costoPorEmpaqueController);
          if (cajetillasPorRueda > 0 && costoRueda > 0) {
            tipoEmpaque = 'PAQUETE'; // Validado para check constraint de PostgreSQL
            unidadesPorEmpaque = cajetillasPorRueda;
            costoPorEmpaque = costoRueda;
            costoMayorista = costoRueda / cajetillasPorRueda;
          } else {
            costoMayorista = _parse(_costoMayoristaController);
          }

          // Si el usuario configuró alerta en Ruedas, convertir a cajetillas base
          if (_unidadAlertaCigarro == 'RUEDA') {
            final cajPorRueda = cajetillasPorRueda > 0 ? cajetillasPorRueda : 10.0;
            stockMinimo = _parse(_stockMinimoController) * cajPorRueda;
          } else {
            stockMinimo = _parse(_stockMinimoController);
          }
          break;

        case ModoVentaUi.granelBalanza:
          tipoUnidad = 'FRACCIONABLE';
          tipoEmpaque = _unidadMedidaPeso == 'lb' ? 'LIBRA' : 'KILO';
          costoMayorista = _parse(_costoMayoristaController);
          precioVenta = _parse(_precioVentaController);
          break;
      }

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
        tipoUnidad: tipoUnidad,
        stockActual: stockActual,
        stockMinimo: stockMinimo,
        costoMayorista: costoMayorista,
        precioVenta: precioVenta,
        estadoActivo: true,
        createdAt: p?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),

        // Empaque Mayorista
        tipoEmpaque: tipoEmpaque,
        unidadesPorEmpaque: unidadesPorEmpaque,
        costoPorEmpaque: costoPorEmpaque,
        precioEmpaqueMayorista: precioEmpaqueMayorista,

        // Venta Dual / Sueltos
        permiteVentaSuelta: permiteVentaSuelta,
        nombreUnidadSuelta: nombreUnidadSuelta,
        unidadesEnEmpaqueVenta: unidadesEnEmpaqueVenta,
        precioVentaSuelta: precioVentaSuelta,

        // Proveedor, Categoría y Subcategoría
        proveedorId: _proveedorSeleccionadoId,
        categoria: _categoriaController.text.trim().isEmpty ? null : _categoriaController.text.trim(),
        subcategoria: _subcategoriaController.text.trim().isEmpty ? null : _subcategoriaController.text.trim(),
      );

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
          'El producto "${p.nombre}" dejará de aparecer en el catálogo y punto de venta.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, retirar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      setState(() => _guardando = true);
      final exito = await ref.read(productoOperacionProvider.notifier).desactivarProducto(p.id, p.nombre);
      if (!mounted) return;
      setState(() => _guardando = false);
      if (exito) {
        Navigator.pop(context, null);
      }
    }
  }

  Future<bool> _confirmarDescartarCambios() async {
    if (!_tieneCambiosSinGuardar) return true;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.warning),
        title: const Text('¿Descartar cambios?'),
        content: const Text('Tienes información sin guardar que se perderá si sales ahora.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuar editando')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return confirmar ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final proveedoresAsync = ref.watch(proveedoresListProvider);
    final arbolCategoriasAsync = ref.watch(arbolCategoriasProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final puedeIrse = await _confirmarDescartarCambios();
        if (puedeIrse && context.mounted) {
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ============================================================
                  // 1. BLOQUE SUPERIOR: DATOS BÁSICOS GENERALES
                  // ============================================================
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
                            hintText: 'Ej. Coca Machucada Menta, Paceña 710cc, Pollo...',
                            prefixIcon: Icon(Icons.label_outline, color: AppColors.primary),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
                        ),
                        const SizedBox(height: 14),

                        // Código de barras con botón generador y pistola
                        TextFormField(
                          controller: _codigoBarrasController,
                          focusNode: _codigoBarrasFocusNode,
                          style: const TextStyle(fontSize: 16),
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: _onCodigoBarrasSubmitted,
                          onChanged: (val) {
                            setState(() {});
                            Future.delayed(const Duration(milliseconds: 500), () {
                              if (mounted && _codigoBarrasController.text == val) {
                                _verificarCodigoBarras(val);
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
                                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
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
                        ),

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
                                const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 26),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Código ya registrado en "${_productoConflicto!.nombre}"',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Descripción opcional
                        TextFormField(
                          controller: _descripcionController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Descripción o Ubicación (Opcional)',
                            hintText: 'Ej. Heladera del fondo, anaquel 2...',
                            prefixIcon: Icon(Icons.description_outlined, color: AppColors.textSecondary),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ============================================================
                  // 2. BLOQUE: PROVEEDOR, CATEGORÍA Y SUBCATEGORÍA
                  // ============================================================
                  _buildCard(
                    titulo: '🏷️ Clasificación y Proveedor',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Proveedor habitual
                        Row(
                          children: [
                            Expanded(
                              child: proveedoresAsync.when(
                                loading: () => const LinearProgressIndicator(),
                                error: (e, _) => const Text('Error al cargar proveedores'),
                                data: (proveedores) {
                                  final yaExiste = _proveedorSeleccionadoId == null ||
                                      proveedores.any((p) => p.id == _proveedorSeleccionadoId);
                                  final valorValido = yaExiste ? _proveedorSeleccionadoId : null;

                                  return DropdownButtonFormField<String>(
                                    initialValue: valorValido,
                                    decoration: const InputDecoration(
                                      labelText: 'Empresa Proveedora',
                                      prefixIcon: Icon(Icons.local_shipping_outlined, color: AppColors.primary),
                                      border: OutlineInputBorder(),
                                    ),
                                    isExpanded: true,
                                    items: [
                                      const DropdownMenuItem(value: null, child: Text('Sin Proveedor Fijo / Compra General')),
                                      ...proveedores.map(
                                        (prov) => DropdownMenuItem(
                                          value: prov.id,
                                          child: Text(prov.nombreEmpresa, overflow: TextOverflow.ellipsis),
                                        ),
                                      ),
                                    ],
                                    onChanged: (id) => setState(() => _proveedorSeleccionadoId = id),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.add_business_rounded, color: AppColors.primary),
                              tooltip: 'Nuevo Proveedor',
                              onPressed: () async {
                                final nuevoProv = await showModalBottomSheet<ProveedorModel>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => const ModalNuevoProveedor(),
                                );
                                if (nuevoProv != null) {
                                  ref.invalidate(proveedoresListProvider);
                                  setState(() => _proveedorSeleccionadoId = nuevoProv.id);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Selector de Categoría Principal
                        arbolCategoriasAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Error al cargar categorías: $e'),
                          data: (categorias) {
                            CategoriaModel? catSeleccionadaObj;
                            if (_categoriaController.text.isNotEmpty) {
                              catSeleccionadaObj = categorias.where(
                                (c) => c.nombre.toLowerCase() == _categoriaController.text.trim().toLowerCase(),
                              ).firstOrNull;
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: catSeleccionadaObj?.nombre,
                                        decoration: const InputDecoration(
                                          labelText: 'Categoría Principal',
                                          prefixIcon: Icon(Icons.category_outlined, color: AppColors.primary),
                                          border: OutlineInputBorder(),
                                        ),
                                        isExpanded: true,
                                        hint: const Text('Selecciona una categoría...'),
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('Sin Categoría')),
                                          ...categorias.map(
                                            (c) => DropdownMenuItem(
                                              value: c.nombre,
                                              child: Text(c.nombreConIcono, overflow: TextOverflow.ellipsis),
                                            ),
                                          ),
                                        ],
                                        onChanged: (nombreCat) {
                                          setState(() {
                                            _categoriaController.text = nombreCat ?? '';
                                            _subcategoriaController.clear();
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton.filledTonal(
                                      icon: const Icon(Icons.playlist_add, color: AppColors.primary),
                                      tooltip: 'Gestionar o Crear Categorías',
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const GestionCategoriasScreen()),
                                        );
                                        ref.invalidate(arbolCategoriasProvider);
                                      },
                                    ),
                                  ],
                                ),

                                // Selector de Subcategoría (Solo si la categoría principal tiene subcategorías o si el usuario quiere)
                                if (_categoriaController.text.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Subcategoría / Tamaño / Marca (Opcional):',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 6),
                                  if (catSeleccionadaObj != null && catSeleccionadaObj.subcategorias.isNotEmpty) ...[
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          // Chip Sin Subcategoría
                                          Padding(
                                            padding: const EdgeInsets.only(right: 6.0),
                                            child: FilterChip(
                                              label: const Text('Ninguna'),
                                              selected: _subcategoriaController.text.isEmpty,
                                              selectedColor: AppColors.secondary.withAlpha(25),
                                              checkmarkColor: AppColors.secondary,
                                              onSelected: (_) => setState(() => _subcategoriaController.clear()),
                                            ),
                                          ),
                                          // Chips de cada subcategoría existente
                                          ...catSeleccionadaObj.subcategorias.map((sub) {
                                            final sel = _subcategoriaController.text.toLowerCase() == sub.nombre.toLowerCase();
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 6.0),
                                              child: FilterChip(
                                                label: Text(sub.nombre),
                                                selected: sel,
                                                selectedColor: AppColors.secondary.withAlpha(25),
                                                checkmarkColor: AppColors.secondary,
                                                labelStyle: TextStyle(
                                                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                                  color: sel ? AppColors.secondary : AppColors.textPrimary,
                                                ),
                                                onSelected: (val) {
                                                  setState(() => _subcategoriaController.text = val ? sub.nombre : '');
                                                },
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _subcategoriaController,
                                    decoration: InputDecoration(
                                      hintText: 'O escribe una subcategoría (ej. Huari, Menta, 2 Litros)',
                                      prefixIcon: const Icon(Icons.subdirectory_arrow_right, size: 20),
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      suffixIcon: _subcategoriaController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 18),
                                              onPressed: () => setState(() => _subcategoriaController.clear()),
                                            )
                                          : null,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ============================================================
                  // 3. SELECTOR DE MODO DE VENTA AL PÚBLICO (4 TARJETAS)
                  // ============================================================
                  _buildCard(
                    titulo: '⚖️ ¿Cómo se vende este producto al público?',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Selecciona el modo según cómo compras y vendes el artículo:',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),

                        // Grid de los 4 Modos
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = (constraints.maxWidth - 10) / 2;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _buildModoButton(
                                  width: cardWidth,
                                  modo: ModoVentaUi.unidadSimple,
                                  icono: '🏷️',
                                  titulo: 'Por Unidad',
                                  subtitulo: 'Coca machucada, pruebas, bolsas',
                                  colorActivo: AppColors.primary,
                                ),
                                _buildModoButton(
                                  width: cardWidth,
                                  modo: ModoVentaUi.paqueteCaja,
                                  icono: '📦',
                                  titulo: 'Paquete / Caja',
                                  subtitulo: 'Cervezas, fardos, galletas, chicles',
                                  colorActivo: AppColors.secondary,
                                ),
                                _buildModoButton(
                                  width: cardWidth,
                                  modo: ModoVentaUi.sueltoCigarro,
                                  icono: '🚬',
                                  titulo: 'Suelto 3 Niveles',
                                  subtitulo: 'Cigarros (Rueda ➔ Cajetilla ➔ Suelto)',
                                  colorActivo: AppColors.warning,
                                ),
                                _buildModoButton(
                                  width: cardWidth,
                                  modo: ModoVentaUi.granelBalanza,
                                  icono: '⚖️',
                                  titulo: 'Granel / Balanza',
                                  subtitulo: 'Coca por libra, pollo, queso por kg',
                                  colorActivo: Colors.teal.shade700,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // ============================================================
                        // FORMULARIO ADAPTATIVO SEGÚN EL MODO SELECCIONADO
                        // ============================================================
                        _buildFormularioSegunModo(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Botón Guardar Flotante
        bottomSheet: Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SafeArea(
            child: SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.check_circle_outline, size: 28),
                label: Text(
                  _guardando ? 'Guardando producto...' : (_esEdicion ? 'Actualizar Producto' : 'Guardar Producto en Inventario'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // WIDGET: TARJETA SELECTORA DE MODO
  // ==========================================================================
  Widget _buildModoButton({
    required double width,
    required ModoVentaUi modo,
    required String icono,
    required String titulo,
    required String subtitulo,
    required Color colorActivo,
  }) {
    final bool activo = _modoVenta == modo;

    return InkWell(
      onTap: () {
        if (_modoVenta != modo) {
          setState(() {
            _modoVenta = modo;
            if (!_esEdicion) {
              if (modo == ModoVentaUi.paqueteCaja) {
                _unidadAlertaPaquete = 'EMPAQUE';
                _stockMinimoController.text = '2';
              } else if (modo == ModoVentaUi.sueltoCigarro) {
                _unidadAlertaCigarro = 'CAJETILLA';
                _stockMinimoController.text = '2';
              } else if (modo == ModoVentaUi.granelBalanza) {
                _stockMinimoController.text = '1.0';
              } else if (modo == ModoVentaUi.unidadSimple) {
                _stockMinimoController.text = '3';
              }
            }
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: activo ? colorActivo.withAlpha(20) : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activo ? colorActivo : AppColors.border,
            width: activo ? 2.2 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icono, style: const TextStyle(fontSize: 22)),
                const Spacer(),
                if (activo)
                  Icon(Icons.check_circle, size: 18, color: colorActivo)
                else
                  Icon(Icons.radio_button_unchecked, size: 18, color: AppColors.textMuted),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: activo ? colorActivo : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitulo,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // FORMULARIO ADAPTATIVO DINÁMICO
  // ==========================================================================
  Widget _buildFormularioSegunModo() {
    switch (_modoVenta) {
      case ModoVentaUi.unidadSimple:
        return _buildFormUnidadSimple();
      case ModoVentaUi.paqueteCaja:
        return _buildFormPaqueteCaja();
      case ModoVentaUi.sueltoCigarro:
        return _buildFormSueltoCigarro();
      case ModoVentaUi.granelBalanza:
        return _buildFormGranelBalanza();
    }
  }

  // 1. MODO: UNIDAD SIMPLE
  Widget _buildFormUnidadSimple() {
    final costo = _parse(_costoMayoristaController);
    final precio = _parse(_precioVentaController);
    final ganancia = precio - costo;
    final margen = precio > 0 ? (ganancia / precio) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _costoMayoristaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'Costo de Compra (Bs.) *',
                    hintText: 'Ej. 4.00',
                    prefixText: 'Bs. ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _precioVentaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.success),
                  decoration: const InputDecoration(
                    labelText: 'Precio de Venta (Bs.) *',
                    hintText: 'Ej. 5.00',
                    prefixText: 'Bs. ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Calculadora de ganancia
          _buildBannerGanancia(ganancia: ganancia, margen: margen),
          const SizedBox(height: 14),

          // Stock
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _stockActualController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad que tienes hoy *',
                    hintText: 'Ej. 10',
                    suffixText: 'uds',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _stockMinimoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Avisar si quedan menos de *',
                    hintText: 'Ej. 3',
                    suffixText: 'unidades',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
            ],
          ),
          if (_parse(_stockMinimoController) > 0) ...[
            const SizedBox(height: 6),
            Text(
              '💡 Te alertará cuando te queden ${_parse(_stockMinimoController).toInt()} unidades o bolsitas en tienda.',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }

  // 2. MODO: PAQUETE / CAJA
  Widget _buildFormPaqueteCaja() {
    final unidades = _parse(_unidadesPorEmpaqueController);
    final costoPaquete = _parse(_costoPorEmpaqueController);
    final costoUnitarioAuto = unidades > 0 ? (costoPaquete / unidades) : 0.0;

    final precioVentaUnidad = _parse(_precioVentaController);
    final precioVentaPaquete = _parse(_precioEmpaqueMayoristaController);

    final gananciaUnidad = precioVentaUnidad - costoUnitarioAuto;
    final margenUnidad = precioVentaUnidad > 0 ? (gananciaUnidad / precioVentaUnidad) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: _tipoEmpaque,
                  decoration: const InputDecoration(labelText: 'Tipo de Empaque', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'CAJA', child: Text('Caja')),
                    DropdownMenuItem(value: 'FARDO', child: Text('Fardo')),
                    DropdownMenuItem(value: 'PAQUETE', child: Text('Paquete')),
                    DropdownMenuItem(value: 'BOLSA', child: Text('Bolsa')),
                  ],
                  onChanged: (val) => setState(() => _tipoEmpaque = val ?? 'CAJA'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _unidadesPorEmpaqueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Uds por Paquete *',
                    hintText: 'Ej. 24',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _costoPorEmpaqueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'Costo del Paquete *',
                    hintText: 'Ej. 120.00',
                    prefixText: 'Bs. ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 12),
              // Auto-calculado
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.secondary.withAlpha(60)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Te sale por lata/ud:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        'Bs. ${costoUnitarioAuto.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.secondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _precioVentaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.success),
                  decoration: const InputDecoration(
                    labelText: 'Venta por Unidad *',
                    hintText: 'Ej. 8.00',
                    prefixText: 'Bs. ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _precioEmpaqueMayoristaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Venta Paquete (Opcional)',
                    hintText: 'Ej. 150.00',
                    prefixText: 'Bs. ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Calculadora de ganancia
          _buildBannerGanancia(
            ganancia: gananciaUnidad,
            margen: margenUnidad,
            textoPersonalizado: 'Ganancia por unidad suelta:',
          ),
          if (precioVentaPaquete > 0 && costoPaquete > 0) ...[
            const SizedBox(height: 6),
            Text(
              '📦 Si vendes el paquete entero ganas: Bs. ${(precioVentaPaquete - costoPaquete).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
          ],
          const SizedBox(height: 14),

          // Stock en Mostrador y en Almacén
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _stockActualController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Unidades en mostrador *',
                    hintText: 'Ej. 6',
                    suffixText: 'uds',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _stockEmpaquesController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'En almacén',
                    hintText: 'Ej. 2',
                    suffixText: _tipoEmpaque.toLowerCase() == 'caja' ? 'cajas' : '${_tipoEmpaque.toLowerCase()}s',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Selector interactivo de alerta de Stock Mínimo (Cajas vs Unidades)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active_outlined, size: 18, color: AppColors.secondary),
                    SizedBox(width: 6),
                    Text('Avisarme cuando me quede poco stock en:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text('📦 ${_tipoEmpaque.toLowerCase() == 'caja' ? 'Cajas' : _tipoEmpaque}'),
                      selected: _unidadAlertaPaquete == 'EMPAQUE',
                      selectedColor: AppColors.secondary,
                      labelStyle: TextStyle(
                        color: _unidadAlertaPaquete == 'EMPAQUE' ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val && _unidadAlertaPaquete != 'EMPAQUE') {
                          final uds = _parse(_unidadesPorEmpaqueController);
                          final actual = _parse(_stockMinimoController);
                          if (uds > 0 && actual > 0) {
                            final cajas = actual / uds;
                            _stockMinimoController.text = (cajas.truncateToDouble() == cajas ? cajas.toInt().toString() : cajas.toStringAsFixed(1));
                          } else {
                            _stockMinimoController.text = '2';
                          }
                          setState(() => _unidadAlertaPaquete = 'EMPAQUE');
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('🍾 Unidades sueltas'),
                      selected: _unidadAlertaPaquete == 'UNIDAD',
                      selectedColor: AppColors.secondary,
                      labelStyle: TextStyle(
                        color: _unidadAlertaPaquete == 'UNIDAD' ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val && _unidadAlertaPaquete != 'UNIDAD') {
                          final uds = _parse(_unidadesPorEmpaqueController);
                          final actual = _parse(_stockMinimoController);
                          if (uds > 0 && actual > 0) {
                            final unidades = (actual * uds).round();
                            _stockMinimoController.text = unidades.toString();
                          } else {
                            _stockMinimoController.text = '12';
                          }
                          setState(() => _unidadAlertaPaquete = 'UNIDAD');
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _stockMinimoController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _unidadAlertaPaquete == 'EMPAQUE'
                        ? 'Alerta cuando queden menos de ($_tipoEmpaque) *'
                        : 'Alerta cuando queden menos de (unidades) *',
                    hintText: _unidadAlertaPaquete == 'EMPAQUE' ? 'Ej. 2' : 'Ej. 10',
                    suffixText: _unidadAlertaPaquete == 'EMPAQUE'
                        ? (_tipoEmpaque.toLowerCase() == 'caja' ? 'cajas' : '${_tipoEmpaque.toLowerCase()}s')
                        : 'unidades',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                if (_unidadAlertaPaquete == 'EMPAQUE' && _parse(_stockMinimoController) > 0 && _parse(_unidadesPorEmpaqueController) > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '💡 Equivale a ${(_parse(_stockMinimoController) * _parse(_unidadesPorEmpaqueController)).toInt()} unidades en total. La app te avisará cuando queden menos de ${_parse(_stockMinimoController).toInt()} $_tipoEmpaque.',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.secondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. MODO: SUELTO 3 NIVELES (Cigarros / Blísters)
  Widget _buildFormSueltoCigarro() {
    final cajetillasPorRueda = _parse(_unidadesPorEmpaqueController);
    final costoRueda = _parse(_costoPorEmpaqueController);
    final costoCajetillaAuto = cajetillasPorRueda > 0 ? (costoRueda / cajetillasPorRueda) : _parse(_costoMayoristaController);

    final unidadesPorCajetilla = _parse(_unidadesEnEmpaqueVentaController);
    final costoSueltoAuto = unidadesPorCajetilla > 0 ? (costoCajetillaAuto / unidadesPorCajetilla) : 0.0;

    final precioVentaCajetilla = _parse(_precioVentaController);
    final precioVentaSuelto = _parse(_precioVentaSueltaController);

    final gananciaCajetilla = precioVentaCajetilla - costoCajetillaAuto;
    final gananciaSuelto = precioVentaSuelto - costoSueltoAuto;
    final gananciaCajetillaEnSueltos = (precioVentaSuelto * unidadesPorCajetilla) - costoCajetillaAuto;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nivel 1: Empaque Grande (Rueda o Paquete)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _unidadesPorEmpaqueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cajetillas por Rueda *',
                    hintText: 'Ej. 10',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _costoPorEmpaqueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Costo de Rueda (Bs.) *',
                    hintText: 'Ej. 150.00',
                    prefixText: 'Bs. ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          const Text('Nivel 2: Cajetilla / Paquetito', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Costo de cajetilla:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text('Bs. ${costoCajetillaAuto.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _precioVentaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'Venta de Cajetilla *',
                    hintText: 'Ej. 20.00',
                    prefixText: 'Bs. ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          const Text('Nivel 3: Unidad Suelta (Cigarros)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _unidadesEnEmpaqueVentaController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cigarros por cajetilla *',
                    hintText: 'Ej. 20',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _precioVentaSueltaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.success),
                  decoration: const InputDecoration(
                    labelText: 'Venta por Cigarro *',
                    hintText: 'Ej. 1.50',
                    prefixText: 'Bs. ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Comparativa de Ganancia
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💵 Venta cajetilla: Ganas Bs. ${gananciaCajetilla.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '🔥 Venta suelta (20 cigarros): Ganas Bs. ${gananciaCajetillaEnSueltos.toStringAsFixed(2)} (Bs. ${gananciaSuelto.toStringAsFixed(2)} por cigarro)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Stock Actual de Cajetillas
          TextFormField(
            controller: _stockActualController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Cajetillas disponibles hoy en mostrador *',
              hintText: 'Ej. 5',
              suffixText: 'cajetillas',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 14),

          // Selector interactivo de alerta de Stock Mínimo para Cigarros (Cajetillas vs Ruedas)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active_outlined, size: 18, color: AppColors.warning),
                    SizedBox(width: 6),
                    Text('Avisarme cuando me quede poco stock en:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('🚬 Cajetillas'),
                      selected: _unidadAlertaCigarro == 'CAJETILLA',
                      selectedColor: AppColors.warning,
                      labelStyle: TextStyle(
                        color: _unidadAlertaCigarro == 'CAJETILLA' ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val && _unidadAlertaCigarro != 'CAJETILLA') {
                          final cajPorRueda = _parse(_unidadesPorEmpaqueController);
                          final actual = _parse(_stockMinimoController);
                          if (cajPorRueda > 0 && actual > 0) {
                            final cajetillas = (actual * cajPorRueda).round();
                            _stockMinimoController.text = cajetillas.toString();
                          } else {
                            _stockMinimoController.text = '3';
                          }
                          setState(() => _unidadAlertaCigarro = 'CAJETILLA');
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('📦 Ruedas / Paquetes'),
                      selected: _unidadAlertaCigarro == 'RUEDA',
                      selectedColor: AppColors.warning,
                      labelStyle: TextStyle(
                        color: _unidadAlertaCigarro == 'RUEDA' ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val && _unidadAlertaCigarro != 'RUEDA') {
                          final cajPorRueda = _parse(_unidadesPorEmpaqueController);
                          final actual = _parse(_stockMinimoController);
                          if (cajPorRueda > 0 && actual > 0) {
                            final ruedas = actual / cajPorRueda;
                            _stockMinimoController.text = (ruedas.truncateToDouble() == ruedas ? ruedas.toInt().toString() : ruedas.toStringAsFixed(1));
                          } else {
                            _stockMinimoController.text = '1';
                          }
                          setState(() => _unidadAlertaCigarro = 'RUEDA');
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _stockMinimoController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _unidadAlertaCigarro == 'CAJETILLA'
                        ? 'Alerta cuando queden menos de (cajetillas) *'
                        : 'Alerta cuando queden menos de (ruedas) *',
                    hintText: _unidadAlertaCigarro == 'CAJETILLA' ? 'Ej. 3' : 'Ej. 1',
                    suffixText: _unidadAlertaCigarro == 'CAJETILLA' ? 'cajetillas' : 'ruedas',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                if (_unidadAlertaCigarro == 'RUEDA' && _parse(_stockMinimoController) > 0 && _parse(_unidadesPorEmpaqueController) > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '💡 Equivale a ${(_parse(_stockMinimoController) * _parse(_unidadesPorEmpaqueController)).toInt()} cajetillas en total.',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.warning),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. MODO: GRANEL / BALANZA (Coca por libra, pollo, queso por kilo)
  Widget _buildFormGranelBalanza() {
    final costo = _parse(_costoMayoristaController);
    final precio = _parse(_precioVentaController);
    final ganancia = precio - costo;
    final margen = precio > 0 ? (ganancia / precio) * 100 : 0.0;

    final unidadTexto = _unidadMedidaPeso == 'lb' ? 'Libra' : 'Kilogramo';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade700.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selector de Unidad de Medida (Kg vs Lb)
          Row(
            children: [
              const Text('Unidad de pesaje:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              ChoiceChip(
                label: const Text('Libra (Lb) - Coca'),
                selected: _unidadMedidaPeso == 'lb',
                selectedColor: Colors.teal.shade700,
                labelStyle: TextStyle(
                  color: _unidadMedidaPeso == 'lb' ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  if (val) setState(() => _unidadMedidaPeso = 'lb');
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Kilo (Kg)'),
                selected: _unidadMedidaPeso == 'kg',
                selectedColor: Colors.teal.shade700,
                labelStyle: TextStyle(
                  color: _unidadMedidaPeso == 'kg' ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  if (val) setState(() => _unidadMedidaPeso = 'kg');
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _costoMayoristaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Costo por $unidadTexto *',
                    hintText: _unidadMedidaPeso == 'lb' ? 'Ej. 100.00' : 'Ej. 18.00',
                    prefixText: 'Bs. ',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _precioVentaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.success),
                  decoration: InputDecoration(
                    labelText: 'Precio en Balanza *',
                    hintText: _unidadMedidaPeso == 'lb' ? 'Ej. 120.00' : 'Ej. 24.00',
                    prefixText: 'Bs. ',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Banner de ganancia por peso
          _buildBannerGanancia(
            ganancia: ganancia,
            margen: margen,
            textoPersonalizado: 'Ganancia por $unidadTexto vendida:',
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app, size: 16, color: Colors.teal.shade800),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'En el Punto de Venta podrás cobrar con atajos rápidos de dinero: Bs. 2, 5, 10, 20 o por peso.',
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Stock
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _stockActualController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Existencias hoy en tienda *',
                    hintText: 'Ej. 10.5',
                    suffixText: _unidadMedidaPeso,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _stockMinimoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Avisar si quedan menos de *',
                    hintText: _unidadMedidaPeso == 'lb' ? 'Ej. 1.5' : 'Ej. 2.0',
                    suffixText: _unidadMedidaPeso == 'lb' ? 'libras' : 'kilos',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
              ),
            ],
          ),
          if (_parse(_stockMinimoController) > 0) ...[
            const SizedBox(height: 6),
            Text(
              '💡 Te alertará cuando en balanza te quede menos de ${_parse(_stockMinimoController).toStringAsFixed(1)} ${_unidadMedidaPeso == 'lb' ? 'libras' : 'kilos'}.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.teal.shade700),
            ),
          ],
        ],
      ),
    );
  }

  // Banner reutilizable para cálculo de ganancia
  Widget _buildBannerGanancia({
    required double ganancia,
    required double margen,
    String? textoPersonalizado,
  }) {
    final bool positiva = ganancia >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: positiva ? AppColors.success.withAlpha(20) : AppColors.danger.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: positiva ? AppColors.success : AppColors.danger, width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            textoPersonalizado ?? (positiva ? 'Ganancia comercial:' : 'Pérdida detectada:'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: positiva ? AppColors.success : AppColors.danger,
            ),
          ),
          Text(
            '${positiva ? '+' : ''}Bs. ${ganancia.toStringAsFixed(2)}  (${margen.toStringAsFixed(1)}%)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: positiva ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  // Tarjeta contenedora de sección
  Widget _buildCard({required String titulo, required Widget child}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: AppTypography.headlineSmall.copyWith(fontSize: 17, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}
