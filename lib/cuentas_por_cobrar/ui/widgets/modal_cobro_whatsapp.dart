import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../data/models/cliente_model.dart';
import '../../state/providers/clientes_providers.dart';
import '../../utils/cobro_whatsapp_formatter.dart';

class ModalCobroWhatsApp extends ConsumerStatefulWidget {
  final Cliente cliente;

  const ModalCobroWhatsApp({super.key, required this.cliente});

  @override
  ConsumerState<ModalCobroWhatsApp> createState() => _ModalCobroWhatsAppState();
}

class _ModalCobroWhatsAppState extends ConsumerState<ModalCobroWhatsApp> {
  TonoCobro _tono = TonoCobro.amable;
  bool _incluirProductos = true;
  bool _incluirQr = true;
  bool _cargando = true;
  List<Map<String, dynamic>> _compras = [];

  @override
  void initState() {
    super.initState();
    _cargarDetallesCompras();
  }

  Future<void> _cargarDetallesCompras() async {
    try {
      final repo = ref.read(clientesRepositoryProvider);
      final data = await repo.obtenerDetalleProductosFiados(widget.cliente.id, limiteVentas: 4);
      debugPrint('[ModalCobroWhatsApp] Compras fiadas obtenidas: ${data.length}');
      if (mounted) {
        setState(() {
          _compras = data;
          _cargando = false;
        });
      }
    } catch (e, stack) {
      debugPrint('[ModalCobroWhatsApp] Error cargando detalle compras fiadas: $e\n$stack');
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _generarTextoActual() {
    final opciones = OpcionesCobroWhatsApp(
      tono: _tono,
      incluirProductos: _incluirProductos,
      incluirOpcionQr: _incluirQr,
      nombreTienda: 'Tienda de Barrio',
    );

    return CobroWhatsAppFormatter.formatearMensajeCobro(
      cliente: widget.cliente,
      opciones: opciones,
      comprasFiadas: _compras,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cliente;
    final mensajeActual = _generarTextoActual();
    final tieneTelefono = c.telefono != null && c.telefono!.trim().isNotEmpty;

    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = esOscuro ? AppColors.darkSurface : Colors.white;
    final cardBg = esOscuro ? AppColors.darkBackground : AppColors.surfaceMuted;
    final cardBorder = esOscuro ? AppColors.darkBorder : AppColors.border;
    final textPrimary = esOscuro ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary = esOscuro ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final textMuted = esOscuro ? AppColors.darkTextMuted : AppColors.textMuted;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 1. Barra superior de arrastre
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: cardBorder,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Encabezado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF15803D), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.nombre,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        Text(
                          tieneTelefono ? 'WhatsApp: ${c.telefono}' : 'Sin número guardado',
                          style: TextStyle(
                            fontSize: 12,
                            color: tieneTelefono ? const Color(0xFF15803D) : AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withAlpha(60)),
                  ),
                  child: Text(
                    'Bs. ${c.saldoActual.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 24, color: cardBorder),

          // 3. Contenido scrolleable de opciones y vista previa
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // Selector de Tono del Mensaje
                Text(
                  '1. SELECCIONA EL TONO DEL COBRO:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildChipTono(
                      label: 'Amable',
                      icono: Icons.sentiment_satisfied_alt_rounded,
                      seleccionado: _tono == TonoCobro.amable,
                      cardBg: cardBg,
                      cardBorder: cardBorder,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: () => setState(() => _tono = TonoCobro.amable),
                    ),
                    const SizedBox(width: 8),
                    _buildChipTono(
                      label: 'Quincena',
                      icono: Icons.calendar_month_rounded,
                      seleccionado: _tono == TonoCobro.quincena,
                      cardBg: cardBg,
                      cardBorder: cardBorder,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: () => setState(() => _tono = TonoCobro.quincena),
                    ),
                    const SizedBox(width: 8),
                    _buildChipTono(
                      label: 'Formal',
                      icono: Icons.priority_high_rounded,
                      seleccionado: _tono == TonoCobro.formal,
                      cardBg: cardBg,
                      cardBorder: cardBorder,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onTap: () => setState(() => _tono = TonoCobro.formal),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Opciones adicionales (Switches)
                Text(
                  '2. CONTENIDO DEL MENSAJE:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        dense: true,
                        title: Text(
                          'Incluir detalle de compras fiadas',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                        subtitle: Text(
                          _cargando
                              ? 'Cargando compras...'
                              : (_compras.isNotEmpty ? '${_compras.length} compras recientes registradas' : 'Sin compras detalladas'),
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                        value: _incluirProductos,
                        activeThumbColor: const Color(0xFF25D366),
                        onChanged: _compras.isNotEmpty ? (val) => setState(() => _incluirProductos = val) : null,
                      ),
                      Divider(height: 1, color: cardBorder),
                      SwitchListTile(
                        dense: true,
                        title: Text(
                          'Indicar medios de pago (Efectivo y QR)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                        ),
                        subtitle: Text(
                          'Recuerda al cliente que puede pagar en efectivo o por QR',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                        value: _incluirQr,
                        activeThumbColor: const Color(0xFF25D366),
                        onChanged: (val) => setState(() => _incluirQr = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Vista previa estilo chat de WhatsApp
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '3. VISTA PREVIA DEL WHATSAPP:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copiar texto', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        await CobroWhatsAppFormatter.copiarAlPortapapeles(mensajeActual);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Mensaje copiado al portapapeles')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Burbuja de chat WhatsApp
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: esOscuro ? const Color(0xFF143E2C) : const Color(0xFFE7FBD3),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: esOscuro ? const Color(0xFF25D366).withAlpha(60) : const Color(0xFFC8E6C9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    mensajeActual,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: esOscuro ? const Color(0xFFE9EDEF) : const Color(0xFF1B2E1E),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // 4. Botón inferior de acción masiva
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(top: BorderSide(color: cardBorder)),
              boxShadow: esOscuro ? null : [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // Verde oficial WhatsApp
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.send_rounded, size: 22),
                label: const Text(
                  'ABRIR WHATSAPP CON MENSAJE',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                ),
                onPressed: () async {
                  final exito = await CobroWhatsAppFormatter.enviarWhatsApp(
                    c,
                    mensaje: mensajeActual,
                  );

                  if (!context.mounted) return;
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        exito
                            ? 'Abriendo WhatsApp de ${c.nombre}...'
                            : 'Mensaje copiado al portapapeles para enviar.',
                      ),
                      backgroundColor: const Color(0xFF1E3A2F),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipTono({
    required String label,
    required IconData icono,
    required bool seleccionado,
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: seleccionado ? const Color(0xFF15803D) : cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: seleccionado ? const Color(0xFF15803D) : cardBorder,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icono,
                size: 16,
                color: seleccionado ? Colors.white : textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: seleccionado ? Colors.white : textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
