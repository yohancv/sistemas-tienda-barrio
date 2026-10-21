import 'package:flutter/material.dart';
import '../../data/models/insight_model.dart';

class FinanzasSemanalesAnalyzer {
  /// Analiza el acumulado semanal (7 días) para evaluar la salud del negocio
  /// sin alarmar en días de venta lenta (lunes/martes).
  static List<InsightModel> analizar(Map<String, dynamic> balanceSemanal) {
    final gananciaNeta = (balanceSemanal['ganancia_neta_semana'] as num?)?.toDouble() ?? 0.0;
    final retirosPersonales = (balanceSemanal['retiros_personales_semana'] as num?)?.toDouble() ?? 0.0;
    final totalVentas = (balanceSemanal['total_ventas_semana'] as num?)?.toDouble() ?? 0.0;

    final List<InsightModel> insights = [];

    // 1. Alerta: Retiros personales superan la ganancia neta acumulada en la semana
    if (retirosPersonales > gananciaNeta && totalVentas > 0) {
      final deficit = retirosPersonales - gananciaNeta;
      final bool esCritico = deficit >= 100;

      insights.add(
        InsightModel(
          id: 'finanzas_retiros_semanales',
          categoria: CategoriaInsight.finanzasSemanales,
          urgencia: esCritico ? NivelUrgencia.critico : NivelUrgencia.atencion,
          titulo: 'Alerta Semanal: Retiros Personales',
          badgeTexto: '- Bs. ${deficit.toStringAsFixed(0)} en la semana',
          badgeColor: esCritico ? const Color(0xFFE11D48) : const Color(0xFFF59E0B),
          icono: Icons.account_balance_wallet_outlined,
          descripcion:
              'En los últimos 7 días has retirado Bs. ${retirosPersonales.toStringAsFixed(0)} para gastos de casa, superando la ganancia neta semanal de Bs. ${gananciaNeta.toStringAsFixed(0)}. Modera los retiros este fin de semana para no descapitalizar la tienda.',
          accionLabel: 'VER FLUJO DE CAJA',
          tipoAccion: TipoAccionInsight.soloLectura,
          scorePrioridad: esCritico ? 88 : 74,
          metadata: balanceSemanal,
        ),
      );
    }

    return insights;
  }
}
