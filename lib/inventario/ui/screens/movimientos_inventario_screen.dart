import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../data/models/producto_model.dart';
import '../../state/providers/inventario_providers.dart';
import '../../state/providers/movimientos_providers.dart';

enum ModoMovimiento { desempaque, merma }

class MovimientosInventarioScreen extends ConsumerStatefulWidget {
  const MovimientosInventarioScreen({super.key});

  @override
  ConsumerState<MovimientosInventarioScreen> createState() =>
      _MovimientosInventarioScreenState();
}

class _MovimientosInventarioScreenState
    extends ConsumerState<MovimientosInventarioScreen> {
  ModoMovimiento _modo = ModoMovimiento.desempaque;

  // Estado para Desempaque
  Producto? _cajaSeleccionada;
  Producto? _destinoSeleccionado;
  double _cantidadCajas = 1.0;

  // Estado para Mermas
  Producto? _productoMerma;
  double _cantidadMerma = 1.0;
  String _tipoMerma = 'MERMA_ROTURA';
  final TextEditingController _motivoMermaController = TextEditingController();

  @override
  void dispose() {
    _motivoMermaController.dispose();
    super.dispose();
  }

  void _seleccionarCaja(Producto caja, List<Producto> todosLosProductos) {
    setState(() {
      _cajaSeleccionada = caja;
      _cantidadCajas = 1.0;

      // Buscar si tiene producto hijo pre-vinculado
      if (caja.productoHijoId != null) {
        _destinoSeleccionado = todosLosProductos.cast<Producto?>().firstWhere(
              (p) => p?.id == caja.productoHijoId,
              orElse: () => null,
            );
      } else {
        // Sugerir producto con nombre similar o dejar nulo para que elija
        _destinoSeleccionado = todosLosProductos.cast<Producto?>().firstWhere(
              (p) =>
                  p?.id != caja.id &&
                  p?.nombre.toLowerCase().contains(caja.nombre
                          .toLowerCase()
                          .replaceAll('caja', '')
                          .replaceAll('pack', '')
                          .trim()) ==
                      true,
              orElse: () => null,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosListProvider);
    final operacionState = ref.watch(movimientosNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Movimientos de Inventario',
          style: AppTypography.headlineSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, size: 28, color: Colors.white),
            tooltip: 'Historial de auditoría',
            onPressed: () => _mostrarHistorial(context),
          ),
        ],
      ),
      body: productosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Error al cargar catálogo: $err',
              style: const TextStyle(color: AppColors.danger, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (productos) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner de mensajes de estado de operación
                  if (operacionState.errorMessage != null)
                    _buildAlertaMensaje(
                      mensaje: operacionState.errorMessage!,
                      esError: true,
                    ),
                  if (operacionState.successMessage != null)
                    _buildAlertaMensaje(
                      mensaje: operacionState.successMessage!,
                      esError: false,
                    ),

                  // 1. Selector Superior Masivo de Modo (56dp)
                  _buildSelectorModoMasivo(),

                  const SizedBox(height: 20),

                  // 2. Contenido según el modo activo
                  if (_modo == ModoMovimiento.desempaque)
                    _buildSeccionDesempaque(productos)
                  else
                    _buildSeccionMerma(productos),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Selector de modo accesible estilo interruptor grande
  Widget _buildSelectorModoMasivo() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _modo == ModoMovimiento.desempaque
                      ? AppColors.primary
                      : Colors.transparent,
                  elevation: _modo == ModoMovimiento.desempaque ? 2 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  ref.read(movimientosNotifierProvider.notifier).limpiarMensajes();
                  setState(() => _modo = ModoMovimiento.desempaque);
                },
                icon: Icon(
                  Icons.unarchive,
                  size: 24,
                  color: _modo == ModoMovimiento.desempaque
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
                label: Text(
                  'Desempaque',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _modo == ModoMovimiento.desempaque
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _modo == ModoMovimiento.merma
                      ? AppColors.danger
                      : Colors.transparent,
                  elevation: _modo == ModoMovimiento.merma ? 2 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  ref.read(movimientosNotifierProvider.notifier).limpiarMensajes();
                  setState(() => _modo = ModoMovimiento.merma);
                },
                icon: Icon(
                  Icons.delete_sweep_outlined,
                  size: 24,
                  color: _modo == ModoMovimiento.merma
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
                label: Text(
                  'Roturas / Mermas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _modo == ModoMovimiento.merma
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECCIÓN 1: DESEMPAQUE DE CAJAS
  // =========================================================================

  Widget _buildSeccionDesempaque(List<Producto> productos) {
    final operacionState = ref.watch(movimientosNotifierProvider);
    final cajas = productos
        .where((p) =>
            p.tieneEmpaqueMayorista ||
            p.tipoEmpaque != 'UNIDAD' ||
            p.unidadesPorEmpaque > 1)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Paso 1: Elegir caja origen
        const Text(
          '1. SELECCIONA LA CAJA O PAQUETE A ABRIR:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_cajaSeleccionada == null)
                const Text(
                  'Ninguna caja seleccionada aún',
                  style: TextStyle(fontSize: 16, color: AppColors.textMuted),
                )
              else ...[
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.inventory_2,
                          color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _cajaSeleccionada!.nombre,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Stock disponible: ${_cajaSeleccionada!.stockActual.toInt()} cajas • ${_cajaSeleccionada!.etiquetaEmpaque}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _mostrarDialogoSeleccionarCaja(cajas, productos),
                  icon: const Icon(Icons.search, color: AppColors.primary),
                  label: Text(
                    _cajaSeleccionada == null
                        ? 'Buscar y elegir caja'
                        : 'Cambiar caja seleccionada',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Paso 2: Producto destino que recibe las botellas
        if (_cajaSeleccionada != null) ...[
          const Text(
            '2. PRODUCTO DESTINO (UNIDADES SUELTAS):',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _destinoSeleccionado == null
                    ? AppColors.warning
                    : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_destinoSeleccionado == null)
                  const Text(
                    '⚠️ Selecciona la botella o unidad suelta que recibirá el stock',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  )
                else
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.local_drink,
                            color: AppColors.secondary, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _destinoSeleccionado!.nombre,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Stock actual: ${_destinoSeleccionado!.stockActual.toInt()} unidades sueltas',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _mostrarDialogoSeleccionarDestino(productos),
                  icon: const Icon(Icons.swap_horiz, size: 22),
                  label: Text(
                    _destinoSeleccionado == null
                        ? 'Elegir unidad destino'
                        : 'Cambiar unidad destino',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Paso 3: Cantidad de Cajas a abrir
          const Text(
            '3. ¿CUÁNTAS CAJAS DESEAS ABRIR?:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: AppColors.borderStrong, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _cantidadCajas > 1
                        ? () => setState(() => _cantidadCajas--)
                        : null,
                    child: const Icon(Icons.remove, size: 28),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${_cantidadCajas.toInt()}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _cantidadCajas == 1 ? 'Caja' : 'Cajas',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _cantidadCajas < _cajaSeleccionada!.stockActual
                        ? () => setState(() => _cantidadCajas++)
                        : null,
                    child: const Icon(Icons.add, size: 28, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Paso 4: Tarjeta de Simulación Antes vs Después
          if (_destinoSeleccionado != null) ...[
            _buildTarjetaSimulacionDesempaque(),
            const SizedBox(height: 20),
          ],

          // Paso 5: Botón de Confirmación Masivo (60dp)
          SizedBox(
            height: 60,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: (_destinoSeleccionado != null &&
                        _cajaSeleccionada!.stockActual >= _cantidadCajas)
                    ? AppColors.primary
                    : AppColors.surfaceMuted,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: (_destinoSeleccionado != null &&
                      _cajaSeleccionada!.stockActual >= _cantidadCajas &&
                      !operacionState.isLoading)
                  ? _confirmarDesempaque
                  : null,
              icon: operacionState.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Icon(Icons.check_circle_outline,
                      size: 28, color: Colors.white),
              label: Text(
                operacionState.isLoading
                    ? 'Procesando desempaque...'
                    : 'Confirmar Desempaque (${_cantidadCajas.toInt()} Caja${_cantidadCajas > 1 ? 's' : ''})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Tarjeta de previsualización que muestra exactamente cómo cambiará el stock
  Widget _buildTarjetaSimulacionDesempaque() {
    final unidadesPorCaja = _cajaSeleccionada!.unidadesPorEmpaque > 0
        ? _cajaSeleccionada!.unidadesPorEmpaque
        : 1.0;
    final totalUnidadesSumar = _cantidadCajas * unidadesPorCaja;

    final stockCajaAntes = _cajaSeleccionada!.stockActual.toInt();
    final stockCajaDespues = stockCajaAntes - _cantidadCajas.toInt();

    final stockUnidadesAntes = _destinoSeleccionado!.stockActual.toInt();
    final stockUnidadesDespues = stockUnidadesAntes + totalUnidadesSumar.toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withAlpha(80), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔄 VISTA PREVIA DEL CAMBIO DE INVENTARIO:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📦 ${_cajaSeleccionada!.nombre}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$stockCajaAntes  ➔  $stockCajaDespues cajas (-${_cantidadCajas.toInt()})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: AppColors.primary),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '🍺 ${_destinoSeleccionado!.nombre}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$stockUnidadesAntes  ➔  $stockUnidadesDespues uds (+${totalUnidadesSumar.toInt()})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmarDesempaque() async {
    final notifier = ref.read(movimientosNotifierProvider.notifier);
    final exito = await notifier.desempaquetar(
      caja: _cajaSeleccionada!,
      unidadesDestino: _destinoSeleccionado!,
      cantidadCajas: _cantidadCajas,
    );

    if (exito && mounted) {
      setState(() {
        _cajaSeleccionada = null;
        _destinoSeleccionado = null;
        _cantidadCajas = 1.0;
      });
    }
  }

  // =========================================================================
  // SECCIÓN 2: REGISTRO DE MERMAS Y ROTURAS
  // =========================================================================

  Widget _buildSeccionMerma(List<Producto> productos) {
    final operacionState = ref.watch(movimientosNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Paso 1: Elegir producto roto o vencido
        const Text(
          '1. SELECCIONA EL PRODUCTO CON ROTURA O MERMA:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_productoMerma == null)
                const Text(
                  'Ningún producto seleccionado aún',
                  style: TextStyle(fontSize: 16, color: AppColors.textMuted),
                )
              else
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.broken_image,
                          color: AppColors.danger, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _productoMerma!.nombre,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Stock: ${_productoMerma!.stockActual.toStringAsFixed(_productoMerma!.esFraccionable ? 2 : 0)} • Costo: Bs. ${_productoMerma!.costoMayorista.toStringAsFixed(2)} c/u',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _mostrarDialogoSeleccionarMerma(productos),
                  icon: const Icon(Icons.search, color: AppColors.danger),
                  label: Text(
                    _productoMerma == null
                        ? 'Buscar y elegir producto'
                        : 'Cambiar producto',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (_productoMerma != null) ...[
          // Paso 2: Cantidad dañada
          const Text(
            '2. CANTIDAD DAÑADA / ROTA:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: AppColors.borderStrong, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _cantidadMerma > 1
                        ? () => setState(() => _cantidadMerma--)
                        : null,
                    child: const Icon(Icons.remove, size: 28),
                  ),
                ),
                Text(
                  _cantidadMerma.toStringAsFixed(
                      _productoMerma!.esFraccionable ? 2 : 0),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _cantidadMerma < _productoMerma!.stockActual
                        ? () => setState(() => _cantidadMerma++)
                        : null,
                    child: const Icon(Icons.add, size: 28, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Paso 3: Motivo de la merma con chips grandes
          const Text(
            '3. MOTIVO DE LA MERMA:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              _buildChipMotivo('💥 Rotura', 'MERMA_ROTURA'),
              const SizedBox(width: 8),
              _buildChipMotivo('⏳ Vencido', 'MERMA_VENCIMIENTO'),
              const SizedBox(width: 8),
              _buildChipMotivo('📦 Deterioro', 'MERMA_DETERIORO'),
            ],
          ),

          const SizedBox(height: 16),

          // Paso 4: Pérdida financiera estimada
          _buildTarjetaPerdidaFinanciera(),

          const SizedBox(height: 20),

          // Paso 5: Botón de Confirmación Masivo (60dp)
          SizedBox(
            height: 60,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _productoMerma!.stockActual >= _cantidadMerma
                    ? AppColors.danger
                    : AppColors.surfaceMuted,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: (_productoMerma!.stockActual >= _cantidadMerma &&
                      !operacionState.isLoading)
                  ? _confirmarMerma
                  : null,
              icon: operacionState.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Icon(Icons.delete_forever, size: 28, color: Colors.white),
              label: Text(
                operacionState.isLoading
                    ? 'Registrando merma...'
                    : 'Dar de Baja Merma (-${_cantidadMerma.toInt()})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChipMotivo(String label, String valor) {
    final seleccionado = _tipoMerma == valor;
    return Expanded(
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor:
                seleccionado ? AppColors.danger : AppColors.surfaceMuted,
            elevation: seleccionado ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: seleccionado ? AppColors.danger : AppColors.border,
                width: seleccionado ? 2 : 1,
              ),
            ),
          ),
          onPressed: () => setState(() => _tipoMerma = valor),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: seleccionado ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTarjetaPerdidaFinanciera() {
    final costoUnitario = _productoMerma!.costoMayorista;
    final totalPerdida = _cantidadMerma * costoUnitario;
    final stockRestante = _productoMerma!.stockActual - _cantidadMerma;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withAlpha(80), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pérdida Financiera:',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              Text(
                'Bs. ${totalPerdida.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Stock posterior:',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              Text(
                '${stockRestante.toStringAsFixed(_productoMerma!.esFraccionable ? 2 : 0)} unidades',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmarMerma() async {
    final notifier = ref.read(movimientosNotifierProvider.notifier);
    final exito = await notifier.registrarMerma(
      producto: _productoMerma!,
      cantidad: _cantidadMerma,
      tipoMerma: _tipoMerma,
    );

    if (exito && mounted) {
      setState(() {
        _productoMerma = null;
        _cantidadMerma = 1.0;
      });
    }
  }

  // =========================================================================
  // DIÁLOGOS DE SELECCIÓN TÁCTIL
  // =========================================================================

  void _mostrarDialogoSeleccionarCaja(
      List<Producto> cajas, List<Producto> todosLosProductos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
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
                    'Selecciona una Caja o Paquete',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (cajas.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No hay productos registrados con presentación de caja o mayorista.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: AppColors.textMuted),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: cajas.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final c = cajas[index];
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withAlpha(20),
                          child: const Icon(Icons.inventory_2,
                              color: AppColors.primary),
                        ),
                        title: Text(
                          c.nombre,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Stock: ${c.stockActual.toInt()} cajas • ${c.etiquetaEmpaque}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        onTap: () {
                          _seleccionarCaja(c, todosLosProductos);
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

  void _mostrarDialogoSeleccionarDestino(List<Producto> productos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
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
                    'Selecciona la Botella / Unidad Destino',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: productos.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = productos[index];
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.secondary.withAlpha(20),
                        child: const Icon(Icons.local_drink,
                            color: AppColors.secondary),
                      ),
                      title: Text(
                        p.nombre,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Stock actual: ${p.stockActual.toInt()} unidades',
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () {
                        setState(() => _destinoSeleccionado = p);
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

  void _mostrarDialogoSeleccionarMerma(List<Producto> productos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
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
                    'Selecciona el Producto Roto / Dañado',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: productos.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = productos[index];
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.danger.withAlpha(20),
                        child: const Icon(Icons.broken_image,
                            color: AppColors.danger),
                      ),
                      title: Text(
                        p.nombre,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Stock: ${p.stockActual.toStringAsFixed(p.esFraccionable ? 2 : 0)} • Costo: Bs. ${p.costoMayorista.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () {
                        setState(() {
                          _productoMerma = p;
                          _cantidadMerma = 1.0;
                        });
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

  // =========================================================================
  // HISTORIAL DE AUDITORÍA DE MOVIMIENTOS
  // =========================================================================

  void _mostrarHistorial(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Consumer(
          builder: (context, ref, _) {
            final historialAsync = ref.watch(historialMovimientosProvider);
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
                        '📜 Historial Inmutable de Auditoría',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: historialAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (movimientos) {
                        if (movimientos.isEmpty) {
                          return const Center(
                            child: Text(
                              'Aún no hay movimientos registrados.',
                              style: TextStyle(
                                  fontSize: 16, color: AppColors.textMuted),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: movimientos.length,
                          separatorBuilder: (_, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final m = movimientos[index];
                            final esMerma = m.esMerma;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 2),
                              leading: CircleAvatar(
                                backgroundColor: esMerma
                                    ? AppColors.danger.withAlpha(20)
                                    : AppColors.primary.withAlpha(20),
                                child: Icon(
                                  esMerma ? Icons.warning : Icons.sync_alt,
                                  color: esMerma
                                      ? AppColors.danger
                                      : AppColors.primary,
                                ),
                              ),
                              title: Text(
                                m.etiquetaTipo,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Text(
                                '${m.createdAt.day}/${m.createdAt.month} ${m.createdAt.hour}:${m.createdAt.minute.toString().padLeft(2, '0')} • ${m.motivo ?? ''}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${m.esEntrada ? '+' : '-'}${m.cantidad.toInt()} uds',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: m.esEntrada
                                          ? AppColors.success
                                          : AppColors.danger,
                                    ),
                                  ),
                                  if (m.costoTotal > 0)
                                    Text(
                                      'Bs. ${m.costoTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                ],
                              ),
                            );
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
      },
    );
  }

  Widget _buildAlertaMensaje(
      {required String mensaje, required bool esError}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esError
            ? AppColors.danger.withAlpha(15)
            : AppColors.success.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esError ? AppColors.danger : AppColors.success,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            esError ? Icons.error_outline : Icons.check_circle_outline,
            color: esError ? AppColors.danger : AppColors.success,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: esError ? AppColors.danger : AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
