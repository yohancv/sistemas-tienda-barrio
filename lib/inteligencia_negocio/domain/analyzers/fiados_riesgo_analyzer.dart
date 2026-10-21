import 'package:flutter/material.dart';
import '../../data/models/insight_model.dart';

class FiadosRiesgoAnalyzer {
  /// Analiza vecinos con cuentas por cobrar y detecta moras superiores a 15 días
  static List<InsightModel> analizar(List<Map<String, dynamic>> deudores) {
    if (deudores.isEmpty) return [];

    final List<InsightModel> insights = [];

    for (final d in deudores) {
      final id = d['id'] as String;
      final nombre = d['nombre'] as String;
      final saldo = (d['saldo_actual'] as num).toDouble();
      final diasSinMovimiento = d['dias_sin_movimiento'] as int? ?? 0;

      // Solo evaluamos clientes con saldo pendiente y más de 15 días sin abonar
      if (saldo <= 0 || diasSinMovimiento < 15) continue;

      final bool esCritico = diasSinMovimiento >= 20 || saldo >= 100;
      final int score = 75 + (diasSinMovimiento >= 20 ? 15 : 0) + (saldo >= 100 ? 5 : 0);

      insights.add(
        InsightModel(
          id: 'fiado_mora_$id',
          categoria: CategoriaInsight.cobranzaFiados,
          urgencia: esCritico ? NivelUrgencia.critico : NivelUrgencia.atencion,
          titulo: 'Cobro pendiente: $nombre',
          badgeTexto: '$diasSinMovimiento días sin abonar',
          badgeColor: esCritico ? const Color(0xFFE11D48) : const Color(0xFFF59E0B),
          icono: Icons.mark_chat_unread_rounded,
          descripcion:
              '$nombre tiene una cuenta pendiente de Bs. ${saldo.toStringAsFixed(2)} sin registrar abonos hace $diasSinMovimiento días. Enviar un recordatorio por WhatsApp asegura tu liquidez.',
          accionLabel: 'COBRAR POR WHATSAPP (BS. ${saldo.toStringAsFixed(0)})',
          tipoAccion: TipoAccionInsight.abrirCobroVecino,
          entidadId: id,
          metadata: d,
          scorePrioridad: score,
        ),
      );
    }

    return insights;
  }
}
