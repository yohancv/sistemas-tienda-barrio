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

  late final TextEditingController _montoEfectivoMixtoController;
  late final TextEditingController _billeteEntregadoMixtoController;

  @override
  void initState() {
    super.initState();
    _montoEfectivoMixtoController = TextEditingController();
    _billeteEntregadoMixtoController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(efectivoRecibidoProvider.notifier).corregir();
    });
  }

  @override
  void dispose() {
    _montoEfectivoMixtoController.dispose();
    _billeteEntregadoMixtoController.dispose();
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Selecciona al Vecino / Deudor',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
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
                  separatorBuilder: (_, index) => const Divider(height: 1),
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
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Deuda: Bs. ${c.saldoActual.toStringAsFixed(2)} • Límite: Bs. ${c.limiteCredito.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: superado ? AppColors.danger : AppColors.textSecondary,
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
      final efectivoRecibido = ref.read(efectivoRecibidoProvider);
      final itemsCarrito = ref.read(carritoProvider);
      const tenantId = SupabaseConfig.defaultTenantId;

      String metodoBD = 'EFECTIVO';
      double montoRecibidoVenta = widget.totalAPagar;
      double vueltoVenta = 0.0;

      if (_metodo == MetodoPagoCobro.efectivo) {
        metodoBD = 'EFECTIVO';
        montoRecibidoVenta = efectivoRecibido;
        final calculado = ((efectivoRecibido - widget.totalAPagar) * 100).round() / 100.0;
        vueltoVenta = calculado >= 0 ? calculado : 0.0;
      } else if (_metodo == MetodoPagoCobro.qr) {
        metodoBD = 'QR';
        montoRecibidoVenta = widget.totalAPagar;
        vueltoVenta = 0.0;
      } else if (_metodo == MetodoPagoCobro.mixto) {
        metodoBD = 'MIXTO';
        final efectivoCobrado = double.tryParse(_montoEfectivoMixtoController.text.trim()) ?? 0.0;
        final billete = double.tryParse(_billeteEntregadoMixtoController.text.trim()) ?? efectivoCobrado;
        montoRecibidoVenta = billete > efectivoCobrado ? billete : efectivoCobrado;
        vueltoVenta = billete > efectivoCobrado ? ((billete - efectivoCobrado) * 100).round() / 100.0 : 0.0;
      } else if (_metodo == MetodoPagoCobro.fiado) {
        metodoBD = 'CREDITO_FIADO';
        montoRecibidoVenta = 0.0;
        vueltoVenta = 0.0;
      }

      // Obtener turno activo de caja (asegurándolo si aún no se había inicializado)
      var turnoActivo = ref.read(cajaTurnoActivaProvider).value;
      if (turnoActivo == null) {
        final repo = ref.read(cajaRepositoryProvider);
        turnoActivo = await repo.asegurarTurnoActivo(tenantId: tenantId);
      }

      // 1. Construir cabecera de Venta
      final venta = Venta(
        tenantId: tenantId,
        clienteId: _clienteSeleccionado?.id,
        cajaTurnoId: turnoActivo.id,
        totalVenta: widget.totalAPagar,
        metodoPago: metodoBD,
        montoRecibido: montoRecibidoVenta,
        cambioEntregado: vueltoVenta,
        fechaVenta: DateTime.now(),
      );

      // 2. Construir detalles de venta con costo congelado y descuento real de inventario
      final detalles = itemsCarrito.map((item) {
        final cantInventario = item.descuentoInventario;
        final precioUnitarioEfectivo = cantInventario > 0
            ? ((item.subtotal / cantInventario) * 100).round() / 100.0
            : item.producto.precioVenta;
        return DetalleVenta(
          productoId: item.producto.id,
          cantidad: cantInventario,
          precioUnitario: precioUnitarioEfectivo,
          costoUnitario: item.producto.costoMayorista,
          subtotal: item.subtotal,
        );
      }).toList();

      // 3. Construir desglose de pago (Soporte exacto para pagos divididos en pagos_ventas)
      final List<PagoVenta> pagos;
      if (_metodo == MetodoPagoCobro.mixto) {
        final efectivoCobrado = double.tryParse(_montoEfectivoMixtoController.text.trim()) ?? 0.0;
        final saldoQrCobrado = ((widget.totalAPagar - efectivoCobrado) * 100).round() / 100.0;
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
        pagos = [
          PagoVenta(
            tenantId: tenantId,
            metodo: _metodo == MetodoPagoCobro.fiado
                ? 'FIADO'
                : (_metodo == MetodoPagoCobro.qr ? 'QR' : 'EFECTIVO'),
            monto: widget.totalAPagar,
            createdAt: DateTime.now(),
          ),
        ];
      }

      // 4. Guardar en Supabase y descontar stock (y actualizar saldo de cliente automáticamente vía trigger)
      await ref.read(ventaRepositoryProvider).registrarTransaccionCompleta(
            venta: venta,
            detalles: detalles,
            pagos: pagos,
          );

      // Refrescar proveedores de inventario, clientes, caja y kardex
      ref.read(carritoProvider.notifier).limpiarCarrito();
      ref.read(efectivoRecibidoProvider.notifier).corregir();
      ref.invalidate(productosListProvider);
      ref.invalidate(clientesListProvider);
      ref.invalidate(resumenCajaTurnoProvider);
      ref.invalidate(kardexListProvider);
      ref.invalidate(historialMovimientosProvider);

      if (!mounted) return;

      AppHaptics.medium();

      // 5. Diálogo de éxito visual adaptado al método de pago
      await _mostrarDialogoExito(vueltoVenta, efectivoRecibido);
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
              size: 36,
            ),
            const SizedBox(width: 10),
            Text(
              _metodo == MetodoPagoCobro.fiado ? '¡Fiado Registrado!' : '¡Venta Exitosa!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total cuenta: Bs. ${widget.totalAPagar.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            if (_metodo == MetodoPagoCobro.efectivo) ...[
              Text('Recibido: Bs. ${efectivoRecibido.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20)),
              const Divider(height: 24, thickness: 1.5),
              Text(
                'VUELTO: Bs. ${vuelto.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.success,
                ),
              ),
            ] else if (_metodo == MetodoPagoCobro.qr) ...[
              const Text('Método: Pago QR / Transferencia',
                  style: TextStyle(fontSize: 18, color: AppColors.secondary, fontWeight: FontWeight.bold)),
            ] else if (_metodo == MetodoPagoCobro.mixto) ...[
              const Text('Método: Pago Mixto (Efectivo + QR)',
                  style: TextStyle(fontSize: 18, color: AppColors.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('• En Efectivo: Bs. ${(double.tryParse(_montoEfectivoMixtoController.text) ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16)),
              Text('• Por QR: Bs. ${(widget.totalAPagar - (double.tryParse(_montoEfectivoMixtoController.text) ?? 0)).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, color: AppColors.secondary, fontWeight: FontWeight.bold)),
              if (vuelto > 0) ...[
                const Divider(height: 20, thickness: 1.5),
                Text(
                  'VUELTO EN EFECTIVO: Bs. ${vuelto.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.success,
                  ),
                ),
              ],
            ] else ...[
              Text('Vecino: ${_clienteSeleccionado!.nombre}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Nuevo Saldo Deudor: Bs. ${(_clienteSeleccionado!.saldoActual + widget.totalAPagar).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.pop(context);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text(
                'NUEVA VENTA',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final efectivoRecibido = ref.watch(efectivoRecibidoProvider);
    final diferencia = efectivoRecibido - widget.totalAPagar;
    final bool saldoSuficienteEfectivo = diferencia >= -0.001;
    final clientes = ref.watch(clientesListProvider).maybeWhen(
          data: (l) => l,
          orElse: () => <Cliente>[],
        );

    final double montoEfectivoMixto = double.tryParse(_montoEfectivoMixtoController.text.trim()) ?? 0.0;
    final double saldoQrMixto = widget.totalAPagar - montoEfectivoMixto;
    final double billeteEntregadoMixto = double.tryParse(_billeteEntregadoMixtoController.text.trim()) ?? montoEfectivoMixto;
    final bool saldoSuficienteMixto = montoEfectivoMixto > 0 &&
        montoEfectivoMixto < widget.totalAPagar &&
        saldoQrMixto > 0 &&
        billeteEntregadoMixto >= montoEfectivoMixto;

    final bool saldoFiadoPermitido = _clienteSeleccionado != null &&
        ((_clienteSeleccionado!.saldoActual + widget.totalAPagar) <= _clienteSeleccionado!.limiteCredito);

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
            // 1. Selector Superior de Método de Pago Masivo (4 opciones)
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
                  ? _buildVistaEfectivo(efectivoRecibido, diferencia, saldoSuficienteEfectivo, esOscuro)
                  : (_metodo == MetodoPagoCobro.qr
                      ? _buildVistaQR(esOscuro)
                      : (_metodo == MetodoPagoCobro.mixto
                          ? _buildVistaMixto(esOscuro)
                          : _buildVistaFiado(clientes, esOscuro))),
            ),
          ],
        ),
      ),

      // Botón Confirmar Venta anclado en la base
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
                : Text(
                    _metodo == MetodoPagoCobro.fiado
                        ? 'CONFIRMAR FIADO (Bs. ${widget.totalAPagar.toStringAsFixed(2)})'
                        : 'CONFIRMAR VENTA (Bs. ${widget.totalAPagar.toStringAsFixed(2)})',
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
    final double total = widget.totalAPagar;
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
                Text('TOTAL DE LA CUENTA:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textSecondary)),
                Text('Bs. ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.retailBlue)),
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
                    hintText: 'Ej. 20.00',
                    prefixText: 'Bs. ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),

                // Atajos rápidos de importe
                Row(
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
                    const SizedBox(width: 6),
                    if (total > 10)
                      ActionChip(
                        label: const Text('Bs. 10', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          _montoEfectivoMixtoController.text = '10.00';
                          setState(() {});
                        },
                      ),
                    const SizedBox(width: 6),
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
                        Text('Bs. ${vuelto.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.retailGreen)),
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
                      Text(
                        'Bs. ${saldoQr.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.retailBlue),
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
  Widget _buildVistaEfectivo(double recibido, double diferencia, bool saldoSuficiente, bool esOscuro) {
    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          color: saldoSuficiente
              ? (esOscuro ? const Color(0xFF16A34A).withAlpha(30) : const Color(0xFFDCFCE7))
              : (esOscuro ? const Color(0xFFDC2626).withAlpha(30) : const Color(0xFFFEE2E2)),
          child: Column(
            children: [
              Text(
                'TOTAL DE LA CUENTA: Bs. ${widget.totalAPagar.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'Recibido: Bs. ${recibido.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 6),
              if (!saldoSuficiente)
                Text(
                  'FALTAN: Bs. ${(-diferencia).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.danger),
                )
              else
                Text(
                  'VUELTO: Bs. ${diferencia.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.retailGreen),
                ),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: cardBorder),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.retailBlue, width: 1.6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: cardBg,
                    ),
                    onPressed: () {
                      ref.read(efectivoRecibidoProvider.notifier).fijarMontoExacto(widget.totalAPagar);
                    },
                    icon: const Icon(Icons.flash_on, color: AppColors.retailBlue, size: 24),
                    label: Text(
                      'PAGO EXACTO (Bs. ${widget.totalAPagar.toStringAsFixed(2)})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.retailBlue),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      const _BotonBillete(monto: 10),
                      const _BotonBillete(monto: 20),
                      const _BotonBillete(monto: 50),
                      const _BotonBillete(monto: 100),
                      const _BotonBillete(monto: 200),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          ref.read(efectivoRecibidoProvider.notifier).corregir();
                        },
                        icon: const Icon(Icons.backspace, color: Colors.white, size: 22),
                        label: const Text('BORRAR',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Vista QR ---
  Widget _buildVistaQR(bool esOscuro) {
    final cardBg = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;

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
              Text(
                'Bs. ${widget.totalAPagar.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: AppColors.retailGreen,
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

  // --- Vista Fiado / Crédito ---
  Widget _buildVistaFiado(List<Cliente> clientes, bool esOscuro) {
    final cliente = _clienteSeleccionado;
    final saldoActual = cliente?.saldoActual ?? 0.0;
    final limite = cliente?.limiteCredito ?? 100.0;
    final totalProyectado = saldoActual + widget.totalAPagar;
    final bool excedeLimite = totalProyectado > limite;

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

          const SizedBox(height: 16),

          // 2. Tarjeta de Validación de Límite de Crédito
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
                      Text(
                        excedeLimite ? 'LÍMITE DE CRÉDITO SUPERADO' : 'CRÉDITO AUTORIZADO',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: excedeLimite ? AppColors.danger : AppColors.retailGreen,
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 18, color: cardBorder),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Deuda anterior:', style: TextStyle(fontSize: 14, color: textSecondary)),
                      Text('Bs. ${saldoActual.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Esta compra:', style: TextStyle(fontSize: 14, color: textSecondary)),
                      Text('+Bs. ${widget.totalAPagar.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                    ],
                  ),
                  Divider(height: 14, color: cardBorder),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Deuda Total Resultante:',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                      Text(
                        'Bs. ${totalProyectado.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: excedeLimite ? AppColors.danger : AppColors.retailBlue,
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
                        '⚠️ Esta compra sobrepasa su límite de Bs. ${limite.toStringAsFixed(2)} en Bs. ${(totalProyectado - limite).toStringAsFixed(2)}. Puedes aumentarle el límite o cobrar en otro método.',
                        style: const TextStyle(fontSize: 13, color: AppColors.danger, fontWeight: FontWeight.w600),
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

class _BotonBillete extends ConsumerWidget {
  final double monto;

  const _BotonBillete({required this.monto});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esOscuro = ref.watch(esModoOscuroProvider);
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: esOscuro ? AppColors.darkSurface : AppColors.surface,
        foregroundColor: esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary,
        elevation: 0,
        side: BorderSide(
          color: esOscuro ? AppColors.darkBorder : AppColors.border,
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        ref.read(efectivoRecibidoProvider.notifier).sumar(monto);
      },
      child: Text(
        '+Bs. ${monto.toInt()}',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.retailBlue),
      ),
    );
  }
}
