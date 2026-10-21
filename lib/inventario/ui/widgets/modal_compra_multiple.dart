import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../data/models/producto_model.dart';
import '../../state/providers/inventario_providers.dart';

/// Modal para seleccionar múltiples productos comprados y registrar
/// su entrada de inventario en lote sin tener que buscar uno por uno.
class ModalCompraMultiple extends ConsumerStatefulWidget {
  final List<Producto> productos;

  const ModalCompraMultiple({super.key, required this.productos});

  @override
  ConsumerState<ModalCompraMultiple> createState() => _ModalCompraMultipleState();
}

class _ModalCompraMultipleState extends ConsumerState<ModalCompraMultiple> {
  final Map<String, double> _cantidadesEmpaque = {};
  final Map<String, double> _cantidadesUnidades = {};
  final Set<String> _seleccionados = {};
  String _filtroTexto = '';
  bool _guardando = false;

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.productos.where((p) {
      if (_filtroTexto.isEmpty) return true;
      final q = _filtroTexto.toLowerCase();
      return p.nombre.toLowerCase().contains(q) ||
          (p.categoria ?? '').toLowerCase().contains(q) ||
          (p.subcategoria ?? '').toLowerCase().contains(q);
    }).toList();

    final cantidadSeleccionados = _seleccionados.length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Barra de agarre
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Título
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              children: [
                const Icon(Icons.add_shopping_cart, color: AppColors.primary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ingreso de Varios Productos',
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Buscador rápido de productos en la lista
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: TextField(
              onChanged: (val) => setState(() => _filtroTexto = val.trim()),
              decoration: InputDecoration(
                hintText: 'Filtrar productos a reabastecer...',
                prefixIcon: const Icon(Icons.search, size: 22),
                filled: true,
                fillColor: AppColors.surfaceMuted,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Lista de productos seleccionables
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              itemCount: filtrados.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = filtrados[index];
                final estaMarcado = _seleccionados.contains(p.id);

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: estaMarcado,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _seleccionados.add(p.id);
                                  _cantidadesEmpaque.putIfAbsent(p.id, () => 1.0);
                                  _cantidadesUnidades.putIfAbsent(p.id, () => 0.0);
                                } else {
                                  _seleccionados.remove(p.id);
                                }
                              });
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.nombre,
                                  style: TextStyle(
                                    fontWeight: estaMarcado ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Stock actual: ${p.stockLegibleDesglosado}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Si está marcado, mostrar campos de entrada rápida de cantidad
                      if (estaMarcado)
                        Container(
                          margin: const EdgeInsets.only(left: 48, top: 6, bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              if (p.tieneEmpaqueMayorista) ...[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${p.nombreEmpaquePlural} (${p.unidadesPorEmpaque.toInt()} uds):',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                                            onPressed: () {
                                              final act = _cantidadesEmpaque[p.id] ?? 0;
                                              if (act > 0) {
                                                setState(() => _cantidadesEmpaque[p.id] = act - 1);
                                              }
                                            },
                                          ),
                                          Text(
                                            '${(_cantidadesEmpaque[p.id] ?? 1).toInt()}',
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, color: AppColors.success),
                                            onPressed: () {
                                              final act = _cantidadesEmpaque[p.id] ?? 0;
                                              setState(() => _cantidadesEmpaque[p.id] = act + 1);
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.esFraccionable ? 'Kilos/Libras:' : 'Unidades sueltas:',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                                          onPressed: () {
                                            final act = _cantidadesUnidades[p.id] ?? 0;
                                            if (act > 0) {
                                              setState(() => _cantidadesUnidades[p.id] = act - 1);
                                            }
                                          },
                                        ),
                                        Text(
                                          p.esFraccionable
                                              ? (_cantidadesUnidades[p.id] ?? 0).toStringAsFixed(1)
                                              : '${(_cantidadesUnidades[p.id] ?? 0).toInt()}',
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, color: AppColors.success),
                                          onPressed: () {
                                            final act = _cantidadesUnidades[p.id] ?? 0;
                                            setState(() => _cantidadesUnidades[p.id] = act + 1);
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Botón inferior para confirmar el lote
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _guardando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline, size: 22),
                label: Text(
                  _guardando ? 'Guardando cambios...' : 'AÑADIR AL STOCK ($cantidadSeleccionados PRODUCTOS)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: _guardando || cantidadSeleccionados == 0
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);

                        setState(() => _guardando = true);
                        try {
                          final repo = ref.read(inventarioRepositoryProvider);

                          for (final id in _seleccionados) {
                            final p = widget.productos.firstWhere((prod) => prod.id == id);
                            final empaques = _cantidadesEmpaque[id] ?? 0;
                            final sueltas = _cantidadesUnidades[id] ?? 0;

                            final totalUnidades = (empaques * p.unidadesPorEmpaque) + sueltas;
                            if (totalUnidades > 0) {
                              final nuevoStock = p.stockActual + totalUnidades;
                              await repo.actualizarProducto(p.copyWith(stockActual: nuevoStock));
                              await repo.registrarAjusteManualStock(
                                productoId: p.id,
                                tenantId: SupabaseConfig.defaultTenantId,
                                cantidadDelta: totalUnidades,
                                costoUnitario: p.costoMayorista,
                                stockAnterior: p.stockActual,
                                stockPosterior: nuevoStock,
                              );
                            }
                          }

                          ref.invalidate(productosListProvider);

                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('¡Se añadieron las compras de $cantidadSeleccionados productos al inventario!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Error al guardar: $e'), backgroundColor: AppColors.danger),
                          );
                        } finally {
                          if (mounted) setState(() => _guardando = false);
                        }
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
