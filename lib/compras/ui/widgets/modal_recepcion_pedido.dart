import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../cierre_caja/state/providers/caja_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../inventario/state/providers/inventario_providers.dart';
import '../../../inventario/state/providers/movimientos_providers.dart';
import '../../data/models/compra_model.dart';
import '../../data/models/item_compra_model.dart';
import '../../state/providers/compras_providers.dart';

/// Modal para recepcionar la mercadería cuando el camión llega físicamente a la tienda:
/// 1. Permite verificar y ajustar las cantidades recibidas si el pedido vino incompleto.
/// 2. Permite ajustar costos si hubo variación en la nota de entrega del chofer.
/// 3. Selecciona el método de pago (descuenta de la caja del turno activo).
/// 4. Suma el stock real y audita en el Kardex.
class ModalRecepcionPedido extends ConsumerStatefulWidget {
  final CompraModel pedido;

  const ModalRecepcionPedido({
    super.key,
    required this.pedido,
  });

  @override
  ConsumerState<ModalRecepcionPedido> createState() =>
      _ModalRecepcionPedidoState();
}

class _ModalRecepcionPedidoState extends ConsumerState<ModalRecepcionPedido> {
  bool _isLoadingDetalle = true;
  bool _isProcessing = false;
  String? _errorMessage;

  List<ItemCompraModel> _items = [];
  Map<String, double> _cantidadesOriginales = {};
  final List<ItemCompraModel> _itemsNoLlegaron = [];

  String _metodoPago = 'EFECTIVO_CAJA';
  final TextEditingController _comprobanteController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();
  final TextEditingController _montoCajaMixtoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _comprobanteController.text = widget.pedido.numeroComprobante ?? '';
    _observacionesController.text = widget.pedido.observaciones ?? '';
    _cargarDetalles();
  }

  @override
  void dispose() {
    _comprobanteController.dispose();
    _observacionesController.dispose();
    _montoCajaMixtoController.dispose();
    super.dispose();
  }

  void _cargarDetalles() async {
    try {
      final repo = ref.read(comprasRepositoryProvider);
      final detalles = await repo.obtenerDetalleCompra(widget.pedido.id);
      if (mounted) {
        setState(() {
          _items = detalles;
          _cantidadesOriginales = {for (final d in detalles) d.productoId: d.cantidad};
          _isLoadingDetalle = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar pedido: $e';
          _isLoadingDetalle = false;
        });
      }
    }
  }

  double get _totalRecibido =>
      _items.fold(0.0, (acc, item) => acc + item.subtotal);

  void _quitarProductoNoLlego(ItemCompraModel item) {
    setState(() {
      _items.removeWhere((i) => i.productoId == item.productoId);
      if (!_itemsNoLlegaron.any((i) => i.productoId == item.productoId)) {
        _itemsNoLlegaron.add(item);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.textPrimary,
        duration: const Duration(seconds: 4),
        content: Text('❌ "${item.nombreProducto}" no llegó (omitido del cobro y stock).'),
        action: SnackBarAction(
          label: 'DESHACER',
          textColor: AppColors.secondary,
          onPressed: () => _restaurarItem(item),
        ),
      ),
    );
  }

  void _restaurarItem(ItemCompraModel item) {
    setState(() {
      _itemsNoLlegaron.removeWhere((i) => i.productoId == item.productoId);
      final cantOrig = _cantidadesOriginales[item.productoId] ?? item.cantidad;
      if (!_items.any((i) => i.productoId == item.productoId)) {
        _items.add(item.copyWith(
          cantidad: cantOrig,
          subtotal: cantOrig * item.costoUnitario,
        ));
      }
    });
  }

  void _actualizarCantidad(String productoId, double nuevaCantidad) {
    setState(() {
      if (nuevaCantidad <= 0) {
        final item = _items.firstWhere((i) => i.productoId == productoId);
        _quitarProductoNoLlego(item);
      } else {
        _items = _items.map((i) {
          if (i.productoId == productoId) {
            return i.copyWith(
              cantidad: nuevaCantidad,
              subtotal: nuevaCantidad * i.costoUnitario,
            );
          }
          return i;
        }).toList();
      }
    });
  }

  void _actualizarCosto(String productoId, double nuevoCosto) {
    if (nuevoCosto < 0) return;
    setState(() {
      _items = _items.map((i) {
        if (i.productoId == productoId) {
          return i.copyWith(
            costoUnitario: nuevoCosto,
            subtotal: i.cantidad * nuevoCosto,
          );
        }
        return i;
      }).toList();
    });
  }

  void _mostrarDialogoAjustarCosto(ItemCompraModel item) {
    final controller = TextEditingController(text: item.costoUnitario.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ajustar Costo: ${item.nombreProducto}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresa el costo unitario por pieza según la nota o factura de entrega recibida:',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Costo Unitario (Bs.)',
                prefixText: 'Bs. ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final nuevo = double.tryParse(controller.text.replaceAll(',', '.'));
              if (nuevo != null && nuevo >= 0) {
                _actualizarCosto(item.productoId, nuevo);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  void _confirmarRecepcion() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('No hay productos en la entrega. Cancela el pedido si no llegó nada.'),
        ),
      );
      return;
    }

    final total = _totalRecibido;
    final cajaTurno = ref.read(cajaTurnoActivaProvider).valueOrNull;
    final efectivoCajaDisponible =
        ref.read(resumenCajaTurnoProvider).valueOrNull?.montoEsperadoEfectivo ?? 0.0;

    double montoCaja = 0.0;
    double montoExterno = 0.0;

    if (_metodoPago == 'EFECTIVO_CAJA') {
      if (cajaTurno == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('No hay un turno de caja abierto para registrar el egreso de efectivo.'),
          ),
        );
        return;
      }
      if (efectivoCajaDisponible < total) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.warning,
            content: Text(
              'Efectivo insuficiente en caja (Hay Bs. ${efectivoCajaDisponible.toStringAsFixed(2)} y el total es Bs. ${total.toStringAsFixed(2)}). Usa Dinero Propio o Pago Mixto.',
            ),
          ),
        );
        return;
      }
      montoCaja = total;
    } else if (_metodoPago == 'PAGO_MIXTO') {
      final mc = double.tryParse(_montoCajaMixtoController.text.trim()) ?? 0.0;
      if (mc > efectivoCajaDisponible) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.warning,
            content: Text('El monto asignado a caja supera el efectivo disponible en el turno.'),
          ),
        );
        return;
      }
      montoCaja = mc;
      montoExterno = total - mc;
    } else {
      montoExterno = total;
    }

    setState(() => _isProcessing = true);

    try {
      final repo = ref.read(comprasRepositoryProvider);
      final res = await repo.confirmarRecepcionPedido(
        pedidoId: widget.pedido.id,
        detallesRecibidos: _items,
        metodoPago: _metodoPago,
        montoCaja: montoCaja,
        montoExterno: montoExterno,
        cajaTurnoId: montoCaja > 0 ? cajaTurno?.id : null,
        numeroComprobante: _comprobanteController.text.trim().isNotEmpty
            ? _comprobanteController.text.trim()
            : null,
        observaciones: _observacionesController.text.trim().isNotEmpty
            ? _observacionesController.text.trim()
            : null,
      );

      // Invalidad proveedores
      ref.invalidate(pedidosPendientesProvider);
      ref.invalidate(productosListProvider);
      ref.invalidate(kardexListProvider);
      ref.invalidate(historialComprasProvider);
      ref.invalidate(historialMovimientosProvider);
      if (montoCaja > 0) {
        ref.invalidate(resumenCajaTurnoProvider);
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pop(context, true);
        final prov = res['proveedor'] ?? 'Proveedor';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
            content: Text(
              '✅ ¡Entrega de $prov confirmada! Mercadería ingresada al inventario y pago registrado (Bs. ${total.toStringAsFixed(2)}).',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Error al confirmar recepción: $e'),
          ),
        );
      }
    }
  }

  void _cancelarPedido() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar este pedido?'),
        content: const Text(
          'El pedido quedará registrado como CANCELADO. No se alterará la caja ni el inventario.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, Cancelar Pedido', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final repo = ref.read(comprasRepositoryProvider);
      await repo.cancelarPedidoPendiente(widget.pedido.id);
      ref.invalidate(pedidosPendientesProvider);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido cancelado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.danger, content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cajaTurno = ref.watch(cajaTurnoActivaProvider).valueOrNull;
    final efectivoCajaDisponible =
        ref.watch(resumenCajaTurnoProvider).valueOrNull?.montoEsperadoEfectivo ?? 0.0;
    final provNombre = widget.pedido.nombreProveedor ?? 'Proveedor';

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header del Modal
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recepción de Camión: $provNombre',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Pedido realizado: ${widget.pedido.fechaCompra.day}/${widget.pedido.fechaCompra.month} • Ajusta lo que realmente llegó',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Contenido
          Expanded(
            child: _isLoadingDetalle
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : ListView(
                        padding: const EdgeInsets.all(14),
                        children: [
                          // Alerta explicativa
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.warning.withAlpha(70)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Revisa lo que bajó el chofer. Si un producto vino incompleto, reduce la cantidad. Si no trajo nada, elimínalo con la ❌.',
                                    style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          const Text(
                            'PRODUCTOS A CONFIRMAR:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Lista de Productos con Controles Táctiles
                          ..._items.map((item) {
                            final tieneEmpaque = item.unidadesPorEmpaque > 1;
                            final cantEmpaques = tieneEmpaque ? (item.cantidad / item.unidadesPorEmpaque) : item.cantidad;
                            final cantOrig = _cantidadesOriginales[item.productoId] ?? item.cantidad;
                            final vinoIncompleto = item.cantidad < cantOrig;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: vinoIncompleto ? AppColors.warning.withAlpha(120) : AppColors.border,
                                  width: vinoIncompleto ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Nombre y Costo
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.nombreProducto,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        InkWell(
                                          onTap: () => _mostrarDialogoAjustarCosto(item),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  tieneEmpaque
                                                      ? '${item.nombreEmpaqueLegible} x${item.unidadesPorEmpaque.toInt()}u • Bs. ${item.costoUnitario.toStringAsFixed(2)}/u'
                                                      : 'Costo: Bs. ${item.costoUnitario.toStringAsFixed(2)}/u',
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.edit, size: 12, color: AppColors.primary),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Subtotal: Bs. ${item.subtotal.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        if (vinoIncompleto)
                                          Container(
                                            margin: const EdgeInsets.only(top: 3),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.warning.withAlpha(30),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '⚠️ Faltaron ${tieneEmpaque ? ((cantOrig - item.cantidad) / item.unidadesPorEmpaque).toStringAsFixed(cantEmpaques % 1 == 0 ? 0 : 1) : (cantOrig - item.cantidad).toInt()} ${tieneEmpaque ? item.nombreEmpaquePlural : 'uds'}',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Controles de Cantidad Recibida
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(Icons.remove, size: 18),
                                          onPressed: () {
                                            if (tieneEmpaque) {
                                              _actualizarCantidad(
                                                item.productoId,
                                                item.cantidad - item.unidadesPorEmpaque,
                                              );
                                            } else {
                                              _actualizarCantidad(item.productoId, item.cantidad - 1);
                                            }
                                          },
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              tieneEmpaque
                                                  ? '${cantEmpaques.toStringAsFixed(cantEmpaques % 1 == 0 ? 0 : 1)} ${item.nombreEmpaquePlural}'
                                                  : '${item.cantidad.toInt()} uds',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                            if (tieneEmpaque)
                                              Text(
                                                '(${item.cantidad.toInt()} uds)',
                                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                              ),
                                          ],
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                                          onPressed: () {
                                            if (tieneEmpaque) {
                                              _actualizarCantidad(
                                                item.productoId,
                                                item.cantidad + item.unidadesPorEmpaque,
                                              );
                                            } else {
                                              _actualizarCantidad(item.productoId, item.cantidad + 1);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Botón explícito para quitar si el camión no trajo nada
                                  InkWell(
                                    onTap: () => _quitarProductoNoLlego(item),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 16),
                                          SizedBox(height: 1),
                                          Text(
                                            'No vino',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.danger,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          // Lista de productos que NO vinieron (omitidos de la entrega)
                          if (_itemsNoLlegaron.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_itemsNoLlegaron.length} PRODUCTO(S) QUE NO LLEGARON:',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.danger,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Estos productos se quitaron de la entrega. NO se cobrarán de la caja ni se sumarán al inventario.',
                                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                  const SizedBox(height: 8),
                                  ..._itemsNoLlegaron.map((itemNo) => Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.shade100),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            itemNo.nombreProducto,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              decoration: TextDecoration.lineThrough,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ),
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            foregroundColor: AppColors.primary,
                                          ),
                                          onPressed: () => _restaurarItem(itemNo),
                                          icon: const Icon(Icons.restore, size: 14),
                                          label: const Text('Restaurar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          // Comprobante / Nota de Entrega
                          TextField(
                            controller: _comprobanteController,
                            decoration: InputDecoration(
                              labelText: 'Nº Factura / Nota de Entrega (Opcional)',
                              prefixIcon: const Icon(Icons.receipt_outlined, size: 20),
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Método de Pago
                          const Text(
                            'MÉTODO DE PAGO AL CHOFER:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: Text(
                                  '💵 Efectivo Caja (${cajaTurno != null ? "Bs. ${efectivoCajaDisponible.toStringAsFixed(0)}" : "Sin turno"})',
                                ),
                                selected: _metodoPago == 'EFECTIVO_CAJA',
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: _metodoPago == 'EFECTIVO_CAJA' ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => setState(() => _metodoPago = 'EFECTIVO_CAJA'),
                              ),
                              ChoiceChip(
                                label: const Text('🏧 Dinero Propio / Bolsillo'),
                                selected: _metodoPago == 'EFECTIVO_EXTERNO_ATM',
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: _metodoPago == 'EFECTIVO_EXTERNO_ATM' ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => setState(() => _metodoPago = 'EFECTIVO_EXTERNO_ATM'),
                              ),
                              ChoiceChip(
                                label: const Text('📱 QR / Banco Personal'),
                                selected: _metodoPago == 'QR_BANCO',
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: _metodoPago == 'QR_BANCO' ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => setState(() => _metodoPago = 'QR_BANCO'),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Botón Cancelar Pedido
                          Center(
                            child: TextButton.icon(
                              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                              onPressed: _cancelarPedido,
                              icon: const Icon(Icons.cancel_outlined, size: 16),
                              label: const Text('Cancelar este pedido (El camión no vendrá)'),
                            ),
                          ),
                        ],
                      ),
          ),

          // Barra Inferior de Confirmación
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 6, offset: const Offset(0, -2)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_totalRecibido < widget.pedido.totalCompra)
                          Text(
                            'Pedido original: Bs. ${widget.pedido.totalCompra.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.textMuted,
                            ),
                          ),
                        Text(
                          'Bs. ${_totalRecibido.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        if (_totalRecibido < widget.pedido.totalCompra)
                          Text(
                            'Entrega incompleta (-Bs. ${(widget.pedido.totalCompra - _totalRecibido).toStringAsFixed(2)})',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warning),
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    onPressed: _isProcessing ? null : _confirmarRecepcion,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 22),
                    label: Text(
                      _isProcessing ? 'Confirmando...' : 'Confirmar y Pagar',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
