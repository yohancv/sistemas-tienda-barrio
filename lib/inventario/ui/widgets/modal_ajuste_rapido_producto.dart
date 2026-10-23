import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../compras/ui/screens/compras_proveedores_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/models/producto_model.dart';
import '../../state/providers/inventario_providers.dart';
import '../screens/formulario_producto_screen.dart';
import '../screens/movimientos_inventario_screen.dart';

/// Modal rápido para administrar un producto desde el inventario en 2 segundos:
/// - Ver costos, precio actual y margen de ganancia.
/// - Cambiar el precio de venta al instante (ej. si subió el aceite o el azúcar).
/// - Acceso a editar ficha completa, reportar merma o pedir a proveedores.
class ModalAjusteRapidoProducto extends ConsumerStatefulWidget {
  final Producto producto;

  const ModalAjusteRapidoProducto({
    super.key,
    required this.producto,
  });

  @override
  ConsumerState<ModalAjusteRapidoProducto> createState() =>
      _ModalAjusteRapidoProductoState();
}

class _ModalAjusteRapidoProductoState
    extends ConsumerState<ModalAjusteRapidoProducto> {
  late final TextEditingController _precioVentaController;
  late final TextEditingController _precioEmpaqueController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _precioVentaController = TextEditingController(
      text: widget.producto.precioVenta.toStringAsFixed(2),
    );
    _precioEmpaqueController = TextEditingController(
      text: widget.producto.precioEmpaqueMayorista != null
          ? widget.producto.precioEmpaqueMayorista!.toStringAsFixed(2)
          : widget.producto.precioVentaEmpaqueEfectivo.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _precioVentaController.dispose();
    _precioEmpaqueController.dispose();
    super.dispose();
  }

  double get _nuevoPrecioVenta =>
      double.tryParse(_precioVentaController.text.trim().replaceAll(',', '.')) ??
      widget.producto.precioVenta;

  double get _nuevoPrecioEmpaque =>
      double.tryParse(_precioEmpaqueController.text.trim().replaceAll(',', '.')) ??
      widget.producto.precioVentaEmpaqueEfectivo;

  double get _gananciaUnitaria => _nuevoPrecioVenta - widget.producto.costoMayorista;

  double get _margenPorcentual {
    if (widget.producto.costoMayorista <= 0) return 100.0;
    return (_gananciaUnitaria / widget.producto.costoMayorista) * 100.0;
  }

  void _guardarPrecios() async {
    final nuevoPrecio = _nuevoPrecioVenta;
    if (nuevoPrecio <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('El precio de venta debe ser mayor a 0.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final productoModificado = widget.producto.copyWith(
        precioVenta: nuevoPrecio,
        precioEmpaqueMayorista: widget.producto.tieneEmpaqueMayorista ? _nuevoPrecioEmpaque : null,
        updatedAt: DateTime.now(),
      );

      final notifier = ref.read(productoOperacionProvider.notifier);
      final exito = await notifier.guardarProducto(productoModificado);

      if (mounted) {
        setState(() => _isSaving = false);
        if (exito != null) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text(
                '✅ Precio de "${widget.producto.nombre}" actualizado a Bs. ${nuevoPrecio.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Error al actualizar: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prod = widget.producto;
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = esOscuro ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textMuted = esOscuro ? AppColors.darkTextMuted : AppColors.textMuted;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final inputBg = esOscuro ? AppColors.darkBackground : AppColors.background;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra de arrastre superior
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cardBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Cabecera con Nombre y Categoría
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    Producto.emojiCategoria(prod.categoria),
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prod.nombre,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${prod.categoria ?? "General"} • ${prod.subcategoria ?? ""}',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                      if (prod.codigoBarras != null && prod.codigoBarras!.isNotEmpty)
                        Text(
                          'Cód: #${prod.codigoBarras}',
                          style: TextStyle(fontSize: 11, color: textMuted),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Divider(height: 1, color: cardBorder),
            const SizedBox(height: 14),

            // Tarjeta de Stock y Rentabilidad
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  // Stock Actual
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock en Tienda',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          prod.stockLegibleDesglosado,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          prod.esStockBajo
                              ? '⚠️ Stock bajo (mín: ${prod.stockMinimo.toInt()})'
                              : '✅ Stock óptimo',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: prod.esStockBajo ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: cardBorder),
                  const SizedBox(width: 12),

                  // Costo vs Ganancia
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rentabilidad por Ud.',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Costo: Bs. ${prod.costoMayorista.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                        Text(
                          'Ganas: +Bs. ${_gananciaUnitaria.toStringAsFixed(2)} (${_margenPorcentual.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _gananciaUnitaria >= 0 ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Campos de Modificación Rápida de Precio
            Text(
              'MODIFICAR PRECIO DE VENTA AL CLIENTE:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                // Precio por Unidad
                Expanded(
                  child: TextFormField(
                    controller: _precioVentaController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Precio Venta Unitario',
                      prefixText: 'Bs. ',
                      helperText: 'Por unidad suelta',
                      helperStyle: TextStyle(color: textMuted),
                      filled: true,
                      fillColor: inputBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                // Precio por Empaque / Caja (si aplica venta por caja en mostrador)
                if (prod.permiteVentaEmpaque) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _precioEmpaqueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Precio ${prod.nombreEmpaqueLegible}',
                        prefixText: 'Bs. ',
                        helperText: 'Caja x${prod.unidadesPorEmpaque.toInt()} uds',
                        helperStyle: TextStyle(color: textMuted),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Botón Guardar Nuevo Precio
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 1,
                ),
                onPressed: _isSaving ? null : _guardarPrecios,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(
                  _isSaving ? 'Guardando...' : 'Guardar Nuevo Precio (Bs. ${_nuevoPrecioVenta.toStringAsFixed(2)})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: cardBorder),
            const SizedBox(height: 12),

            // Acciones Adicionales
            Text(
              'OTRAS ACCIONES PARA ESTE PRODUCTO:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                // Editar Ficha Completa
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FormularioProductoScreen(productoParaEditar: prod),
                        ),
                      );
                    },
                    icon: Icon(Icons.edit_outlined, size: 16, color: textPrimary),
                    label: Text(
                      'Ficha Completa',
                      style: TextStyle(fontSize: 12, color: textPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Reportar Merma / Rotura
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.danger.withAlpha(80)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MovimientosInventarioScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.remove_circle_outline, size: 16, color: AppColors.danger),
                    label: const Text(
                      'Baja / Merma',
                      style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Pedir a Proveedor
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary.withAlpha(80)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ComprasProveedoresScreen(tabInicial: 0),
                        ),
                      );
                    },
                    icon: const Icon(Icons.shopping_cart_outlined, size: 16, color: AppColors.primary),
                    label: const Text(
                      'Pedir Orden',
                      style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
