import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/config/supabase_client.dart';
import '../../../cuentas_por_cobrar/data/models/cliente_model.dart';
import '../../../cuentas_por_cobrar/state/providers/clientes_providers.dart';
import '../../../cuentas_por_cobrar/ui/widgets/modal_nuevo_cliente.dart';
import '../../data/models/venta_models.dart';
import '../../state/providers/carrito_providers.dart';
import '../../state/providers/pago_providers.dart';
import '../../state/providers/venta_providers.dart';
import '../../../inventario/state/providers/inventario_providers.dart';
import '../../../inventario/state/providers/movimientos_providers.dart';
import '../../../cierre_caja/state/providers/caja_providers.dart';

enum MetodoPagoCobro { efectivo, qr, fiado }

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(efectivoRecibidoProvider.notifier).corregir();
    });
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
      } else if (_metodo == MetodoPagoCobro.fiado) {
        metodoBD = 'CREDITO_FIADO';
        montoRecibidoVenta = 0.0;
        vueltoVenta = 0.0;
      }

      // Obtener turno activo de caja si existe
      final turnoActivo = ref.read(cajaTurnoActivaProvider).value;

      // 1. Construir cabecera de Venta
      final venta = Venta(
        tenantId: tenantId,
        clienteId: _clienteSeleccionado?.id,
        cajaTurnoId: turnoActivo?.id,
        totalVenta: widget.totalAPagar,
        metodoPago: metodoBD,
        montoRecibido: montoRecibidoVenta,
        cambioEntregado: vueltoVenta,
        fechaVenta: DateTime.now(),
      );

      // 2. Construir detalles de venta con costo congelado
      final detalles = itemsCarrito.map((item) {
        return DetalleVenta(
          productoId: item.producto.id,
          cantidad: item.cantidad,
          precioUnitario: item.producto.precioVenta,
          costoUnitario: item.producto.costoMayorista,
          subtotal: item.subtotal,
        );
      }).toList();

      // 3. Construir desglose de pago
      final pagos = [
        PagoVenta(
          tenantId: tenantId,
          metodo: _metodo == MetodoPagoCobro.fiado
              ? 'FIADO'
              : (_metodo == MetodoPagoCobro.qr ? 'QR' : 'EFECTIVO'),
          monto: widget.totalAPagar,
          createdAt: DateTime.now(),
        ),
      ];

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

    final bool puedeConfirmar = _metodo == MetodoPagoCobro.efectivo
        ? saldoSuficienteEfectivo
        : (_metodo == MetodoPagoCobro.qr
            ? true
            : (_clienteSeleccionado != null));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cobro en Caja',
          style: AppTypography.headlineSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Selector Superior de Método de Pago Masivo (52dp)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              color: AppColors.surface,
              child: Row(
                children: [
                  _buildBotonMetodo('💵 Efectivo', MetodoPagoCobro.efectivo),
                  const SizedBox(width: 8),
                  _buildBotonMetodo('📱 QR', MetodoPagoCobro.qr),
                  const SizedBox(width: 8),
                  _buildBotonMetodo('📝 Fiado', MetodoPagoCobro.fiado),
                ],
              ),
            ),

            // 2. Contenido según el método de pago seleccionado
            Expanded(
              child: _metodo == MetodoPagoCobro.efectivo
                  ? _buildVistaEfectivo(efectivoRecibido, diferencia, saldoSuficienteEfectivo)
                  : (_metodo == MetodoPagoCobro.qr
                      ? _buildVistaQR()
                      : _buildVistaFiado(clientes)),
            ),
          ],
        ),
      ),

      // Botón Confirmar Venta anclado en la base
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
          height: 64,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: puedeConfirmar ? AppColors.success : Colors.grey.shade400,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: puedeConfirmar ? 4 : 0,
            ),
            onPressed: puedeConfirmar && !_isProcessing ? _confirmarVenta : null,
            child: _isProcessing
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    _metodo == MetodoPagoCobro.fiado
                        ? 'CONFIRMAR FIADO (Bs. ${widget.totalAPagar.toStringAsFixed(2)})'
                        : 'CONFIRMAR VENTA (Bs. ${widget.totalAPagar.toStringAsFixed(2)})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBotonMetodo(String label, MetodoPagoCobro metodo) {
    final seleccionado = _metodo == metodo;
    return Expanded(
      child: SizedBox(
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: seleccionado ? AppColors.primary : AppColors.surfaceMuted,
            elevation: seleccionado ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: seleccionado ? AppColors.primary : AppColors.border,
                width: seleccionado ? 2 : 1,
              ),
            ),
          ),
          onPressed: () => setState(() => _metodo = metodo),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: seleccionado ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // --- Vista Efectivo ---
  Widget _buildVistaEfectivo(double recibido, double diferencia, bool saldoSuficiente) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          color: saldoSuficiente ? AppColors.success.withAlpha(25) : AppColors.danger.withAlpha(25),
          child: Column(
            children: [
              Text(
                'TOTAL DE LA CUENTA: Bs. ${widget.totalAPagar.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'Recibido: Bs. ${recibido.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              if (!saldoSuficiente)
                Text(
                  'FALTAN: Bs. ${(-diferencia).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.danger),
                )
              else
                Text(
                  'VUELTO: Bs. ${diferencia.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: AppColors.success),
                ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 2, color: AppColors.border),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: AppColors.surface,
                    ),
                    onPressed: () {
                      ref.read(efectivoRecibidoProvider.notifier).fijarMontoExacto(widget.totalAPagar);
                    },
                    icon: const Icon(Icons.flash_on, color: AppColors.primary, size: 28),
                    label: Text(
                      'PAGO EXACTO (Bs. ${widget.totalAPagar.toStringAsFixed(2)})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          ref.read(efectivoRecibidoProvider.notifier).corregir();
                        },
                        icon: const Icon(Icons.backspace, color: Colors.white, size: 24),
                        label: const Text('BORRAR',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
  Widget _buildVistaQR() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.secondary.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.qr_code_2, size: 64, color: AppColors.secondary),
            ),
            const SizedBox(height: 20),
            Text(
              'COBRO POR QR',
              style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Muestra el código QR al cliente por el monto exacto:',
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Bs. ${widget.totalAPagar.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: AppColors.secondary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Una vez que el cliente confirme la transferencia en su celular, presiona el botón inferior para cerrar la venta.',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- Vista Fiado / Crédito ---
  Widget _buildVistaFiado(List<Cliente> clientes) {
    final cliente = _clienteSeleccionado;
    final saldoActual = cliente?.saldoActual ?? 0.0;
    final limite = cliente?.limiteCredito ?? 100.0;
    final totalProyectado = saldoActual + widget.totalAPagar;
    final bool excedeLimite = totalProyectado > limite;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Selector de Cliente
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cliente == null ? AppColors.warning : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VECINO / CLIENTE QUE SACA FIADO:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                if (cliente == null)
                  const Text(
                    '⚠️ Aún no has seleccionado ningún cliente',
                    style: TextStyle(fontSize: 16, color: AppColors.warning, fontWeight: FontWeight.bold),
                  )
                else
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person, color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cliente.nombre,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Deuda actual: Bs. ${cliente.saldoActual.toStringAsFixed(2)} • Límite: Bs. ${cliente.limiteCredito.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _mostrarSelectorClientes(clientes),
                        icon: const Icon(Icons.search, color: AppColors.primary),
                        label: Text(
                          cliente == null ? 'Buscar Vecino' : 'Cambiar Vecino',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: AppColors.secondary),
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
                color: excedeLimite ? AppColors.danger.withAlpha(15) : AppColors.success.withAlpha(15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: excedeLimite ? AppColors.danger : AppColors.success,
                  width: 1.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        excedeLimite ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                        color: excedeLimite ? AppColors.danger : AppColors.success,
                        size: 26,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        excedeLimite ? 'LÍMITE DE CRÉDITO SUPERADO' : 'CRÉDITO AUTORIZADO',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: excedeLimite ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Deuda anterior:', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      Text('Bs. ${saldoActual.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Esta compra:', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                      Text('+Bs. ${widget.totalAPagar.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Deuda Total Resultante:',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text(
                        'Bs. ${totalProyectado.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: excedeLimite ? AppColors.danger : AppColors.primary,
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
                        '⚠️ Esta compra sobrepasa su límite de Bs. ${limite.toStringAsFixed(2)} en Bs. ${(totalProyectado - limite).toStringAsFixed(2)}. Puedes confirmar bajo tu propio criterio.',
                        style: const TextStyle(fontSize: 13, color: AppColors.danger, fontWeight: FontWeight.w600),
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
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 2,
        side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        ref.read(efectivoRecibidoProvider.notifier).sumar(monto);
      },
      child: Text(
        '+Bs. ${monto.toInt()}',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
      ),
    );
  }
}
