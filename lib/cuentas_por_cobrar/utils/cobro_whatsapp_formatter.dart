import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models/cliente_model.dart';

enum TonoCobro {
  amable,      // Cordial y cercano
  quincena,    // Recordatorio de fin de mes o quincena
  formal,      // Para deudas con retraso
}

class OpcionesCobroWhatsApp {
  final TonoCobro tono;
  final bool incluirProductos;
  final bool incluirOpcionQr;
  final String nombreTienda;

  const OpcionesCobroWhatsApp({
    this.tono = TonoCobro.amable,
    this.incluirProductos = true,
    this.incluirOpcionQr = true,
    this.nombreTienda = 'Tienda de Barrio',
  });

  OpcionesCobroWhatsApp copyWith({
    TonoCobro? tono,
    bool? incluirProductos,
    bool? incluirOpcionQr,
    String? nombreTienda,
  }) {
    return OpcionesCobroWhatsApp(
      tono: tono ?? this.tono,
      incluirProductos: incluirProductos ?? this.incluirProductos,
      incluirOpcionQr: incluirOpcionQr ?? this.incluirOpcionQr,
      nombreTienda: nombreTienda ?? this.nombreTienda,
    );
  }
}

class CobroWhatsAppFormatter {
  static const _mesesCortos = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];

  /// Formatea la cantidad limpia sin la 'x': e.g. "2" o "1.5 kg"
  static String _formatearCantidad(double cant, String tipoUnidad, [String? unidadMedida]) {
    final cantStr = (cant % 1 == 0) ? cant.toInt().toString() : cant.toStringAsFixed(1);
    final tipoUpper = tipoUnidad.toUpperCase();
    if (tipoUpper == 'KILO' || tipoUpper == 'GRANEL' || tipoUpper == 'FRACCIONABLE') {
      final unidad = (unidadMedida != null && unidadMedida.trim().isNotEmpty)
          ? unidadMedida.trim()
          : 'kg';
      return '$cantStr $unidad';
    }
    if (unidadMedida != null &&
        unidadMedida.trim().isNotEmpty &&
        unidadMedida.trim().toLowerCase() != 'unidad' &&
        unidadMedida.trim().toLowerCase() != 'uds') {
      return '$cantStr ${unidadMedida.trim()}';
    }
    return cantStr;
  }

  /// Genera el texto del mensaje adaptado al tono, desglose de productos y pago por QR/Efectivo
  static String formatearMensajeCobro({
    required Cliente cliente,
    OpcionesCobroWhatsApp opciones = const OpcionesCobroWhatsApp(),
    List<Map<String, dynamic>> comprasFiadas = const [],
  }) {
    final buffer = StringBuffer();

    // 1. Saludo según el tono seleccionado
    switch (opciones.tono) {
      case TonoCobro.amable:
        buffer.writeln('👋 *Buenas tardes estimado(a) ${cliente.nombre}*, un saludo cordial de parte de *${opciones.nombreTienda}*.');
        buffer.writeln('Le compartimos con mucho gusto el resumen de su cuenta de confianza:');
        break;
      case TonoCobro.quincena:
        buffer.writeln('📅 *Buenas tardes estimado(a) ${cliente.nombre}*, un saludo de *${opciones.nombreTienda}*.');
        buffer.writeln('Aprovechando el cierre de quincena/mes, le enviamos el estado de su cuenta:');
        break;
      case TonoCobro.formal:
        buffer.writeln('📌 *Estimado(a) ${cliente.nombre}*, le saludamos de *${opciones.nombreTienda}*.');
        buffer.writeln('Nos comunicamos para recordarle cordialmente el saldo pendiente en su cuenta:');
        break;
    }

    // 2. Desglose detallado de compras fiadas (si está activado y hay datos)
    if (opciones.incluirProductos && comprasFiadas.isNotEmpty) {
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('🛒 *Compras recientes:*');

      for (final compra in comprasFiadas) {
        final fechaVenta = DateTime.tryParse(compra['fecha'] as String? ?? '') ?? DateTime.now();
        final diaMes = '${fechaVenta.day}/${_mesesCortos[fechaVenta.month - 1]}';
        final totalCompra = (compra['total'] as num).toDouble();
        final items = compra['items'] as List<dynamic>? ?? [];

        if (items.isNotEmpty) {
          // Formato solicitado: sin 'x', directo: "2 Coca Cola 2L, 1 Aceite"
          final articulosStr = items.map((it) {
            final cant = (it['cantidad'] as num).toDouble();
            final nombre = it['nombre'] as String? ?? 'Producto';
            final tipoUnidad = it['tipo_unidad'] as String? ?? 'UNIDAD';
            final unidadMedida = it['unidad_medida'] as String?;
            return '${_formatearCantidad(cant, tipoUnidad, unidadMedida)} $nombre';
          }).join(', ');

          buffer.writeln('• $diaMes: $articulosStr (Bs. ${totalCompra.toStringAsFixed(2)})');
        } else {
          buffer.writeln('• $diaMes: Compra a fiado (Bs. ${totalCompra.toStringAsFixed(2)})');
        }
      }
    }

    // 3. Monto Total Pendiente
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('💰 *SALDO PENDIENTE: Bs. ${cliente.saldoActual.toStringAsFixed(2)}*');

    // 4. Medios de Pago Exclusivos (Efectivo y QR)
    if (opciones.incluirOpcionQr) {
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('💳 *Medios de pago disponibles:*');
      buffer.writeln('💵 Efectivo en la tienda.');
      buffer.writeln('📱 Pago por QR desde su celular (avísenos para enviarle el código).');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('¡Muchas gracias por su preferencia y puntualidad! Que tenga un excelente día.');

    return buffer.toString();
  }

  /// Lanza WhatsApp con el mensaje cargado directamente al chat del cliente
  static Future<bool> enviarWhatsApp(
    Cliente cliente, {
    String? mensaje,
  }) async {
    final mensajeFinal = mensaje ?? formatearMensajeCobro(cliente: cliente);
    final cleanPhone = (cliente.telefono ?? '').replaceAll(RegExp(r'[^0-9]'), '');

    // Si tiene número boliviano o estándar, formatea con código si hace falta
    String? phoneParam;
    if (cleanPhone.isNotEmpty) {
      if (cleanPhone.length == 8) {
        phoneParam = '591$cleanPhone'; // Prefijo de Bolivia
      } else {
        phoneParam = cleanPhone;
      }
    }

    final urlStr = phoneParam != null
        ? 'https://wa.me/$phoneParam?text=${Uri.encodeComponent(mensajeFinal)}'
        : 'https://wa.me/?text=${Uri.encodeComponent(mensajeFinal)}';

    final uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // Fallback nativo
    try {
      final fallbackUri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(mensajeFinal)}');
      if (await canLaunchUrl(fallbackUri)) {
        return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    await copiarAlPortapapeles(mensajeFinal);
    return false;
  }

  /// Envía recordatorio rápido manteniendo compatibilidad con código antiguo
  static Future<bool> enviarRecordatorio({
    required Cliente cliente,
    String nombreTienda = 'Tienda de Barrio',
  }) async {
    final mensaje = formatearMensajeCobro(
      cliente: cliente,
      opciones: OpcionesCobroWhatsApp(nombreTienda: nombreTienda),
    );
    return enviarWhatsApp(cliente, mensaje: mensaje);
  }

  static Future<void> copiarAlPortapapeles(String texto) async {
    await Clipboard.setData(ClipboardData(text: texto));
  }
}
