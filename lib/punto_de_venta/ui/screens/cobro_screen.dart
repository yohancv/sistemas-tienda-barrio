import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/config/supabase_client.dart';
import '../../../cuentas_por_cobrar/data/models/cliente_model.dart';
import '../../../cuentas_por_cobrar/state/providers/clientes_providers.dart';
import '../../../cuentas_por_cobrar/ui/widgets/modal_nuevo_cliente.dart';
import '../../../cuentas_por_cobrar/ui/widgets/modal_editar_cliente.dart';
import '../../data/models/venta_models.dart';
import '../../state/providers/carrito_providers.dart';
import '../../state/providers/pago_providers.dart';
import '../../state/providers/venta_providers.dart';
import '../../../inventario/state/providers/inventario_providers.dart';
import '../../../inventario/state/providers/movimientos_providers.dart';
import '../../../cierre_caja/state/providers/caja_providers.dart';
import '../../../reportes/state/providers/reportes_providers.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/theme/theme_provider.dart';

enum MetodoPagoCobro { efectivo, qr, mixto, fiado }

class CobroScreen extends ConsumerStatefulWidget {
  final double totalAPagar;

  const CobroScreen({
    super.key,
    required this.totalAPagar,
  });

  @override
  ConsumerState<CobroScreen> createState() => _CobroScreenState();
}

class _CobroScreenState extends ConsumerState<CobroScreen> {
  MetodoPagoCobro _metodo = MetodoPagoCobro.efectivo;
  Cliente? _clienteSeleccionado;
  bool _isProcessing = false;

  late final TextEditingController _billeteEfectivoController;
  late final TextEditingController _montoEfectivoMixtoController;
  late final TextEditingController _billeteEntregadoMixtoController;

  // Rebaja / Descuento casera
  double _descuento = 0.0;
  double get _totalCobroFinal => (widget.totalAPagar - _descuento).clamp(0.0, double.infinity);

  // Fiado parcial con anticipo
  bool _esFiadoParcial = false;
  bool _anticipoEsQr = false; // false: Efectivo, true: QR
  late final TextEditingController _anticipoFiadoController;
  late final TextEditingController _billeteAnticipoController;

  @override
  void initState() {
    super.initState();
    _billeteEfectivoController = TextEditingController();
    _montoEfectivoMixtoController = TextEditingController();
    _billeteEntregadoMixtoController = TextEditingController();
    _anticipoFiadoController = TextEditingController();
    _billeteAnticipoController = TextEditingController();
  }

  @override
  void dispose() {
    _billeteEfectivoController.dispose();
    _montoEfectivoMixtoController.dispose();
    _billeteEntregadoMixtoController.dispose();
    _anticipoFiadoController.dispose();
    _billeteAnticipoController.dispose();
    super.dispose();
  }

  void _abrirCrearNuevoCliente() async {
    final nuevo = await showModalBottomSheet<Cliente>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ModalNuevoCliente(),
    );

    if (nuevo != null && mounted) {
      setState(() => _clienteSeleccionado = nuevo);
    }
  }

  void _abrirModalEditarCliente(Cliente cliente) async {
    final actualizado = await showModalBottomSheet<Cliente>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalEditarCliente(cliente: cliente),
    );

    if (actualizado != null && mounted) {
      setState(() => _clienteSeleccionado = actualizado);
    }
  }

  void _mostrarSelectorClientes(List<Cliente> clientes) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Selecciona al Vecino / Deudor',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Botón rápido para crear cliente en el momento
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _abrirCrearNuevoCliente();
                  },
                  icon: const Icon(Icons.person_add, color: AppColors.primary),
                  label: const Text(
                    '➕ Registrar Nuevo Vecino Aquí',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: clientes.length,
                  separatorBuilder: (_, index) => Divider(height: 1, color: cardBorder),
                  itemBuilder: (context, index) {
                    final c = clientes[index];
                    final superado = c.saldoActual + widget.totalAPagar > c.limiteCredito;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      leading: CircleAvatar(
                        backgroundColor: superado
                            ? AppColors.danger.withAlpha(20)
                            : AppColors.primary.withAlpha(20),
                        child: Icon(
                          Icons.person,
                          color: superado ? AppColors.danger : AppColors.primary,
                        ),
                      ),
                      title: Text(
                        c.nombre,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                      subtitle: Text(
                        'Deuda: Bs. ${c.saldoActual.toStringAsFixed(2)} • Límite: Bs. ${c.limiteCredito.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: superado ? AppColors.danger : textSecondary,
                          fontWeight: superado ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Text(
                        'Disp: Bs. ${c.creditoDisponible.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: superado ? AppColors.danger : AppColors.success,
                        ),
                      ),
                      onTap: () {
                        setState(() => _clienteSeleccionado = c);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _abrirModalRebaja() {
    AppHaptics.light();
    final subtotal = widget.totalAPagar;
    final txtTotalController = TextEditingController(
      text: _totalCobroFinal.toStringAsFixed(2),
    );
    final txtDescuentoController = TextEditingController(
      text: _descuento > 0 ? _descuento.toStringAsFixed(2) : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final esOscuro = ref.watch(esModoOscuroProvider);
            final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
            final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
            final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;
            final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.local_offer_rounded, color: Color(0xFF10B981), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rebaja / Descuento Casera',
                                style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Ajusta el total acordado para esta venta',
                                style: TextStyle(color: textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: esOscuro ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal original calculado:', style: TextStyle(color: textSecondary, fontSize: 13)),
                          Text('Bs. ${subtotal.toStringAsFixed(2)}', style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Dos campos sincronizados: Monto a rebajar y Total final a cobrar
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Monto a rebajar:', style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: txtDescuentoController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                autofocus: true,
                                decoration: const InputDecoration(
                                  prefixText: '-Bs. ',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                ),
                                onChanged: (val) {
                                  final desc = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                                  final nuevoTotal = (subtotal - desc).clamp(0.0, subtotal);
                                  txtTotalController.text = nuevoTotal.toStringAsFixed(2);
                                  setModalState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total final a cobrar:', style: TextStyle(color: textSecondary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: txtTotalController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  prefixText: 'Bs. ',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                ),
                                onChanged: (val) {
                                  final nuevoTotal = double.tryParse(val.replaceAll(',', '.')) ?? subtotal;
                                  final desc = (subtotal - nuevoTotal).clamp(0.0, subtotal);
                                  txtDescuentoController.text = desc > 0 ? desc.toStringAsFixed(2) : '';
                                  setModalState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_descuento > 0) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.refresh, size: 16, color: AppColors.danger),
                          label: const Text('Restablecer precio original', style: TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
                          onPressed: () {
                            txtDescuentoController.text = '';
                            txtTotalController.text = subtotal.toStringAsFixed(2);
                            setModalState(() {});
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final descIngresado = double.tryParse(txtDescuentoController.text.replaceAll(',', '.')) ?? 0.0;
                          final nuevoTotal = double.tryParse(txtTotalController.text.replaceAll(',', '.')) ?? (subtotal - descIngresado);
                          final descCalculado = (subtotal - nuevoTotal).clamp(0.0, subtotal);
                          setState(() {
                            _descuento = descCalculado;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('CONFIRMAR REBAJA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmarVenta() async {
    if (_isProcessing) return;

    if (_metodo == MetodoPagoCobro.fiado && _clienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Por favor selecciona al cliente antes de registrar el fiado'),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final itemsCarrito = ref.read(carritoProvider);
      const tenantId = SupabaseConfig.defaultTenantId;

      String metodoBD = 'EFECTIVO';
      double montoRecibidoVenta = _totalCobroFinal;
      double vueltoVenta = 0.0;
      final List<PagoVenta> pagos;

      if (_metodo == MetodoPagoCobro.efectivo) {
        metodoBD = 'EFECTIVO';
        final billete = double.tryParse(_billeteEfectivoController.text.trim()) ?? _totalCobroFinal;
        montoRecibidoVenta = billete;
        final calculado = ((billete - _totalCobroFinal) * 100).round() / 100.0;
        vueltoVenta = calculado >= 0 ? calculado : 0.0;
        pagos = [
          PagoVenta(
            tenantId: tenantId,
            metodo: 'EFECTIVO',
            monto: _totalCobroFinal,
            createdAt: DateTime.now(),
          ),
        ];
      } else if (_metodo == MetodoPagoCobro.qr) {
        metodoBD = 'QR';
        montoRecibidoVenta = _totalCobroFinal;
        vueltoVenta = 0.0;
        pagos = [
          PagoVenta(
            tenantId: tenantId,
            metodo: 'QR',
            monto: _totalCobroFinal,
            createdAt: DateTime.now(),
          ),
        ];
      } else if (_metodo == MetodoPagoCobro.mixto) {
        metodoBD = 'MIXTO';
        final efectivoCobrado = double.tryParse(_montoEfectivoMixtoController.text.trim()) ?? 0.0;
        final saldoQrCobrado = ((_totalCobroFinal - efectivoCobrado) * 100).round() / 100.0;
        final billete = double.tryParse(_billeteEntregadoMixtoController.text.trim()) ?? efectivoCobrado;
        montoRecibidoVenta = billete > efectivoCobrado ? billete : efectivoCobrado;
        vueltoVenta = billete > efectivoCobrado ? ((billete - efectivoCobrado) * 100).round() / 100.0 : 0.0;
        pagos = [
          PagoVenta(
            tenantId: tenantId,
            metodo: 'EFECTIVO',
            monto: efectivoCobrado,
            createdAt: DateTime.now(),
          ),
          PagoVenta(
            tenantId: tenantId,
            metodo: 'QR',
            monto: saldoQrCobrado > 0 ? saldoQrCobrado : 0.0,
            createdAt: DateTime.now(),
          ),
        ];
      } else {
        metodoBD = 'CREDITO_FIADO';
        if (_esFiadoParcial) {
          final anticipo = double.tryParse(_anticipoFiadoController.text.trim()) ?? 0.0;
          final billeteAnticipo = double.tryParse(_billeteAnticipoController.text.trim()) ?? anticipo;
          final saldoFiado = ((_totalCobroFinal - anticipo) * 100).round() / 100.0;

          // montoRecibidoVenta refleja el anticipo neto aplicado a la venta
          montoRecibidoVenta = anticipo;
          if (!_anticipoEsQr && billeteAnticipo > anticipo) {
            vueltoVenta = ((billeteAnticipo - anticipo) * 100).round() / 100.0;
          } else {
            vueltoVenta = 0.0;
          }

          pagos = [
            PagoVenta(
              tenantId: tenantId,
              metodo: _anticipoEsQr ? 'QR' : 'EFECTIVO',
              monto: anticipo,
              createdAt: DateTime.now(),
            ),
            PagoVenta(
              tenantId: tenantId,
              metodo: 'FIADO',
              monto: saldoFiado > 0 ? saldoFiado : 0.0,
              createdAt: DateTime.now(),
            ),
          ];
        } else {
          montoRecibidoVenta = 0.0;
          vueltoVenta = 0.0;
          pagos = [
            PagoVenta(
              tenantId: tenantId,
              metodo: 'FIADO',
              monto: _totalCobroFinal,
              createdAt: DateTime.now(),
            ),
          ];
        }
      }

      // Obtener turno activo de caja (asegurándolo si aún no se había inicializado)
      var turnoActivo = ref.read(cajaTurnoActivaProvider).value;
      if (turnoActivo == null || !turnoActivo.estaAbierta) {
        final repo = ref.read(cajaRepositoryProvider);
        turnoActivo = await repo.asegurarTurnoActivo(tenantId: tenantId);
        ref.invalidate(cajaTurnoActivaProvider);
      }

      // 1. Construir cabecera de Venta
      final venta = Venta(
        tenantId: tenantId,
        clienteId: _clienteSeleccionado?.id,
        cajaTurnoId: turnoActivo.id,
        totalVenta: _totalCobroFinal,
        metodoPago: metodoBD,
        montoRecibido: montoRecibidoVenta,
        cambioEntregado: vueltoVenta,
        fechaVenta: DateTime.now(),
      );

      // 2. Construir detalles de venta ajustados proporcionalmente si hubo rebaja
      final factorDescuento = widget.totalAPagar > 0 ? _totalCobroFinal / widget.totalAPagar : 1.0;
      final detalles = itemsCarrito.map((item) {
        final cantInventario = item.descuentoInventario;
        final subtotalAjustado = ((item.subtotal * factorDescuento) * 100).round() / 100.0;
        final precioUnitarioEfectivo = cantInventario > 0
            ? ((subtotalAjustado / cantInventario) * 100).round() / 100.0
            : item.producto.precioVenta;
        return DetalleVenta(
          productoId: item.producto.id,
          cantidad: cantInventario,
          precioUnitario: precioUnitarioEfectivo,
          costoUnitario: item.producto.costoMayorista,
          subtotal: subtotalAjustado,
        );
      }).toList();

      // 3. Guardar en Supabase/SQLite y descontar stock (y actualizar saldo de cliente automáticamente vía trigger)
      await ref.read(ventaRepositoryProvider).registrarTransaccionCompleta(
            venta: venta,
            detalles: detalles,
            pagos: pagos,
          );

      // Refrescar proveedores de inventario, clientes, caja, reportes y kardex
      ref.read(carritoProvider.notifier).limpiarCarrito();
      _billeteEfectivoController.clear();
      ref.read(efectivoRecibidoProvider.notifier).corregir();
      ref.invalidate(productosListProvider);
      ref.invalidate(clientesListProvider);
      ref.invalidate(cajaTurnoActivaProvider);
      ref.invalidate(resumenCajaTurnoProvider);
      ref.invalidate(ventasTurnoProvider);
      ref.invalidate(reporteDashboardProvider);
      ref.invalidate(kardexListProvider);
      ref.invalidate(historialMovimientosProvider);

      if (!mounted) return;

      AppHaptics.medium();

      // 4. Diálogo de éxito visual adaptado al método de pago y rebaja
      await _mostrarDialogoExito(vueltoVenta, montoRecibidoVenta);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Error al registrar venta: $e', style: const TextStyle(fontSize: 18)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _mostrarDialogoExito(double vuelto, double efectivoRecibido) async {
    final subtotalOriginal = widget.totalAPagar;
    final totalCobrado = _totalCobroFinal;
    final descuento = _descuento;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              _metodo == MetodoPagoCobro.fiado ? Icons.assignment_turned_in : Icons.check_circle,
              color: AppColors.success,
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _metodo == MetodoPagoCobro.fiado
                    ? (_esFiadoParcial ? '¡Fiado Parcial Registrado!' : '¡Fiado Registrado!')
                    : '¡Venta Exitosa!',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (descuento > 0) ...[
              Text('Subtotal original: Bs. ${subtotalOriginal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, decoration: TextDecoration.lineThrough)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.retailGreen.withAlpha(30),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Rebaja: -Bs. ${descuento.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.retailGreen)),
                  ),
                  const SizedBox(width: 8),
                  Text('Total Cobrado: Bs. ${totalCobrado.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.retailGreen)),
                ],
              ),
              const SizedBox(height: 8),
            ] else ...[
              Text('Total cobrado: Bs. ${totalCobrado.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
            ],
            if (_metodo == MetodoPagoCobro.efectivo) ...[
              Text('Recibido: Bs. ${efectivoRecibido.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18)),
              const Divider(height: 20, thickness: 1.5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'VUELTO: Bs. ${vuelto.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.retailGreen,
                  ),
                ),
              ),
            ] else if (_metodo == MetodoPagoCobro.qr) ...[
              const Text('Método: Pago QR / Transferencia',
                  style: TextStyle(fontSize: 16, color: AppColors.secondary, fontWeight: FontWeight.bold)),
            ] else if (_metodo == MetodoPagoCobro.mixto) ...[
              const Text('Método: Pago Mixto (Efectivo + QR)',
                  style: TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('• En Efectivo: Bs. ${(double.tryParse(_montoEfectivoMixtoController.text) ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 15)),
              Text('• Por QR: Bs. ${(totalCobrado - (double.tryParse(_montoEfectivoMixtoController.text) ?? 0)).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 15, color: AppColors.secondary, fontWeight: FontWeight.bold)),
              if (vuelto > 0) ...[
                const Divider(height: 18, thickness: 1.5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'VUELTO EN EFECTIVO: Bs. ${vuelto.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.retailGreen,
                    ),
                  ),
                ),
              ],
            ] else ...[
              Text('Vecino: ${_clienteSeleccionado!.nombre}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (_esFiadoParcial) ...[
                Builder(
                  builder: (_) {
                    final anticipo = double.tryParse(_anticipoFiadoController.text.trim()) ?? 0.0;
                    final saldoFiado = totalCobrado - anticipo;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• Anticipo pagado hoy (${_anticipoEsQr ? "QR" : "Efectivo"}): Bs. ${anticipo.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 15, color: AppColors.retailGreen, fontWeight: FontWeight.bold)),
                        if (vuelto > 0)
                          Text('• Vuelto entregado: Bs. ${vuelto.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        Text('• Saldo fiado adeudado: Bs. ${saldoFiado.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 15, color: AppColors.danger, fontWeight: FontWeight.bold)),
                        const Divider(height: 16, thickness: 1.5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Nuevo Saldo Deudor: Bs. ${(_clienteSeleccionado!.saldoActual + saldoFiado).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ] else ...[
                const Divider(height: 16, thickness: 1.5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Nuevo Saldo Deudor: Bs. ${(_clienteSeleccionado!.saldoActual + totalCobrado).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.pop(context);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text(
                'NUEVA VENTA',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCobro = _totalCobroFinal;
    final double? billeteIngresado = double.tryParse(_billeteEfectivoController.text.trim());
    final double efectivoEntregado = billeteIngresado ?? totalCobro;
    final double diferenciaEfectivo = efectivoEntregado - totalCobro;
    final bool saldoSuficienteEfectivo = billeteIngresado == null || diferenciaEfectivo >= -0.001;
    final double vueltoEfectivo = diferenciaEfectivo > 0 ? diferenciaEfectivo : 0.0;

    final clientes = ref.watch(clientesListProvider).maybeWhen(
          data: (l) => l,
          orElse: () => <Cliente>[],
        );

    final double montoEfectivoMixto = double.tryParse(_montoEfectivoMixtoController.text.trim()) ?? 0.0;
    final double saldoQrMixto = totalCobro - montoEfectivoMixto;
    final double billeteEntregadoMixto = double.tryParse(_billeteEntregadoMixtoController.text.trim()) ?? montoEfectivoMixto;
    final bool saldoSuficienteMixto = montoEfectivoMixto > 0 &&
        montoEfectivoMixto < totalCobro &&
        saldoQrMixto > 0 &&
        billeteEntregadoMixto >= montoEfectivoMixto;

    final bool saldoFiadoPermitido;
    if (_clienteSeleccionado == null) {
      saldoFiadoPermitido = false;
    } else if (_esFiadoParcial) {
      final anticipo = double.tryParse(_anticipoFiadoController.text.trim()) ?? 0.0;
      final billeteAnticipo = double.tryParse(_billeteAnticipoController.text.trim()) ?? anticipo;
      final saldoFiado = totalCobro - anticipo;
      final anticipoValido = anticipo > 0 &&
          anticipo < totalCobro &&
          (_anticipoEsQr || billeteAnticipo >= anticipo);
      saldoFiadoPermitido = anticipoValido &&
          ((_clienteSeleccionado!.saldoActual + saldoFiado) <= _clienteSeleccionado!.limiteCredito);
    } else {
      saldoFiadoPermitido = (_clienteSeleccionado!.saldoActual + totalCobro) <= _clienteSeleccionado!.limiteCredito;
    }

    final bool puedeConfirmar = _metodo == MetodoPagoCobro.efectivo
        ? saldoSuficienteEfectivo
        : (_metodo == MetodoPagoCobro.qr
            ? true
            : (_metodo == MetodoPagoCobro.mixto
                ? saldoSuficienteMixto
                : saldoFiadoPermitido));

    final esOscuro = ref.watch(esModoOscuroProvider);
    final bgColor = esOscuro ? AppColors.darkBackground : AppColors.background;
    final surfaceColor = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final salir = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
                SizedBox(width: 8),
                Text('¿Salir del cobro?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: const Text(
              'La venta actual no se perderá: los productos seguirán guardados en tu ticket.',
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continuar cobrando', style: TextStyle(fontSize: 15)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Volver al ticket', style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
            ],
          ),
        );
        if (salir == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(
            'Cobro en Caja',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: surfaceColor,
          foregroundColor: textPrimary,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: cardBorder, height: 1.0),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Barra superior de Rebaja / Descuento Casera
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _descuento > 0
                      ? (esOscuro ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                      : (esOscuro ? AppColors.darkSurface : const Color(0xFFF8FAFC)),
                  border: Border(
                    bottom: BorderSide(
                      color: _descuento > 0 ? const Color(0xFF10B981) : cardBorder,
                      width: _descuento > 0 ? 1.5 : 1.0,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_offer_rounded,
                      color: _descuento > 0 ? const Color(0xFF10B981) : AppColors.retailBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _descuento > 0
                          ? Row(
                              children: [
                                Text(
                                  'Subtotal: Bs. ${widget.totalAPagar.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '-Bs. ${_descuento.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: FittedBox(
                                    alignment: Alignment.centerLeft,
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'A cobrar: Bs. ${_totalCobroFinal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total a cobrar: Bs. ${widget.totalAPagar.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                                ),
                                Text(
                                  '¿Compró en cantidad o es vecino casero?',
                                  style: TextStyle(fontSize: 11, color: textSecondary),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 6),
                    if (_descuento > 0)
                      IconButton(
                        tooltip: 'Quitar rebaja',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                        onPressed: () {
                          setState(() => _descuento = 0.0);
                        },
                      ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        backgroundColor: _descuento > 0
                            ? const Color(0xFF10B981).withAlpha(30)
                            : AppColors.retailBlue.withAlpha(20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _abrirModalRebaja,
                      icon: Icon(
                        _descuento > 0 ? Icons.edit : Icons.tune,
                        size: 16,
                        color: _descuento > 0 ? const Color(0xFF10B981) : AppColors.retailBlue,
                      ),
                      label: Text(
                        _descuento > 0 ? 'Modificar' : 'Rebajar',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: _descuento > 0 ? const Color(0xFF10B981) : AppColors.retailBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 1. Selector de Método de Pago (4 opciones)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  border: Border(bottom: BorderSide(color: cardBorder, width: 1.0)),
                ),
                child: Row(
                  children: [
                    _buildBotonMetodo('💵 Efectivo', MetodoPagoCobro.efectivo, esOscuro),
                    const SizedBox(width: 8),
                    _buildBotonMetodo('📱 QR', MetodoPagoCobro.qr, esOscuro),
                    const SizedBox(width: 8),
                    _buildBotonMetodo('🔀 Mixto', MetodoPagoCobro.mixto, esOscuro),
                    const SizedBox(width: 8),
                    _buildBotonMetodo('📝 Fiado', MetodoPagoCobro.fiado, esOscuro),
                  ],
                ),
              ),

              // 2. Contenido según el método de pago seleccionado
              Expanded(
                child: _metodo == MetodoPagoCobro.efectivo
                    ? _buildVistaEfectivo(
                        billeteIngresado: billeteIngresado,
                        efectivoEntregado: efectivoEntregado,
                        diferencia: diferenciaEfectivo,
                        vuelto: vueltoEfectivo,
                        saldoSuficiente: saldoSuficienteEfectivo,
                        esOscuro: esOscuro,
                      )
                    : (_metodo == MetodoPagoCobro.qr
                        ? _buildVistaQR(esOscuro)
                        : (_metodo == MetodoPagoCobro.mixto
                            ? _buildVistaMixto(esOscuro)
                            : _buildVistaFiado(clientes, esOscuro))),
              ),
            ],
          ),
        ),

        // Botón Confirmar Venta anclado en la base con FittedBox
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(top: BorderSide(color: cardBorder, width: 1.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(esOscuro ? 40 : 10),
                offset: const Offset(0, -2),
                blurRadius: 4,
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: puedeConfirmar
                    ? (esOscuro ? AppColors.darkSuccess : AppColors.retailGreen)
                    : (esOscuro ? AppColors.darkSurfaceMuted : Colors.grey.shade400),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: puedeConfirmar && !_isProcessing ? _confirmarVenta : null,
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _metodo == MetodoPagoCobro.fiado
                            ? (_esFiadoParcial
                                ? 'CONFIRMAR FIADO PARCIAL (Bs. ${totalCobro.toStringAsFixed(2)})'
                                : 'CONFIRMAR FIADO (Bs. ${totalCobro.toStringAsFixed(2)})')
                            : 'CONFIRMAR VENTA (Bs. ${totalCobro.toStringAsFixed(2)})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: puedeConfirmar
                              ? (esOscuro ? AppColors.darkSuccessDark : Colors.white)
                              : Colors.white60,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBotonMetodo(String label, MetodoPagoCobro metodo, bool esOscuro) {
    final seleccionado = _metodo == metodo;
    final unselectedBg = esOscuro ? AppColors.darkSurface : AppColors.surfaceMuted;
    final unselectedBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final unselectedText = esOscuro ? AppColors.darkTextSecondary : AppColors.textPrimary;

    return Expanded(
      child: SizedBox(
        height: 46,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            backgroundColor: seleccionado ? AppColors.retailBlue : unselectedBg,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: seleccionado ? AppColors.retailBlue : unselectedBorder,
                width: seleccionado ? 1.5 : 1,
              ),
            ),
          ),
          onPressed: () {
            AppHaptics.selection();
            setState(() => _metodo = metodo);
          },
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: seleccionado ? Colors.white : unselectedText,
            ),
          ),
        ),
      ),
    );
  }

  // --- Vista Pago Mixto (Efectivo + QR) ---
  Widget _buildVistaMixto(bool esOscuro) {
    final double total = _totalCobroFinal;
    final double efectivoACobrar = double.tryParse(_montoEfectivoMixtoController.text.trim()) ?? 0.0;
    final double saldoQr = (total - efectivoACobrar) > 0 ? (total - efectivoACobrar) : 0.0;
    final double billeteEntregado = double.tryParse(_billeteEntregadoMixtoController.text.trim()) ?? efectivoACobrar;
    final double vuelto = (billeteEntregado - efectivoACobrar) > 0 ? (billeteEntregado - efectivoACobrar) : 0.0;
    final bool valido = efectivoACobrar > 0 && efectivoACobrar < total;

    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Resumen Total
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: esOscuro ? AppColors.darkSurface : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: esOscuro ? AppColors.darkBorder : const Color(0xFFBFDBFE)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL DE LA CUENTA:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textSecondary)),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Bs. ${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.retailBlue),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Bloque 1: Parte en Efectivo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.attach_money, color: AppColors.retailGreen, size: 22),
                    SizedBox(width: 6),
                    Text('1. Parte pagada en Efectivo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.retailGreen)),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _montoEfectivoMixtoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.retailGreen),
                  decoration: const InputDecoration(
                    labelText: 'Monto a pagar en Efectivo (Bs.) *',
                    prefixText: 'Bs. ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),

                // Atajos rápidos de importe
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Text('Atajos: ', style: TextStyle(fontSize: 12, color: textSecondary)),
                    ActionChip(
                      label: const Text('Mitad (50%)', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        final mitad = (total / 2.0);
                        _montoEfectivoMixtoController.text = mitad.toStringAsFixed(2);
                        setState(() {});
                      },
                    ),
                    if (total > 10)
                      ActionChip(
                        label: const Text('Bs. 10', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          _montoEfectivoMixtoController.text = '10.00';
                          setState(() {});
                        },
                      ),
                    if (total > 20)
                      ActionChip(
                        label: const Text('Bs. 20', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          _montoEfectivoMixtoController.text = '20.00';
                          setState(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Campo Billete entregado
                TextField(
                  controller: _billeteEntregadoMixtoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Billete recibido (Opcional para vuelto)',
                    hintText: efectivoACobrar > 0 ? 'Ej. ${efectivoACobrar.toStringAsFixed(0)}' : 'Ej. 50',
                    prefixText: 'Bs. ',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (vuelto > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.retailGreen.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Vuelto en efectivo a entregar:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Bs. ${vuelto.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.retailGreen)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Bloque 2: Saldo restante por QR
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_2, color: AppColors.retailBlue, size: 24),
                    SizedBox(width: 8),
                    Text('2. Saldo restante por QR', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.retailBlue)),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: esOscuro ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: esOscuro ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    children: [
                      Text('El cliente debe escanear el QR por:', style: TextStyle(fontSize: 13, color: textSecondary)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Bs. ${saldoQr.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.retailBlue),
                        ),
                      ),
                      if (!valido && efectivoACobrar >= total) ...[
                        const SizedBox(height: 4),
                        const Text('⚠️ El efectivo ya cubre todo el total. Usa la pestaña "Efectivo".', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold)),
                      ] else if (!valido) ...[
                        const SizedBox(height: 4),
                        Text('Ingresa el monto en efectivo para calcular el QR restante.', style: TextStyle(color: textSecondary, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Vista Efectivo ---
  Widget _buildVistaEfectivo({
    required double? billeteIngresado,
    required double efectivoEntregado,
    required double diferencia,
    required double vuelto,
    required bool saldoSuficiente,
    required bool esOscuro,
  }) {
    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final total = _totalCobroFinal;

    // Sugerir billetes bolivianos útiles según el total de la cuenta
    final List<double> billetesEstandar = [10.0, 20.0, 50.0, 100.0, 200.0];
    final List<double> billetesUtiles = billetesEstandar.where((b) => b >= total).toList();
    if (billetesUtiles.isEmpty) {
      final prox100 = ((total / 100).ceil()) * 100.0;
      billetesUtiles.add(prox100);
      billetesUtiles.add(prox100 + 100.0);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tarjeta Resumen: Estado del Pago en Efectivo
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: !saldoSuficiente
                  ? (esOscuro ? const Color(0xFF7F1D1D).withAlpha(50) : const Color(0xFFFEE2E2))
                  : (billeteIngresado != null && vuelto > 0
                      ? (esOscuro ? const Color(0xFF064E3B).withAlpha(60) : const Color(0xFFECFDF5))
                      : cardBg),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: !saldoSuficiente
                    ? AppColors.danger
                    : (billeteIngresado != null && vuelto > 0
                        ? const Color(0xFF10B981)
                        : cardBorder),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(esOscuro ? 30 : 8),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL A COBRAR:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: billeteIngresado == null
                            ? const Color(0xFF10B981).withAlpha(25)
                            : (saldoSuficiente ? AppColors.retailBlue.withAlpha(25) : AppColors.danger.withAlpha(25)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            billeteIngresado == null
                                ? Icons.flash_on
                                : (saldoSuficiente ? Icons.payments : Icons.warning_amber),
                            size: 14,
                            color: billeteIngresado == null
                                ? const Color(0xFF10B981)
                                : (saldoSuficiente ? AppColors.retailBlue : AppColors.danger),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            billeteIngresado == null
                                ? 'PAGO EXACTO'
                                : (saldoSuficiente ? 'CON VUELTO' : 'MONTO INSUFICIENTE'),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: billeteIngresado == null
                                  ? const Color(0xFF10B981)
                                  : (saldoSuficiente ? AppColors.retailBlue : AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Bs. ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: AppColors.retailBlue,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: cardBorder),
                const SizedBox(height: 12),

                // Resultado interactivo
                if (billeteIngresado == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: esOscuro ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Por defecto se asume pago exacto. Toca "CONFIRMAR VENTA" abajo para guardar.',
                            style: TextStyle(fontSize: 12.5, color: textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!saldoSuficiente)
                  Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'FALTAN: Bs. ${(-diferencia).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'El billete recibido (Bs. ${efectivoEntregado.toStringAsFixed(2)}) no cubre el total de la cuenta.',
                        style: const TextStyle(fontSize: 12, color: AppColors.danger),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      Text(
                        'VUELTO A ENTREGAR:',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textSecondary),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Bs. ${vuelto.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Recibido: Bs. ${efectivoEntregado.toStringAsFixed(2)}  •  Cobro: Bs. ${total.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bloque: Calculadora de Vuelto
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calculate_outlined, color: AppColors.retailBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Calculadora de Vuelto',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Si el cliente paga con un billete mayor, anótalo o tócalo para calcular el cambio:',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 14),

                // Campo de texto del billete
                TextField(
                  controller: _billeteEfectivoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.attach_money, color: AppColors.retailBlue),
                    prefixText: 'Bs. ',
                    prefixStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                    labelText: 'Billete o monto entregado',
                    filled: true,
                    fillColor: esOscuro ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.retailBlue, width: 2),
                    ),
                    suffixIcon: _billeteEfectivoController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                            tooltip: 'Restablecer a pago exacto',
                            onPressed: () {
                              AppHaptics.light();
                              _billeteEfectivoController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),

                // Chips de Billetes Rápidos
                Text(
                  'Billetes sugeridos:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Chip Pago Exacto
                    ChoiceChip(
                      selected: billeteIngresado == null,
                      avatar: const Icon(Icons.flash_on, size: 16),
                      label: const Text('Exacto'),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: billeteIngresado == null ? Colors.white : textPrimary,
                      ),
                      selectedColor: const Color(0xFF10B981),
                      backgroundColor: esOscuro ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      onSelected: (selected) {
                        AppHaptics.light();
                        _billeteEfectivoController.clear();
                        setState(() {});
                      },
                    ),
                    // Chips para cada billete útil
                    ...billetesUtiles.map((b) {
                      final bool esSeleccionado = billeteIngresado != null && (billeteIngresado - b).abs() < 0.001;
                      return ChoiceChip(
                        selected: esSeleccionado,
                        label: Text('Bs. ${b.toInt()}'),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: esSeleccionado ? Colors.white : textPrimary,
                        ),
                        selectedColor: AppColors.retailBlue,
                        backgroundColor: esOscuro ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        onSelected: (selected) {
                          AppHaptics.light();
                          _billeteEfectivoController.text = b.toInt().toString();
                          setState(() {});
                        },
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Vista QR ---
  Widget _buildVistaQR(bool esOscuro) {
    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final total = _totalCobroFinal;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.retailBlue.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.qr_code_2, size: 52, color: AppColors.retailBlue),
              ),
              const SizedBox(height: 16),
              Text(
                'COBRO POR QR',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Muestra el código QR al cliente por el monto exacto:',
                style: TextStyle(fontSize: 14, color: textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Bs. ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.retailGreen,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Una vez que el cliente confirme la transferencia en su celular, presiona el botón inferior para cerrar la venta.',
                style: TextStyle(fontSize: 12, color: textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Vista Fiado / Crédito con opción de Fiado Parcial ---
  Widget _buildVistaFiado(List<Cliente> clientes, bool esOscuro) {
    final cliente = _clienteSeleccionado;
    final saldoActual = cliente?.saldoActual ?? 0.0;
    final limite = cliente?.limiteCredito ?? 100.0;
    final totalCobro = _totalCobroFinal;

    // Cálculos de Fiado Parcial vs Fiado Total
    final double anticipo = _esFiadoParcial ? (double.tryParse(_anticipoFiadoController.text.trim()) ?? 0.0) : 0.0;
    final double saldoFiado = _esFiadoParcial
        ? ((totalCobro - anticipo) > 0 ? (totalCobro - anticipo) : 0.0)
        : totalCobro;
    final double billeteAnticipo = double.tryParse(_billeteAnticipoController.text.trim()) ?? anticipo;
    final double vueltoAnticipo = (!_anticipoEsQr && billeteAnticipo > anticipo) ? billeteAnticipo - anticipo : 0.0;

    final double totalProyectado = saldoActual + saldoFiado;
    final bool excedeLimite = totalProyectado > limite;
    final bool anticipoInvalido = _esFiadoParcial && (anticipo <= 0 || anticipo >= totalCobro);

    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Selector de Cliente
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cliente == null ? AppColors.warning : cardBorder,
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VECINO / CLIENTE QUE SACA FIADO:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textSecondary),
                ),
                const SizedBox(height: 10),
                if (cliente == null)
                  const Text(
                    '⚠️ Aún no has seleccionado ningún cliente',
                    style: TextStyle(fontSize: 15, color: AppColors.warning, fontWeight: FontWeight.bold),
                  )
                else
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.retailBlue.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person, color: AppColors.retailBlue, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cliente.nombre,
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Deuda: Bs. ${cliente.saldoActual.toStringAsFixed(2)} • Límite: Bs. ${cliente.limiteCredito.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 13, color: textSecondary),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _abrirModalEditarCliente(cliente),
                                  borderRadius: BorderRadius.circular(6),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Icon(Icons.edit_outlined, size: 15, color: AppColors.retailBlue),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.retailBlue, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _mostrarSelectorClientes(clientes),
                        icon: const Icon(Icons.search, color: AppColors.retailBlue),
                        label: Text(
                          cliente == null ? 'Buscar Vecino' : 'Cambiar Vecino',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.retailBlue),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: AppColors.retailBlue),
                      icon: const Icon(Icons.person_add, color: Colors.white),
                      tooltip: 'Registrar nuevo vecino',
                      onPressed: _abrirCrearNuevoCliente,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. Modalidad de Fiado: Total (100%) vs Parcial con Anticipo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MODALIDAD DE COBRO FIADO:',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _esFiadoParcial = false),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: !_esFiadoParcial
                                ? AppColors.retailBlue.withAlpha(25)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: !_esFiadoParcial ? AppColors.retailBlue : cardBorder,
                              width: !_esFiadoParcial ? 1.6 : 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                color: !_esFiadoParcial ? AppColors.retailBlue : textSecondary,
                                size: 22,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fiado Total (100%)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: !_esFiadoParcial ? AppColors.retailBlue : textPrimary,
                                ),
                              ),
                              Text('No paga nada hoy', style: TextStyle(fontSize: 10.5, color: textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _esFiadoParcial = true),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _esFiadoParcial
                                ? const Color(0xFF10B981).withAlpha(25)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _esFiadoParcial ? const Color(0xFF10B981) : cardBorder,
                              width: _esFiadoParcial ? 1.6 : 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.payments_outlined,
                                color: _esFiadoParcial ? const Color(0xFF10B981) : textSecondary,
                                size: 22,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fiado Parcial',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: _esFiadoParcial ? const Color(0xFF10B981) : textPrimary,
                                ),
                              ),
                              Text('Paga una parte hoy', style: TextStyle(fontSize: 10.5, color: textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Formulario de anticipo cuando se activa Fiado Parcial
                if (_esFiadoParcial) ...[
                  const SizedBox(height: 14),
                  Divider(height: 1, color: cardBorder),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Método del anticipo:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('💵 Efectivo', style: TextStyle(fontSize: 11)),
                            selected: !_anticipoEsQr,
                            onSelected: (val) {
                              if (val) setState(() => _anticipoEsQr = false);
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('📱 QR', style: TextStyle(fontSize: 11)),
                            selected: _anticipoEsQr,
                            onSelected: (val) {
                              if (val) setState(() => _anticipoEsQr = true);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _anticipoFiadoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    decoration: const InputDecoration(
                      labelText: 'Monto de anticipo que paga hoy (Bs.) *',
                      prefixText: 'Bs. ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  // Atajos rápidos
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Text('Atajos: ', style: TextStyle(fontSize: 11.5, color: textSecondary)),
                      ActionChip(
                        label: const Text('Mitad (50%)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          final mitad = totalCobro / 2.0;
                          _anticipoFiadoController.text = mitad.toStringAsFixed(2);
                          setState(() {});
                        },
                      ),
                      if (totalCobro > 10)
                        ActionChip(
                          label: const Text('Bs. 10', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            _anticipoFiadoController.text = '10.00';
                            setState(() {});
                          },
                        ),
                      if (totalCobro > 20)
                        ActionChip(
                          label: const Text('Bs. 20', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            _anticipoFiadoController.text = '20.00';
                            setState(() {});
                          },
                        ),
                      if (totalCobro > 50)
                        ActionChip(
                          label: const Text('Bs. 50', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            _anticipoFiadoController.text = '50.00';
                            setState(() {});
                          },
                        ),
                    ],
                  ),

                  // Si el anticipo es en efectivo, permitir registrar billete entregado para cambio
                  if (!_anticipoEsQr) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _billeteAnticipoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Billete recibido para el anticipo (Opcional)',
                        hintText: anticipo > 0 ? 'Ej. ${anticipo.toStringAsFixed(0)}' : 'Ej. 50',
                        prefixText: 'Bs. ',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (vueltoAnticipo > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Vuelto en efectivo a entregar:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Bs. ${vueltoAnticipo.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.retailBlue.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.qr_code, color: AppColors.retailBlue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'El vecino transferirá Bs. ${anticipo.toStringAsFixed(2)} por QR.',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (anticipoInvalido) ...[
                    const SizedBox(height: 8),
                    Text(
                      anticipo >= totalCobro
                          ? '⚠️ El anticipo cubre o supera todo el total. Selecciona cobro en Efectivo o QR regular.'
                          : '⚠️ Ingresa un monto de anticipo válido mayor a 0.',
                      style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. Tarjeta de Validación de Límite de Crédito y Desglose
          if (cliente != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: excedeLimite
                    ? (esOscuro ? const Color(0xFFDC2626).withAlpha(25) : AppColors.danger.withAlpha(15))
                    : (esOscuro ? const Color(0xFF16A34A).withAlpha(25) : AppColors.retailGreen.withAlpha(15)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: excedeLimite ? AppColors.danger : AppColors.retailGreen,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        excedeLimite ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                        color: excedeLimite ? AppColors.danger : AppColors.retailGreen,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          excedeLimite ? 'LÍMITE DE CRÉDITO SUPERADO' : 'CRÉDITO AUTORIZADO',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: excedeLimite ? AppColors.danger : AppColors.retailGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 18, color: cardBorder),
                  if (_esFiadoParcial) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total acordado venta:', style: TextStyle(fontSize: 13.5, color: textSecondary)),
                        Text('Bs. ${totalCobro.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Anticipo pagado hoy (${_anticipoEsQr ? "QR" : "Efectivo"}):', style: const TextStyle(fontSize: 13.5, color: Color(0xFF10B981))),
                        Text('-Bs. ${anticipo.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Saldo que se anota al Fiado:', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textPrimary)),
                        Text('+Bs. ${saldoFiado.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.retailBlue)),
                      ],
                    ),
                    Divider(height: 14, color: cardBorder),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Deuda anterior:', style: TextStyle(fontSize: 13.5, color: textSecondary)),
                      Text('Bs. ${saldoActual.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                    ],
                  ),
                  if (!_esFiadoParcial) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Esta compra:', style: TextStyle(fontSize: 13.5, color: textSecondary)),
                        Text('+Bs. ${totalCobro.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                      ],
                    ),
                  ],
                  Divider(height: 14, color: cardBorder),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Nueva Deuda Total:',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textPrimary)),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Bs. ${totalProyectado.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: excedeLimite ? AppColors.danger : AppColors.retailBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (excedeLimite) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '⚠️ Esta compra sobrepasa su límite de Bs. ${limite.toStringAsFixed(2)} en Bs. ${(totalProyectado - limite).toStringAsFixed(2)}. Puedes aumentarle el límite o solicitar un anticipo mayor.',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _abrirModalEditarCliente(cliente),
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text('Aumentar límite de fiado a este vecino'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
