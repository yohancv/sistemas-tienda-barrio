import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models/item_reposicion_model.dart';

class PedidoFormatter {
  /// Genera un texto ordenado y legible con formato de WhatsApp para proveedores mayoristas.
  /// Soporta empaques cerrados (cajas, paquetes, fardos) y unidades sueltas.
  static String formatearPedido({
    required List<ItemReposicion> items,
    required double totalInversion,
    String nombreTienda = 'Licorería & Tienda Familiar',
  }) {
    final now = DateTime.now();
    final fechaStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final horaStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final buffer = StringBuffer();
    buffer.writeln('📋 *PEDIDO DE REPOSICIÓN MAYORISTA*');
    buffer.writeln('🏪 *$nombreTienda*');
    buffer.writeln('📅 Fecha: $fechaStr - $horaStr');
    buffer.writeln('-----------------------------------');

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final cantStr = _formatearCantidad(item);
      final costoLabel = _formatearCostoUnitario(item);

      buffer.writeln('${i + 1}. *${item.nombre}*');
      buffer.writeln('   • Pedir: $cantStr');
      buffer.writeln('   • Costo est.: $costoLabel  ->  Subtotal: Bs. ${item.subtotalEstimado.toStringAsFixed(2)}');
      buffer.writeln();
    }

    buffer.writeln('-----------------------------------');
    buffer.writeln('📦 *Total:* ${items.length} productos');
    buffer.writeln('💰 *Inversión Total Estimada:* Bs. ${totalInversion.toStringAsFixed(2)}');
    buffer.writeln('\n_Generado desde Sistema POS Tienda de Barrio_');

    return buffer.toString();
  }

  /// Formatea la cantidad según el tipo de empaque del producto
  static String _formatearCantidad(ItemReposicion item) {
    final cant = item.cantidadAComprar;

    if (item.esEmpaqueado) {
      final cantStr = cant.truncateToDouble() == cant
          ? cant.toInt().toString()
          : cant.toStringAsFixed(1);
      final etiqueta = item.etiquetaUnidadCompra;
      final equivStr = item.equivalenciaUnidadesSueltas.truncateToDouble() == item.equivalenciaUnidadesSueltas
          ? item.equivalenciaUnidadesSueltas.toInt().toString()
          : item.equivalenciaUnidadesSueltas.toStringAsFixed(1);
      return '$cantStr $etiqueta${cant > 1 ? 's' : ''} (= $equivStr uds)';
    }

    if (item.esFraccionable) {
      final cantInt = cant.round();
      final unidad = item.producto.tipoEmpaque == 'LIBRA' ? 'libras' : 'kilos';
      return '$cantInt $unidad';
    }

    final cantStr = cant.truncateToDouble() == cant
        ? cant.toInt().toString()
        : cant.toStringAsFixed(1);
    return '$cantStr uds';
  }

  /// Formatea el costo unitario según empaque o unidad
  static String _formatearCostoUnitario(ItemReposicion item) {
    if (item.esEmpaqueado && item.costoPorUnidadCompra > 0) {
      final tipoEmpaque = item.etiquetaUnidadCompra.toLowerCase();
      return 'Bs. ${item.costoPorUnidadCompra.toStringAsFixed(2)} / $tipoEmpaque';
    }
    return 'Bs. ${item.costoMayorista.toStringAsFixed(2)} c/u';
  }

  /// Envía el texto a WhatsApp mediante el esquema universal wa.me
  static Future<bool> compartirPorWhatsApp(String texto) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texto)}');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback intent específico para Android
      final fallbackUri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(texto)}');
      if (await canLaunchUrl(fallbackUri)) {
        return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    }
    return false;
  }

  /// Copia el texto formateado al portapapeles del dispositivo
  static Future<void> copiarAlPortapapeles(String texto) async {
    await Clipboard.setData(ClipboardData(text: texto));
  }
}
