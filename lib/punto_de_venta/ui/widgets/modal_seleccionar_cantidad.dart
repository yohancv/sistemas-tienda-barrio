import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../inventario/data/models/producto_model.dart';

class ModalSeleccionarCantidad extends StatefulWidget {
  final Producto producto;
  final double unidadesEnCajas; // Unidades disponibles en cajas padre
  final double cantidadInicialEnCarrito;
  final void Function(double cantidad) onConfirmar;

  const ModalSeleccionarCantidad({
    super.key,
    required this.producto,
    this.unidadesEnCajas = 0.0,
    this.cantidadInicialEnCarrito = 0.0,
    required this.onConfirmar,
  });

  @override
  State<ModalSeleccionarCantidad> createState() => _ModalSeleccionarCantidadState();
}

class _ModalSeleccionarCantidadState extends State<ModalSeleccionarCantidad> {
  late final TextEditingController _cantidadController;
  double _cantidad = 1.0;

  double get _stockEnMostrador => widget.producto.stockActual;
  double get _stockTotalDisponible => _stockEnMostrador + widget.unidadesEnCajas;
  bool get _tieneCajasEnAlmacen => widget.unidadesEnCajas > 0;

  // Determina si para esta cantidad se requerirá abrir cajas automáticamente
  bool get _requiereAutoDesempaque =>
      _cantidad > _stockEnMostrador && _cantidad <= _stockTotalDisponible;

  // Determina si la cantidad supera el total físico existente
  bool get _superaStockTotal => _cantidad > _stockTotalDisponible;

  // Cuántas cajas se abrirán
  int get _cajasAAbrir {
    if (!_requiereAutoDesempaque || widget.producto.unidadesPorEmpaque <= 0) return 0;
    final faltante = _cantidad - _stockEnMostrador;
    return (faltante / widget.producto.unidadesPorEmpaque).ceil();
  }

  // Cuántas botellas/unidades quedarán sueltas tras la venta y el desempaque
  double get _unidadesRestantesProyectadas {
    final unidadesSumadas = _cajasAAbrir * widget.producto.unidadesPorEmpaque;
    return (_stockEnMostrador + unidadesSumadas) - _cantidad;
  }

  @override
  void initState() {
    super.initState();
    // Iniciar con 1 unidad o lo que ya tenía
    _cantidad = widget.cantidadInicialEnCarrito > 0 ? widget.cantidadInicialEnCarrito : 1.0;
    // Si el stock total es 0, permitir mostrar 0
    if (_stockTotalDisponible <= 0) {
      _cantidad = 0.0;
    }
    _cantidadController = TextEditingController(
      text: _cantidad.truncateToDouble() == _cantidad
          ? _cantidad.toInt().toString()
          : _cantidad.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  void _ajustarCantidad(double nuevaCantidad) {
    if (nuevaCantidad < 1) return;

    // Validación estricta: No permitir superar el stock total disponible
    if (nuevaCantidad > _stockTotalDisponible && _stockTotalDisponible > 0) {
      _mostrarAvisoStockMaximo();
      nuevaCantidad = _stockTotalDisponible;
    }

    setState(() {
      _cantidad = nuevaCantidad;
      _cantidadController.text = _cantidad.truncateToDouble() == _cantidad
          ? _cantidad.toInt().toString()
          : _cantidad.toStringAsFixed(1);
    });
  }

  void _onInputManualChanged(String valor) {
    final parseado = double.tryParse(valor.replaceAll(',', '.')) ?? 0.0;
    setState(() {
      _cantidad = parseado;
    });
  }

  void _mostrarAvisoStockMaximo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(
          'Stock máximo alcanzado: Solo hay ${_stockTotalDisponible.toInt()} unidades disponibles.',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = (_cantidad * widget.producto.precioVenta * 100).round() / 100.0;
    final bool esValido = _cantidad > 0 && !_superaStockTotal;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pestaña superior de arrastre
            Center(
              child: Container(
                width: 44,
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
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_drink, size: 30, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.producto.nombre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Precio unitario: Bs. ${widget.producto.precioVenta.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 28, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Tarjeta de estado de stock en mostrador y almacén
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 24, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock en mostrador: ${_stockEnMostrador.toInt()} uds',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _stockEnMostrador <= 0 ? AppColors.danger : AppColors.textPrimary,
                          ),
                        ),
                        if (_tieneCajasEnAlmacen)
                          Text(
                            '📦 ${widget.unidadesEnCajas.toInt()} uds en almacén (cajas) • Total: ${_stockTotalDisponible.toInt()} uds',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Selector Central Masivo: [ - ] [ Cantidad ] [ + ]
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Botón Disminuir
                InkWell(
                  onTap: _cantidad > 1 ? () => _ajustarCantidad(_cantidad - 1) : null,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _cantidad > 1 ? AppColors.surfaceMuted : AppColors.surfaceMuted.withAlpha(50),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: Icon(
                      Icons.remove,
                      size: 36,
                      color: _cantidad > 1 ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Entrada numérica central grande
                Container(
                  width: 130,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _superaStockTotal ? AppColors.danger : AppColors.primary,
                      width: 2.5,
                    ),
                  ),
                  child: TextField(
                    controller: _cantidadController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: _superaStockTotal ? AppColors.danger : AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: _onInputManualChanged,
                  ),
                ),

                const SizedBox(width: 16),

                // Botón Aumentar
                InkWell(
                  onTap: _cantidad < _stockTotalDisponible
                      ? () => _ajustarCantidad(_cantidad + 1)
                      : () => _mostrarAvisoStockMaximo(),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _cantidad < _stockTotalDisponible
                          ? AppColors.primary.withAlpha(20)
                          : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _cantidad < _stockTotalDisponible ? AppColors.primary : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.add,
                      size: 36,
                      color: _cantidad < _stockTotalDisponible ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Fila de Atajos Rápidos (1, 2, 3, 4, 6, 12 botellas)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [1, 2, 3, 4, 6, 12].map((preset) {
                final bool seleccionado = _cantidad == preset.toDouble();
                final bool disponible = preset <= _stockTotalDisponible;

                return InkWell(
                  onTap: disponible ? () => _ajustarCantidad(preset.toDouble()) : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: seleccionado
                          ? AppColors.primary
                          : (disponible ? AppColors.surfaceMuted : AppColors.background),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: seleccionado
                            ? AppColors.primary
                            : (disponible ? AppColors.border : AppColors.border.withAlpha(60)),
                        width: seleccionado ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '$preset uds',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: seleccionado
                            ? Colors.white
                            : (disponible ? AppColors.textPrimary : AppColors.textMuted),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Mensaje de Auto-Desempaque o Advertencia de Stock
            if (_superaStockTotal)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No puedes agregar más de ${_stockTotalDisponible.toInt()} unidades. No hay más stock en almacén.',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_requiereAutoDesempaque)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.secondary, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.unarchive_outlined, color: AppColors.secondary, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '📦 ¡Auto-Desempaque!: Al cobrar se abrirá $_cajasAAbrir caja(s) de almacén automáticamente (quedarán ${_unidadesRestantesProyectadas.toInt()} uds sueltas disponibles).',
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 18),

            // Resumen de Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SUBTOTAL:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  'Bs. ${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Botón Masivo Confirmar Agregar al Ticket (60dp)
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: esValido ? AppColors.primary : AppColors.surfaceMuted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: esValido ? 4 : 0,
                ),
                onPressed: esValido
                    ? () {
                        widget.onConfirmar(_cantidad);
                        Navigator.pop(context);
                      }
                    : null,
                icon: Icon(
                  Icons.add_shopping_cart,
                  color: esValido ? Colors.white : AppColors.textMuted,
                  size: 26,
                ),
                label: Text(
                  esValido
                      ? 'Agregar al Ticket (${_cantidad.toInt()} uds)'
                      : 'Stock Insuficiente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: esValido ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
