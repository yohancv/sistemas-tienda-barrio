import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../inventario/data/models/producto_model.dart';

/// Modal para venta de productos a granel/pesables optimizado para tiendas de barrio:
/// 1. Un único recuadro principal donde se introduce o visualiza el precio por dinero.
/// 2. Fila de venta rápida por fracciones de peso (1/4, 1/2, 3/4, 1 kg/lb).
/// 3. Botón para desplegar balanza / teclado numérico solo cuando se requiere un peso exacto.
/// 4. Botón masivo para confirmar y agregar al ticket.
class ModalVentaFraccionada extends StatefulWidget {
  final Producto producto;
  final void Function(double peso, double totalCobrar) onAgregarAlTicket;

  const ModalVentaFraccionada({
    super.key,
    required this.producto,
    required this.onAgregarAlTicket,
  });

  @override
  State<ModalVentaFraccionada> createState() => _ModalVentaFraccionadaState();
}

class _ModalVentaFraccionadaState extends State<ModalVentaFraccionada> {
  late final TextEditingController _dineroController;
  double _totalCobrar = 0.0;
  double _pesoActual = 0.0;

  // Fracción seleccionada (0.25, 0.50, 0.75, 1.00)
  double? _fraccionSeleccionada;

  // Despliegue de peso específico de balanza
  bool _mostrarBalanza = false;
  String _inputPesoBalanza = '';

  double get _precioPorUnidad => widget.producto.precioVenta;
  String get _unidadMedida => widget.producto.tipoEmpaque == 'LIBRA' ? 'lb' : 'kg';
  String get _nombreUnidad => widget.producto.tipoEmpaque == 'LIBRA' ? 'Libra' : 'Kilo';

  @override
  void initState() {
    super.initState();
    _dineroController = TextEditingController();
  }

  @override
  void dispose() {
    _dineroController.dispose();
    super.dispose();
  }

  /// Redondeo comercial boliviano: en tiendas de barrio no circulan monedas menores a 50 centavos.
  /// Se redondea hacia arriba al múltiplo de 0.50 Bs más cercano (ej: 3.33 -> 3.50 Bs, 4.38 -> 4.50 Bs).
  double _redondearComercial(double valor) {
    if (valor <= 0) return 0.0;
    return (valor * 2).ceilToDouble() / 2.0;
  }

  /// Selecciona una fracción rápida de peso (1/4, 1/2, 3/4, 1 kg)
  void _seleccionarFraccion(double fraccion) {
    if (_precioPorUnidad <= 0) return;
    final rawTotal = fraccion * _precioPorUnidad;
    final total = _redondearComercial(rawTotal);
    setState(() {
      _fraccionSeleccionada = fraccion;
      _pesoActual = fraccion;
      _totalCobrar = total;
      _dineroController.text = total.toStringAsFixed(2);
      _inputPesoBalanza = fraccion.toString();
    });
  }

  /// Actualiza cuando el usuario escribe manualmente en el recuadro de dinero
  void _onDineroChanged(String valor) {
    final limpio = valor.replaceAll(',', '.');
    final monto = double.tryParse(limpio) ?? 0.0;
    final peso = _precioPorUnidad > 0
        ? (monto / _precioPorUnidad * 1000).round() / 1000.0
        : 0.0;

    setState(() {
      _totalCobrar = monto;
      _pesoActual = peso;
      _fraccionSeleccionada = null;
      _inputPesoBalanza = peso > 0 ? peso.toString() : '';
    });
  }

  /// Entrada táctil del teclado de balanza para peso específico
  void _onTeclaBalanza(String tecla) {
    setState(() {
      if (tecla == '⌫') {
        if (_inputPesoBalanza.isNotEmpty) {
          _inputPesoBalanza = _inputPesoBalanza.substring(0, _inputPesoBalanza.length - 1);
        }
      } else if (tecla == '.') {
        if (!_inputPesoBalanza.contains('.')) {
          _inputPesoBalanza = _inputPesoBalanza.isEmpty ? '0.' : '$_inputPesoBalanza.';
        }
      } else {
        if (_inputPesoBalanza.contains('.')) {
          final partes = _inputPesoBalanza.split('.');
          if (partes[1].length >= 3) return;
        }
        _inputPesoBalanza += tecla;
      }

      final peso = double.tryParse(_inputPesoBalanza) ?? 0.0;
      _pesoActual = peso;
      final rawTotal = peso * _precioPorUnidad;
      _totalCobrar = _redondearComercial(rawTotal);
      _dineroController.text = _totalCobrar.toStringAsFixed(2);
      _fraccionSeleccionada = null;
    });
  }

  void _limpiarBalanza() {
    setState(() {
      _inputPesoBalanza = '';
      _pesoActual = 0.0;
      _totalCobrar = 0.0;
      _dineroController.clear();
      _fraccionSeleccionada = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.scale, size: 28, color: AppColors.secondary),
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
                      Text(
                        'Precio: Bs. ${_precioPorUnidad.toStringAsFixed(2)} por $_nombreUnidad',
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
                  icon: const Icon(Icons.close, size: 26, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 1. RECUADRO PRINCIPAL: PRECIO POR DINERO
            const Text(
              '💵 PRECIO POR DINERO (MONTO A COBRAR):',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _totalCobrar > 0 ? AppColors.primary : AppColors.border,
                  width: 2.5,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Bs.',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _dineroController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: _onDineroChanged,
                        ),
                      ),
                      if (_dineroController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.danger, size: 26),
                          onPressed: () {
                            _dineroController.clear();
                            _onDineroChanged('');
                          },
                        ),
                    ],
                  ),
                  const Divider(height: 16, thickness: 1),
                  // Equivalencia sincronizada en peso
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Equivale a:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _pesoActual > 0
                              ? AppColors.secondary.withAlpha(20)
                              : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_pesoActual.toStringAsFixed(3)} $_unidadMedida',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _pesoActual > 0 ? AppColors.secondary : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. VENTA RÁPIDA POR PESO (1/4, 1/2, 3/4, 1 kg)
            const Text(
              '⚖️ VENTA RÁPIDA POR PESO:',
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
                _buildBotonFraccion('¼ $_unidadMedida', 0.25),
                const SizedBox(width: 8),
                _buildBotonFraccion('½ $_unidadMedida', 0.50),
                const SizedBox(width: 8),
                _buildBotonFraccion('¾ $_unidadMedida', 0.75),
                const SizedBox(width: 8),
                _buildBotonFraccion('1 $_unidadMedida', 1.00),
              ],
            ),

            const SizedBox(height: 12),

            // Botón interactivo que despliega el teclado de peso específico
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: BorderSide(
                  color: _mostrarBalanza ? AppColors.secondary : AppColors.borderStrong,
                  width: 1.8,
                ),
                backgroundColor: _mostrarBalanza
                    ? AppColors.secondary.withAlpha(15)
                    : Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() {
                  _mostrarBalanza = !_mostrarBalanza;
                });
              },
              icon: Icon(
                _mostrarBalanza ? Icons.expand_less : Icons.scale_outlined,
                color: _mostrarBalanza ? AppColors.secondary : AppColors.textPrimary,
                size: 24,
              ),
              label: Text(
                _mostrarBalanza
                    ? 'Ocultar teclado de balanza'
                    : '⚖️ ¿Otro peso específico de balanza? (Tocar aquí)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _mostrarBalanza ? AppColors.secondary : AppColors.textPrimary,
                ),
              ),
            ),

            // 3. SECCIÓN DESPLEGABLE: BALANZA Y TECLADO TÁCTIL
            if (_mostrarBalanza) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.secondary.withAlpha(80), width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Peso en balanza ($_unidadMedida):',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (_inputPesoBalanza.isNotEmpty)
                          TextButton(
                            onPressed: _limpiarBalanza,
                            child: const Text(
                              'Borrar',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.secondary, width: 2),
                      ),
                      child: Text(
                        _inputPesoBalanza.isEmpty ? '0.000' : _inputPesoBalanza,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    _buildTecladoNumerico(),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 22),

            // 4. BOTÓN PRINCIPAL MASIVO DE AGREGAR AL TICKET
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _totalCobrar > 0 ? AppColors.success : AppColors.surfaceMuted,
                  elevation: _totalCobrar > 0 ? 3 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _totalCobrar > 0
                    ? () {
                        widget.onAgregarAlTicket(_pesoActual, _totalCobrar);
                        Navigator.pop(context);
                      }
                    : null,
                icon: Icon(
                  Icons.add_shopping_cart,
                  size: 26,
                  color: _totalCobrar > 0 ? Colors.white : AppColors.textMuted,
                ),
                label: Text(
                  _totalCobrar > 0
                      ? 'Agregar al Ticket (Bs. ${_totalCobrar.toStringAsFixed(2)})'
                      : 'Elige peso o monto a cobrar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _totalCobrar > 0 ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonFraccion(String texto, double valor) {
    final seleccionado = _fraccionSeleccionada == valor;
    return Expanded(
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: seleccionado ? AppColors.secondary : AppColors.surfaceMuted,
            elevation: seleccionado ? 2 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: seleccionado ? AppColors.secondary : AppColors.border,
                width: seleccionado ? 2 : 1.2,
              ),
            ),
          ),
          onPressed: () => _seleccionarFraccion(valor),
          child: Text(
            texto,
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

  Widget _buildTecladoNumerico() {
    const teclas = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', '⌫'],
    ];

    return Column(
      children: teclas.map((fila) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: fila.map((tecla) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tecla == '⌫'
                            ? AppColors.danger.withAlpha(20)
                            : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AppColors.border, width: 1),
                        ),
                      ),
                      onPressed: () => _onTeclaBalanza(tecla),
                      child: Text(
                        tecla,
                        style: TextStyle(
                          fontSize: tecla == '⌫' ? 20 : 22,
                          fontWeight: FontWeight.bold,
                          color: tecla == '⌫' ? AppColors.danger : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
