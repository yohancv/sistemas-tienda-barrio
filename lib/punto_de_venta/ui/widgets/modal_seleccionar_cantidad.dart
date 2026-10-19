import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../inventario/data/models/producto_model.dart';
import '../../data/models/item_carrito_model.dart';

class ModalSeleccionarCantidad extends StatefulWidget {
  final Producto producto;
  final double unidadesEnCajas; // Unidades disponibles en cajas padre
  final double cantidadInicialEnCarrito;
  final void Function(double cantidad, ModoVenta modoVenta) onConfirmar;

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
  ModoVenta _modoVenta = ModoVenta.normal;

  double get _stockEnMostrador => widget.producto.stockActual;
  double get _stockTotalDisponible => _stockEnMostrador + widget.unidadesEnCajas;
  bool get _tieneCajasEnAlmacen => widget.unidadesEnCajas > 0;
  bool get _tieneEmpaque => widget.producto.permiteVentaEmpaque;
  double get _udsPorEmpaque =>
      widget.producto.unidadesPorEmpaque > 0 ? widget.producto.unidadesPorEmpaque : 1.0;

  bool get _esEmpaque => _modoVenta == ModoVenta.porEmpaqueMayorista;

  double get _maxDisponible =>
      _esEmpaque ? (_stockTotalDisponible ~/ _udsPorEmpaque).toDouble() : _stockTotalDisponible;

  bool get _superaStockTotal => _cantidad > _maxDisponible;

  double get _precioActivo =>
      _esEmpaque ? widget.producto.precioVentaEmpaqueEfectivo : widget.producto.precioVenta;



  @override
  void initState() {
    super.initState();
    _cantidad = widget.cantidadInicialEnCarrito > 0 ? widget.cantidadInicialEnCarrito : 1.0;
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

  void _cambiarModo(ModoVenta nuevoModo) {
    if (_modoVenta == nuevoModo) return;
    setState(() {
      _modoVenta = nuevoModo;
      if (nuevoModo == ModoVenta.porEmpaqueMayorista) {
        final maxEmp = _stockTotalDisponible ~/ _udsPorEmpaque;
        _cantidad = maxEmp > 0 ? 1.0 : 0.0;
      } else {
        _cantidad = _stockTotalDisponible > 0 ? 1.0 : 0.0;
      }
      _cantidadController.text = _cantidad.truncateToDouble() == _cantidad
          ? _cantidad.toInt().toString()
          : _cantidad.toStringAsFixed(1);
    });
  }

  void _ajustarCantidad(double nuevaCantidad) {
    if (nuevaCantidad < 1) return;

    if (nuevaCantidad > _maxDisponible && _maxDisponible > 0) {
      _mostrarAvisoStockMaximo();
      nuevaCantidad = _maxDisponible;
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
    final texto = _esEmpaque
        ? 'Stock máximo: Solo hay ${_maxDisponible.toInt()} ${widget.producto.nombreEmpaquePlural.toLowerCase()} disponibles (${_stockTotalDisponible.toInt()} uds totales).'
        : 'Stock máximo: Solo hay ${_stockTotalDisponible.toInt()} unidades disponibles.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = (_cantidad * _precioActivo * 100).round() / 100.0;
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
                    color: _esEmpaque
                        ? AppColors.secondary.withAlpha(25)
                        : AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _esEmpaque ? Icons.inventory_2_outlined : Icons.local_drink,
                    size: 30,
                    color: _esEmpaque ? AppColors.secondary : AppColors.primary,
                  ),
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
                        _esEmpaque
                            ? 'Precio ${widget.producto.nombreEmpaqueLegible}: Bs. ${_precioActivo.toStringAsFixed(2)}'
                            : 'Precio unitario: Bs. ${_precioActivo.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _esEmpaque ? AppColors.secondary : AppColors.primary,
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

            const SizedBox(height: 12),

            // Selector interactivo: Venta por Unidad vs Venta por Paquete / Caja
            if (_tieneEmpaque) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    // Opción 1: Por Unidad
                    Expanded(
                      child: InkWell(
                        onTap: () => _cambiarModo(ModoVenta.normal),
                        borderRadius: BorderRadius.circular(11),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_esEmpaque ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '🍾 Por Unidad',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: !_esEmpaque ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Bs. ${widget.producto.precioVenta.toStringAsFixed(2)} c/u',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: !_esEmpaque ? Colors.white70 : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Opción 2: Por Paquete / Caja
                    Expanded(
                      child: InkWell(
                        onTap: () => _cambiarModo(ModoVenta.porEmpaqueMayorista),
                        borderRadius: BorderRadius.circular(11),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _esEmpaque ? AppColors.secondary : Colors.transparent,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '📦 Por ${widget.producto.nombreEmpaqueLegible} (${_udsPorEmpaque.toInt()} uds)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _esEmpaque ? Colors.white : AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Bs. ${widget.producto.precioVentaEmpaqueEfectivo.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _esEmpaque ? Colors.white70 : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Tarjeta de estado de stock inteligente desglosado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    _esEmpaque ? Icons.inventory_2_outlined : Icons.shelves,
                    size: 24,
                    color: _esEmpaque ? AppColors.secondary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock disponible: ${widget.producto.stockLegibleDesglosado}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _stockTotalDisponible <= 0 ? AppColors.danger : AppColors.textPrimary,
                          ),
                        ),
                        if (_esEmpaque)
                          Text(
                            'Puedes vender hasta ${_maxDisponible.toInt()} ${widget.producto.nombreEmpaquePlural.toLowerCase()} cerrados.',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          )
                        else if (_tieneCajasEnAlmacen)
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
                  width: 140,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _superaStockTotal
                          ? AppColors.danger
                          : (_esEmpaque ? AppColors.secondary : AppColors.primary),
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
                  onTap: _cantidad < _maxDisponible
                      ? () => _ajustarCantidad(_cantidad + 1)
                      : () => _mostrarAvisoStockMaximo(),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _cantidad < _maxDisponible
                          ? (_esEmpaque ? AppColors.secondary.withAlpha(20) : AppColors.primary.withAlpha(20))
                          : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _cantidad < _maxDisponible
                            ? (_esEmpaque ? AppColors.secondary : AppColors.primary)
                            : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.add,
                      size: 36,
                      color: _cantidad < _maxDisponible
                          ? (_esEmpaque ? AppColors.secondary : AppColors.primary)
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Fila de Atajos Rápidos adaptativa (Empaques vs Unidades)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: (_esEmpaque ? [1, 2, 3, 5, 10] : [1, 2, 3, 4, 6, 12]).map((preset) {
                final bool seleccionado = _cantidad == preset.toDouble();
                final bool disponible = preset <= _maxDisponible;
                final etiqueta = _esEmpaque
                    ? '$preset ${preset == 1 ? widget.producto.nombreEmpaqueCorto : widget.producto.nombreEmpaquePlural.toLowerCase()}'
                    : '$preset uds';

                return InkWell(
                  onTap: disponible ? () => _ajustarCantidad(preset.toDouble()) : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: seleccionado
                          ? (_esEmpaque ? AppColors.secondary : AppColors.primary)
                          : (disponible ? AppColors.surfaceMuted : AppColors.background),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: seleccionado
                            ? (_esEmpaque ? AppColors.secondary : AppColors.primary)
                            : (disponible ? AppColors.border : AppColors.border.withAlpha(60)),
                        width: seleccionado ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      etiqueta,
                      style: TextStyle(
                        fontSize: 15,
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

            // Mensajes Informativos (Empaque vs Auto-desempaque)
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
                        _esEmpaque
                            ? 'No hay suficiente stock para ${_cantidad.toInt()} ${widget.producto.nombreEmpaquePlural.toLowerCase()}. Máximo disponible: ${_maxDisponible.toInt()}.'
                            : 'No puedes agregar más de ${_stockTotalDisponible.toInt()} unidades. No hay más stock en almacén.',
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
            else if (_esEmpaque)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.secondary, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: AppColors.secondary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '📦 ${_cantidad.toInt()} ${widget.producto.nombreEmpaquePlural.toLowerCase()} = ${(_cantidad * _udsPorEmpaque).toInt()} unidades en total. Se descontará del inventario.',
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontSize: 13,
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

            // Botón Masivo Confirmar Agregar al Ticket
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: esValido
                      ? (_esEmpaque ? AppColors.secondary : AppColors.primary)
                      : AppColors.surfaceMuted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: esValido ? 4 : 0,
                ),
                onPressed: esValido
                    ? () {
                        widget.onConfirmar(_cantidad, _modoVenta);
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
                      ? (_esEmpaque
                          ? 'Agregar ${_cantidad.toInt()} ${widget.producto.nombreEmpaquePlural.toLowerCase()} (${(_cantidad * _udsPorEmpaque).toInt()} uds)'
                          : 'Agregar al Ticket (${_cantidad.toInt()} uds)')
                      : 'Stock Insuficiente',
                  style: TextStyle(
                    fontSize: 17,
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
