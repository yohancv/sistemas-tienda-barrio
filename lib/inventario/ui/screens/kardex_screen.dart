import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/models/movimiento_inventario_model.dart';
import '../../state/providers/movimientos_providers.dart';
import '../widgets/modal_registrar_merma.dart';
import 'movimientos_inventario_screen.dart';

class KardexScreen extends ConsumerStatefulWidget {
  final String? productoIdInicial;
  final String? nombreProductoInicial;

  const KardexScreen({
    super.key,
    this.productoIdInicial,
    this.nombreProductoInicial,
  });

  @override
  ConsumerState<KardexScreen> createState() => _KardexScreenState();
}

class _KardexScreenState extends ConsumerState<KardexScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.productoIdInicial != null) {
        ref.read(kardexFiltroProvider.notifier).seleccionarProducto(
              widget.productoIdInicial,
              nombreProducto: widget.nombreProductoInicial,
            );
      } else {
        // Al entrar al Kardex general, asegurarse de limpiar cualquier producto filtrado previamente
        ref.read(kardexFiltroProvider.notifier).limpiarBusquedaYProducto();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirModalMerma() async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ModalRegistrarMerma(),
    );

    if (res == true) {
      ref.invalidate(kardexListProvider);
    }
  }

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final min = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes ${fecha.year} • $hora:$min';
  }

  @override
  Widget build(BuildContext context) {
    final filtro = ref.watch(kardexFiltroProvider);
    final movimientosAsync = ref.watch(kardexListProvider);
    final resumen = ref.watch(resumenKardexProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kardex de Inventario',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined, color: Colors.white),
            tooltip: 'Desempaque de Cajas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MovimientosInventarioScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refrescar Kardex',
            onPressed: () => ref.invalidate(kardexListProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ================================================================
            // 1. Barra de Filtros (Período, Tipos y Búsqueda)
            // ================================================================
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Selector de Período Rápido
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ChipPeriodo(
                          label: 'Hoy',
                          seleccionado: filtro.periodo == PeriodoKardex.hoy,
                          onTap: () => ref
                              .read(kardexFiltroProvider.notifier)
                              .cambiarPeriodo(PeriodoKardex.hoy),
                        ),
                        const SizedBox(width: 8),
                        _ChipPeriodo(
                          label: 'Últimos 7 días',
                          seleccionado:
                              filtro.periodo == PeriodoKardex.ultimos7Dias,
                          onTap: () => ref
                              .read(kardexFiltroProvider.notifier)
                              .cambiarPeriodo(PeriodoKardex.ultimos7Dias),
                        ),
                        const SizedBox(width: 8),
                        _ChipPeriodo(
                          label: 'Este Mes',
                          seleccionado: filtro.periodo == PeriodoKardex.esteMes,
                          onTap: () => ref
                              .read(kardexFiltroProvider.notifier)
                              .cambiarPeriodo(PeriodoKardex.esteMes),
                        ),
                        const SizedBox(width: 8),
                        _ChipPeriodo(
                          label: 'Histórico Completo',
                          seleccionado: filtro.periodo == PeriodoKardex.todos,
                          onTap: () => ref
                              .read(kardexFiltroProvider.notifier)
                              .cambiarPeriodo(PeriodoKardex.todos),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Chips por Tipo de Movimiento
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ChipTipo(
                          label: 'Todos',
                          tipo: 'TODOS',
                          seleccionado: filtro.filtroTipo == 'TODOS',
                          onTap: () => ref
                              .read(kardexFiltroProvider.notifier)
                              .cambiarTipo('TODOS'),
                        ),
                        const SizedBox(width: 6),
                        _ChipTipo(
                          label: '🛒 Ventas',
                          tipo: 'VENTA',
                          seleccionado: filtro.filtroTipo == 'VENTA',
                          onTap: () => ref
                              .read(kardexFiltroProvider.notifier)
                              .cambiarTipo('VENTA'),
                        ),
                        const SizedBox(width: 6),
                        _ChipTipo(
                          label: '💥 Mermas / Bajas',
                          tipo: 'MERMAS',
                          seleccionado: filtro.filtroTipo == 'MERMAS',
                          onTap: () => ref
                              .read(kardexFiltroProvider.notifier)
                              .cambiarTipo('MERMAS'),
                        ),
                        const SizedBox(width: 6),
                        _ChipTipo(
                          label: '📦 Desempaques',
                          tipo: 'DESEMPAQUES',
                          seleccionado: filtro.filtroTipo == 'DESEMPAQUES',
                          onTap: () => ref
                              .read(kardexFiltroProvider.notifier)
                              .cambiarTipo('DESEMPAQUES'),
                        ),
                        const SizedBox(width: 6),
                        _ChipTipo(
                          label: '⚙️ Ajustes',
                          tipo: 'AJUSTES',
                          seleccionado: filtro.filtroTipo == 'AJUSTES',
                          onTap: () => ref
                              .read(kardexFiltroProvider.notifier)
                              .cambiarTipo('AJUSTES'),
                        ),
                        const SizedBox(width: 6),
                        _ChipTipo(
                          label: '🚚 Entradas',
                          tipo: 'ENTRADAS',
                          seleccionado: filtro.filtroTipo == 'ENTRADAS',
                          onTap: () => ref
                              .read(kardexFiltroProvider.notifier)
                              .cambiarTipo('ENTRADAS'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Buscador por texto
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (text) => ref
                              .read(kardexFiltroProvider.notifier)
                              .actualizarBusqueda(text),
                          decoration: InputDecoration(
                            hintText: 'Buscar por producto, motivo o ticket...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref
                                          .read(kardexFiltroProvider.notifier)
                                          .actualizarBusqueda('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      if (filtro.productoId != null) ...[
                        const SizedBox(width: 8),
                        InputChip(
                          avatar: const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.primary),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          backgroundColor: AppColors.primary.withAlpha(20),
                          label: Text(
                            filtro.nombreProducto ?? widget.nombreProductoInicial ?? 'Producto filtrado',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          onDeleted: () {
                            ref
                                .read(kardexFiltroProvider.notifier)
                                .seleccionarProducto(null);
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ================================================================
            // 2. Tarjetas de Resumen Métrico del Período
            // ================================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: AppColors.background,
              child: Row(
                children: [
                  Expanded(
                    child: _MiniCardResumen(
                      titulo: 'Ventas',
                      valor:
                          '${resumen.totalUnidadesVendidas.toStringAsFixed(0)} u.',
                      icono: Icons.shopping_cart_checkout,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniCardResumen(
                      titulo: 'Mermas',
                      valor:
                          '${resumen.totalUnidadesMermas.toStringAsFixed(0)} u.',
                      subvalor:
                          '-Bs. ${resumen.totalCostoPerdidaMermas.toStringAsFixed(2)}',
                      icono: Icons.broken_image,
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniCardResumen(
                      titulo: 'Entradas',
                      valor:
                          '+${resumen.totalUnidadesIngresadas.toStringAsFixed(0)} u.',
                      icono: Icons.move_to_inbox,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ================================================================
            // 3. Lista de Movimientos (Kardex)
            // ================================================================
            Expanded(
              child: movimientosAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.danger),
                        const SizedBox(height: 12),
                        Text(
                          'Error al cargar movimientos: $e',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(kardexListProvider),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (movimientos) {
                  if (movimientos.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text(
                              'No se encontraron movimientos',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ajusta los filtros de fecha o tipo para ver más registros.',
                              style: TextStyle(color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
                    itemCount: movimientos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final m = movimientos[index];
                      return _KardexItemTile(
                        movimiento: m,
                        fechaFormateada: _formatearFecha(m.createdAt),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // Botón Flotante para Registrar Merma Rápida
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.danger,
        elevation: 4,
        onPressed: _abrirModalMerma,
        icon: const Icon(Icons.broken_image, color: Colors.white),
        label: const Text(
          'REGISTRAR MERMA',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET: Fila individual del Kardex
// ============================================================================
class _KardexItemTile extends StatelessWidget {
  final MovimientoInventario movimiento;
  final String fechaFormateada;

  const _KardexItemTile({
    required this.movimiento,
    required this.fechaFormateada,
  });

  Color _obtenerColor(MovimientoInventario m) {
    if (m.esVenta) return AppColors.primary;
    if (m.esMerma) return AppColors.danger;
    if (m.esDesempaque) return Colors.amber[800]!;
    if (m.esEntrada) return AppColors.success;
    return Colors.purple[700]!;
  }

  IconData _obtenerIcono(MovimientoInventario m) {
    if (m.esVenta) return Icons.shopping_cart;
    if (m.tipoMovimiento == 'MERMA_ROTURA') return Icons.broken_image;
    if (m.tipoMovimiento == 'MERMA_VENCIMIENTO') return Icons.timer_off;
    if (m.tipoMovimiento == 'MERMA_DETERIORO') return Icons.inventory_2;
    if (m.tipoMovimiento == 'DESEMPAQUE_SALIDA') return Icons.outbox;
    if (m.tipoMovimiento == 'DESEMPAQUE_ENTRADA') return Icons.move_to_inbox;
    if (m.esAjuste) return Icons.tune;
    return Icons.swap_horiz;
  }

  @override
  Widget build(BuildContext context) {
    final color = _obtenerColor(movimiento);
    final icon = _obtenerIcono(movimiento);
    final bool esResta = movimiento.esSalida;
    final String signo = esResta ? '-' : '+';
    final String cantidadStr =
        '$signo${movimiento.cantidad.toStringAsFixed(movimiento.cantidad % 1 == 0 ? 0 : 2)} u.';

    final bool tieneTransicion = movimiento.stockAnterior != null &&
        movimiento.stockPosterior != null;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono Tipo
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withAlpha(25),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),

            // Contenido Central
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre del Producto
                  Text(
                    movimiento.nombreProducto ?? 'Producto #${movimiento.productoId.substring(0, 6)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Etiqueta del tipo y fecha
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          movimiento.etiquetaTipo,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        fechaFormateada,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),

                  // Motivo si existe
                  if (movimiento.motivo != null &&
                      movimiento.motivo!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      movimiento.motivo!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],

                  // Transición de Stock: Stock: 10 ➔ 8
                  if (tieneTransicion) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text(
                          'Stock: ',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted),
                        ),
                        Text(
                          movimiento.stockAnterior!.toStringAsFixed(
                              movimiento.stockAnterior! % 1 == 0 ? 0 : 1),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary),
                        ),
                        const Icon(Icons.arrow_right_alt,
                            size: 16, color: AppColors.textMuted),
                        Text(
                          movimiento.stockPosterior!.toStringAsFixed(
                              movimiento.stockPosterior! % 1 == 0 ? 0 : 1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Columna Derecha: Cantidad y Pérdida en Bs.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  cantidadStr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: esResta ? AppColors.danger : AppColors.success,
                  ),
                ),
                if (movimiento.esMerma && movimiento.costoTotal > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '-Bs. ${movimiento.costoTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGETS AUXILIARES DE FILTROS Y RESÚMENES
// ============================================================================
class _ChipPeriodo extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final VoidCallback onTap;

  const _ChipPeriodo({
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (_) => onTap(),
      backgroundColor: AppColors.background,
      selectedColor: AppColors.primary.withAlpha(30),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
        color: seleccionado ? AppColors.primary : AppColors.textPrimary,
      ),
    );
  }
}

class _ChipTipo extends StatelessWidget {
  final String label;
  final String tipo;
  final bool seleccionado;
  final VoidCallback onTap;

  const _ChipTipo({
    required this.label,
    required this.tipo,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (_) => onTap(),
      backgroundColor: AppColors.background,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: seleccionado ? Colors.white : AppColors.textPrimary,
      ),
    );
  }
}

class _MiniCardResumen extends StatelessWidget {
  final String titulo;
  final String valor;
  final String? subvalor;
  final IconData icono;
  final Color color;

  const _MiniCardResumen({
    required this.titulo,
    required this.valor,
    this.subvalor,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            valor,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900, color: color),
          ),
          if (subvalor != null) ...[
            Text(
              subvalor!,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ],
      ),
    );
  }
}
