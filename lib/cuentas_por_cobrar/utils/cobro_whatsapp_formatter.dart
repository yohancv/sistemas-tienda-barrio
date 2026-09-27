import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models/cliente_model.dart';

class CobroWhatsAppFormatter {
  /// Genera un mensaje amable, respetuoso y formal para recordar el estado de cuenta
  static String formatearMensajeCobro({
    required Cliente cliente,
    String nombreTienda = 'Licorería & Tienda Familiar',
  }) {
    final now = DateTime.now();
    final fechaStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final buffer = StringBuffer();
    buffer.writeln('👋 *Estimad@ ${cliente.nombre}*, un saludo cordial de parte de *$nombreTienda*.');
    buffer.writeln('Le compartimos el resumen de su cuenta de confianza:');
    buffer.writeln('-----------------------------------');
    buffer.writeln('💰 *Saldo pendiente por pagar:* Bs. ${cliente.saldoActual.toStringAsFixed(2)}');
    buffer.writeln('📅 *Fecha de corte:* $fechaStr');
    buffer.writeln('-----------------------------------');
    buffer.writeln('Agradecemos mucho su preferencia y puntualidad. ¡Que tenga un excelente día!');

    return buffer.toString();
  }

  /// Lanza WhatsApp con el mensaje cargado directamente al chat del cliente
  static Future<bool> enviarWhatsApp(Cliente cliente) async {
    final mensaje = formatearMensajeCobro(cliente: cliente);
    final cleanPhone = (cliente.telefono ?? '').replaceAll(RegExp(r'[^0-9]'), '');

    // Si tiene número, se abre directamente su chat
    final urlStr = cleanPhone.isNotEmpty
        ? 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(mensaje)}'
        : 'https://wa.me/?text=${Uri.encodeComponent(mensaje)}';

    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback intent específico para Android
      final fallbackUri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(mensaje)}');
      if (await canLaunchUrl(fallbackUri)) {
        return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    }
    return false;
  }

  static Future<void> copiarAlPortapapeles(String texto) async {
    await Clipboard.setData(ClipboardData(text: texto));
  }
}
