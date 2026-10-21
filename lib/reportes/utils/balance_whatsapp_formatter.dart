import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models/reporte_financiero_model.dart';

class BalanceWhatsAppFormatter {
  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];
  static const _diasSemana = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  /// Genera un resumen limpio y formal del balance para compartir por WhatsApp
  static String formatearMensajeBalance(DashboardReporteCompleto data, {String nombreTienda = 'Tienda de Barrio'}) {
    final f = data.financiero;
    final now = DateTime.now();

    String fechaLegible;
    switch (data.periodo) {
      case PeriodoFiltroReporte.hoy:
        final diaNom = _diasSemana[now.weekday - 1];
        final mesNom = _meses[now.month - 1];
        fechaLegible = 'Hoy, $diaNom ${now.day} de $mesNom';
        break;
      case PeriodoFiltroReporte.estaSemana:
        fechaLegible = 'Resumen de los últimos 7 días';
        break;
      case PeriodoFiltroReporte.esteMes:
        fechaLegible = 'Acumulado de ${_meses[now.month - 1]} ${now.year}';
        break;
    }

    final buffer = StringBuffer();
    buffer.writeln('📊 *BALANCE DE CAJA Y NEGOCIO*');
    buffer.writeln('🏪 *$nombreTienda*');
    buffer.writeln('📅 *$fechaLegible*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('💰 *DINERO REAL EN MANO:*');
    buffer.writeln('💵 Efectivo en cajón: Bs. ${f.totalDineroEnCaja.toStringAsFixed(2)}');
    buffer.writeln('📱 Cobros QR banco:   Bs. ${f.totalDineroEnBanco.toStringAsFixed(2)}');
    if (f.totalAbonosCobrados > 0) {
      buffer.writeln('🤝 Abonos de deudas:  Bs. ${f.totalAbonosCobrados.toStringAsFixed(2)}');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📦 *DESGLOSE DEL BALANCE:*');
    buffer.writeln('📥 Total cobrado:    +Bs. ${f.totalCobradoReal.toStringAsFixed(2)}');
    buffer.writeln('🏷️ Costo reposición: -Bs. ${f.costoMercaderiaCobrada.toStringAsFixed(2)}');
    if (f.totalGastosTienda > 0) {
      buffer.writeln('🛠️ Gastos de tienda: -Bs. ${f.totalGastosTienda.toStringAsFixed(2)}');
    }
    if (f.totalMermas > 0) {
      buffer.writeln('⚠️ Mermas/Pérdidas:  -Bs. ${f.totalMermas.toStringAsFixed(2)}');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    final estadoIcono = f.esBalancePositivo ? '🟢' : '🔴';
    buffer.writeln('$estadoIcono *UTILIDAD LIMPIA LIBRE: Bs. ${f.utilidadNetaBalance.toStringAsFixed(2)}*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    if (f.ventasFiadas > 0) {
      buffer.writeln('📝 *EN LA CALLE (FIADOS):*');
      buffer.writeln('⏳ Por cobrar a clientes: Bs. ${f.ventasFiadas.toStringAsFixed(2)}');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    }
    buffer.writeln('👥 *Atención:* ${f.totalTransacciones} ventas (${f.totalArticulosVendidos} productos)');
    buffer.writeln('_Reporte generado automáticamente por Sistema POS_');

    return buffer.toString();
  }

  /// Abre WhatsApp con el mensaje del balance listo para enviar, o lo copia al portapapeles
  static Future<bool> compartirBalance(DashboardReporteCompleto data) async {
    final mensaje = formatearMensajeBalance(data);
    final urlStr = 'https://wa.me/?text=${Uri.encodeComponent(mensaje)}';

    final uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    await Clipboard.setData(ClipboardData(text: mensaje));
    return false;
  }
}
