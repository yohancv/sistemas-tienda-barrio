import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../inventario/data/models/producto_model.dart';

/// Resultado devuelto por el modal de venta dual
class ResultadoVentaDual {
  /// true = cajetilla/empaque entero; false = unidades sueltas
  final bool esEmpaqueEntero;

  /// Cantidad de unidades sueltas seleccionadas (solo aplica si esEmpaqueEntero == false)
  final double cantidadSuelta;

  const ResultadoVentaDual({
    required this.esEmpaqueEntero,
    this.cantidadSuelta = 0,
  });
}

/// Modal de selección rápida para productos con venta dual.
/// Permite al usuario elegir entre comprar el empaque/cajetilla entera
/// o seleccionar unidades sueltas con controles masivos (+/-).
class ModalVentaDual extends StatefulWidget {
  final Producto producto;
  final void Function(ResultadoVentaDual resultado) onSeleccionar;

  const ModalVentaDual({
    super.key,
    required this.producto,
    required this.onSeleccionar,
  });

  @override
  State<ModalVentaDual> createState() => _ModalVentaDualState();
}

class _ModalVentaDualState extends State<ModalVentaDual> {
  double _cantidadSuelta = 1.0;

  double get _subtotalSuelto =>
      (_cantidadSuelta * widget.producto.precioVentaSuelta * 100).round() / 100.0;

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final nombreSuelto = p.nombreUnidadSuelta;
    final nombreSueltoPlural = '${nombreSuelto}s';
    final udsEnEmpaque = p.unidadesEnEmpaqueVenta.truncateToDouble() == p.unidadesEnEmpaqueVenta
        ? p.unidadesEnEmpaqueVenta.toInt().toString()
        : p.unidadesEnEmpaqueVenta.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de arrastre
          Center(
            child: Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Encabezado del producto
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2, size: 28, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p.nombre,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Text(
            '¿Qué lleva el cliente?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 12),

          // Opción 1: Empaque / Cajetilla entera
          SizedBox(
            height: 70,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: AppColors.primary.withAlpha(10),
              ),
              onPressed: () {
                widget.onSeleccionar(
                  const ResultadoVentaDual(esEmpaqueEntero: true),
                );
                Navigator.pop(context);
              },
              child: Row(
                children: [
                  const Icon(Icons.inventory_2, size: 30, color: AppColors.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entero ($udsEnEmpaque $nombreSueltoPlural)',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Precio: Bs. ${p.precioVenta.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Bs. ${p.precioVenta.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Opción 2: Unidades sueltas con selector masivo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.secondary, width: 2),
              color: AppColors.secondary.withAlpha(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.scatter_plot, size: 26, color: AppColors.secondary),
                    const SizedBox(width: 10),
                    Text(
                      '$nombreSueltoPlural suelto(s)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Bs. ${p.precioVentaSuelta.toStringAsFixed(2)} cada $nombreSuelto',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 14),

                // Controles masivos de cantidad
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Botón decrementar
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: const BorderSide(
                            color: AppColors.borderStrong,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _cantidadSuelta > 1
                            ? () => setState(() => _cantidadSuelta--)
                            : null,
                        child: const Icon(Icons.remove, size: 30, color: AppColors.textPrimary),
                      ),
                    ),

                    // Cantidad central
                    Container(
                      constraints: const BoxConstraints(minWidth: 80),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _cantidadSuelta.toInt().toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),

                    // Botón incrementar
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          padding: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => setState(() => _cantidadSuelta++),
                        child: const Icon(Icons.add, size: 30, color: Colors.white),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Subtotal de venta suelta
                Center(
                  child: Text(
                    'Subtotal: Bs. ${_subtotalSuelto.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Botón agregar sueltos al ticket
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      widget.onSeleccionar(ResultadoVentaDual(
                        esEmpaqueEntero: false,
                        cantidadSuelta: _cantidadSuelta,
                      ));
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 24),
                    label: Text(
                      'Agregar ${_cantidadSuelta.toInt()} $nombreSueltoPlural • Bs. ${_subtotalSuelto.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
