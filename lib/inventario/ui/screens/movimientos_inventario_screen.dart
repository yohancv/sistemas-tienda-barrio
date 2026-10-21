import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../data/models/producto_model.dart';
import '../../state/providers/inventario_providers.dart';
import '../../state/providers/movimientos_providers.dart';

/// Pantalla dedicada al registro ágil de Mermas, Bajas y Pérdidas de Inventario:
/// - Roturas de botellas / latas
/// - Productos caducados o vencidos
/// - Deterioro de empaque
/// - Consumo propio / familia
///
/// El stock se descuenta en unidades reales y la pérdida financiera se audita en el Kardex.
class MovimientosInventarioScreen extends ConsumerStatefulWidget {
  const MovimientosInventarioScreen({super.key});

  @override
  ConsumerState<MovimientosInventarioScreen> createState() =>
      _MovimientosInventarioScreenState();
}

class _MovimientosInventarioScreenState
    extends ConsumerState<MovimientosInventarioScreen> {
  Producto? _productoMerma;
  double _cantidadMerma = 1.0;
  bool _esMermaPorEmpaque = false;
  String _tipoMerma = 'MERMA_ROTURA';
  final TextEditingController _motivoMermaController = TextEditingController();

  @override
  void dispose() {
    _motivoMermaController.dispose();
    super.dispose();
  }

  double get _unidadesRealesMerma {
    if (_productoMerma == null) return 0.0;
    if (_esMermaPorEmpaque && _productoMerma!.tieneEmpaqueMayorista) {
      return _cantidadMerma * _productoMerma!.unidadesPorEmpaque;
    }
    return _cantidadMerma;
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosListProvider);
    final operacionState = ref.watch(movimientosNotifierProvider);

    final esOscuro = ref.watch(esModoOscuroProvider);
    final bgColor = esOscuro ? AppColors.darkBackground : AppColors.background;
    final surfaceColor = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Mermas y Bajas',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: cardBorder, height: 1.0),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history, size: 24, color: textPrimary),
            tooltip: 'Historial de mermas y auditoría',
            onPressed: () => _mostrarHistorial(context),
          ),
        ],
      ),
      body: productosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
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

                  // Tarjeta explicativa de inicio
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.danger.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.remove_circle_outline_rounded,
                            color: AppColors.danger,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Registra pérdidas por roturas, productos vencidos o consumo personal. El sistema ajustará el stock e incluirá la pérdida en el Kardex.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sección principal de Merma
                  _buildSeccionMerma(productos, operacionState),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // SECCIÓN PRINCIPAL: REGISTRO DE MERMAS Y ROTURAS
  // =========================================================================

  Widget _buildSeccionMerma(
    List<Producto> productos,
    MovimientoOperacionState operacionState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Paso 1: Elegir producto roto o vencido
        const Text(
          '1. SELECCIONA EL PRODUCTO DAÑADO O VENCIDO:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _productoMerma != null ? AppColors.danger.withAlpha(120) : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_productoMerma == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Ningún producto seleccionado aún.',
                    style: TextStyle(fontSize: 15, color: AppColors.textMuted),
                  ),
                )
              else
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        Producto.emojiCategoria(_productoMerma!.categoria),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _productoMerma!.nombre,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Stock actual: ${_productoMerma!.stockLegibleDesglosado}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Costo: Bs. ${_productoMerma!.costoMayorista.toStringAsFixed(2)} / unidad',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
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
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _productoMerma == null ? AppColors.primary : AppColors.danger,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _mostrarDialogoSeleccionarMerma(productos),
                  icon: Icon(
                    Icons.search,
                    color: _productoMerma == null ? AppColors.primary : AppColors.danger,
                    size: 20,
                  ),
                  label: Text(
                    _productoMerma == null
                        ? 'Buscar y elegir producto'
                        : 'Cambiar de producto',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _productoMerma == null ? AppColors.primary : AppColors.danger,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        if (_productoMerma != null) ...[
          // Selector de modalidad si el producto tiene empaque (Caja vs Unidad)
          if (_productoMerma!.tieneEmpaqueMayorista) ...[
            const Text(
              'PRESENTACIÓN DE LA MERMA:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _esMermaPorEmpaque = false;
                          _cantidadMerma = 1.0;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_esMermaPorEmpaque ? AppColors.danger : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '🥤 Unidades Sueltas',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: !_esMermaPorEmpaque ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _esMermaPorEmpaque = true;
                          _cantidadMerma = 1.0;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _esMermaPorEmpaque ? AppColors.danger : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '📦 ${_productoMerma!.nombreEmpaqueLegible} Completo (x${_productoMerma!.unidadesPorEmpaque.toInt()}u)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _esMermaPorEmpaque ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Paso 2: Cantidad dañada
          Text(
            _esMermaPorEmpaque
                ? '2. CANTIDAD DE ${_productoMerma!.nombreEmpaquePlural.toUpperCase()} A DAR DE BAJA:'
                : '2. CANTIDAD DE UNIDADES A DAR DE BAJA:',
            style: const TextStyle(
              fontSize: 13,
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
                  width: 52,
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: AppColors.border, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _cantidadMerma > 1
                        ? () => setState(() => _cantidadMerma--)
                        : null,
                    child: const Icon(Icons.remove, size: 24),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _cantidadMerma.toStringAsFixed(
                          (!_esMermaPorEmpaque && _productoMerma!.esFraccionable) ? 2 : 0),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _esMermaPorEmpaque
                          ? '${_unidadesRealesMerma.toInt()} unidades en total'
                          : (_productoMerma!.esFraccionable ? _productoMerma!.unidadMedida : 'unidades sueltas'),
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: (_unidadesRealesMerma + (_esMermaPorEmpaque ? _productoMerma!.unidadesPorEmpaque : 1.0)) <=
                            _productoMerma!.stockActual
                        ? () => setState(() => _cantidadMerma++)
                        : null,
                    child: const Icon(Icons.add, size: 24, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Paso 3: Motivo de la merma
          const Text(
            '3. MOTIVO DE LA BAJA:',
            style: TextStyle(
              fontSize: 13,
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
              _buildChipMotivo('💥 Rotura', 'MERMA_ROTURA'),
              _buildChipMotivo('⏳ Vencido', 'MERMA_VENCIMIENTO'),
              _buildChipMotivo('📦 Deterioro', 'MERMA_DETERIORO'),
              _buildChipMotivo('🏠 Consumo Propio', 'AJUSTE_NEGATIVO'),
            ],
          ),

          const SizedBox(height: 14),

          // Observación opcional
          TextField(
            controller: _motivoMermaController,
            decoration: InputDecoration(
              hintText: 'Detalle o nota opcional (ej. se cayó al acomodar la vitrina)',
              prefixIcon: const Icon(Icons.edit_note, size: 20),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Paso 4: Pérdida financiera calculada
          _buildTarjetaPerdidaFinanciera(),

          const SizedBox(height: 20),

          // Paso 5: Botón de Confirmación
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _productoMerma!.stockActual >= _unidadesRealesMerma
                    ? AppColors.danger
                    : AppColors.surfaceMuted,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: (_productoMerma!.stockActual >= _unidadesRealesMerma &&
                      !operacionState.isLoading)
                  ? _confirmarMerma
                  : null,
              icon: operacionState.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Icon(Icons.delete_outline, size: 24, color: Colors.white),
              label: Text(
                operacionState.isLoading
                    ? 'Procesando baja...'
                    : 'Confirmar Baja (-${_unidadesRealesMerma.toInt()} uds)',
                style: const TextStyle(
                  fontSize: 16,
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
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: seleccionado ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: seleccionado,
      selectedColor: AppColors.danger,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: seleccionado ? AppColors.danger : AppColors.border,
          width: 1.2,
        ),
      ),
      onSelected: (val) {
        if (val) setState(() => _tipoMerma = valor);
      },
    );
  }

  Widget _buildTarjetaPerdidaFinanciera() {
    final costoUnitario = _productoMerma!.costoMayorista;
    final totalPerdida = _unidadesRealesMerma * costoUnitario;
    final stockRestante = _productoMerma!.stockActual - _unidadesRealesMerma;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withAlpha(70), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pérdida Financiera:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                'Bs. ${totalPerdida.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
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
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                '${stockRestante.toStringAsFixed(_productoMerma!.esFraccionable ? 2 : 0)} uds',
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
    final detalle = _motivoMermaController.text.trim();
    final motivoFinal = detalle.isNotEmpty ? detalle : null;

    final exito = await notifier.registrarMerma(
      producto: _productoMerma!,
      cantidad: _unidadesRealesMerma,
      tipoMerma: _tipoMerma,
      motivo: motivoFinal,
    );

    if (exito && mounted) {
      _motivoMermaController.clear();
      setState(() {
        _productoMerma = null;
        _cantidadMerma = 1.0;
        _esMermaPorEmpaque = false;
      });
    }
  }

  // =========================================================================
  // MODAL DE BÚSQUEDA Y SELECCIÓN DE PRODUCTO CON FILTRO RÁPIDO
  // =========================================================================

  void _mostrarDialogoSeleccionarMerma(List<Producto> productos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtrados = productos.where((p) {
              if (query.isEmpty) return true;
              final n = p.nombre.toLowerCase();
              final c = (p.categoria ?? '').toLowerCase();
              final b = (p.codigoBarras ?? '').toLowerCase();
              return n.contains(query) || c.contains(query) || b.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                        'Selecciona el Producto',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Buscador rápido
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, categoría o código...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setModalState(() => query = val.toLowerCase().trim());
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtrados.isEmpty
                        ? const Center(
                            child: Text(
                              'No se encontraron productos',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtrados.length,
                            separatorBuilder: (_, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final p = filtrados[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.danger.withAlpha(20),
                                  child: Text(
                                    Producto.emojiCategoria(p.categoria),
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                                title: Text(
                                  p.nombre,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Stock: ${p.stockLegibleDesglosado}  •  Costo: Bs. ${p.costoMayorista.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () {
                                  setState(() {
                                    _productoMerma = p;
                                    _cantidadMerma = 1.0;
                                    _esMermaPorEmpaque = false;
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
      },
    );
  }

  // =========================================================================
  // HISTORIAL DE AUDITORÍA
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
                        '📜 Historial de Auditoría',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (movimientos) {
                        if (movimientos.isEmpty) {
                          return const Center(
                            child: Text(
                              'Aún no hay movimientos registrados.',
                              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
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
                              contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                              leading: CircleAvatar(
                                backgroundColor: esMerma
                                    ? AppColors.danger.withAlpha(20)
                                    : AppColors.primary.withAlpha(20),
                                child: Icon(
                                  esMerma ? Icons.warning_rounded : Icons.sync_alt,
                                  color: esMerma ? AppColors.danger : AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                m.etiquetaTipo,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                '${m.createdAt.day}/${m.createdAt.month} ${m.createdAt.hour}:${m.createdAt.minute.toString().padLeft(2, '0')} • ${m.motivo ?? 'Sin observación'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${m.esEntrada ? '+' : '-'}${m.cantidad.toInt()} uds',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: m.esEntrada ? AppColors.success : AppColors.danger,
                                    ),
                                  ),
                                  if (m.costoTotal > 0)
                                    Text(
                                      'Bs. ${m.costoTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 11,
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

  Widget _buildAlertaMensaje({required String mensaje, required bool esError}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: esError ? AppColors.danger.withAlpha(15) : AppColors.success.withAlpha(15),
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
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(
                fontSize: 14,
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
