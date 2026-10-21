import 'package:flutter/material.dart';
import '../data/models/insight_model.dart';
import '../data/repositories/bi_analytics_repository.dart';
import 'analyzers/fiados_riesgo_analyzer.dart';
import 'analyzers/finanzas_semanales_analyzer.dart';
import 'analyzers/licores_rotacion_analyzer.dart';
import 'analyzers/stock_proveedor_analyzer.dart';

class SmartBusinessEngine {
  final BiAnalyticsRepository _repo;

  SmartBusinessEngine([BiAnalyticsRepository? repo])
      : _repo = repo ?? BiAnalyticsRepository();

  /// Ejecuta todas las reglas de negocio analíticas en paralelo sobre SQLite
  /// y retorna el Top 3-4 de sugerencias ordenadas por impacto financiero.
  Future<List<InsightModel>> generarSugerencias(String tenantId) async {
    // 1. Extraer métricas desde SQLite
    final stockBajosFuture = _repo.obtenerProductosStockCritico();
    final balanceSemanalFuture = _repo.obtenerBalanceSemanal(tenantId);
    final bebidasFuture = _repo.obtenerRotacionBebidasYLicores();
    final deudoresFuture = _repo.obtenerDeudoresConAntiguedad();
    final silenciadosFuture = _repo.obtenerIdsSilenciados();

    final stockBajos = await stockBajosFuture;
    final balanceSemanal = await balanceSemanalFuture;
    final bebidas = await bebidasFuture;
    final deudores = await deudoresFuture;
    final silenciados = await silenciadosFuture;

    // 2. Procesar a través de los 4 analizadores especializados
    final insights = <InsightModel>[];

    // Analizador 1: Stock y Proveedores
    insights.addAll(StockProveedorAnalyzer.analizar(stockBajos));

    // Analizador 2: Finanzas Semanales (Módulo D: Retiros vs Ganancia de 7 días)
    insights.addAll(FinanzasSemanalesAnalyzer.analizar(balanceSemanal));

    // Analizador 3: Licores y Bebidas (Módulo E: Cervezas, Combos y Vitrina)
    insights.addAll(LicoresRotacionAnalyzer.analizar(
      productosBebidas: bebidas,
      idsSilenciados: silenciados,
    ));

    // Analizador 4: Cobranza a Vecinos Morosos (> 15 días)
    insights.addAll(FiadosRiesgoAnalyzer.analizar(deudores));

    // 3. Si no hay alertas, generamos el estado de salud comercial 100% al día
    if (insights.isEmpty) {
      return [
        const InsightModel(
          id: 'negocio_saludable_100',
          categoria: CategoriaInsight.saludComercial,
          urgencia: NivelUrgencia.oportunidad,
          titulo: '¡Tienda 100% al Día y Saludable!',
          badgeTexto: 'Sin Alertas Críticas',
          badgeColor: Color(0xFF00E676),
          icono: Icons.verified_rounded,
          descripcion:
              'No tienes productos por agotarse, no hay fiados con más de 15 días sin pagar y tus retiros están dentro de la ganancia semanal. ¡Excelente control de negocio!',
          accionLabel: 'TODO EN ORDEN',
          tipoAccion: TipoAccionInsight.soloLectura,
          scorePrioridad: 100,
        ),
      ];
    }

    // 4. Ordenar por score de prioridad descendente
    insights.sort((a, b) => b.scorePrioridad.compareTo(a.scorePrioridad));

    // 5. Retornar las 3 o 4 mejores sugerencias de mayor impacto
    return insights.take(4).toList();
  }

  /// Silencia un producto marcado como estacional
  Future<void> silenciarProducto(String productoId) async {
    await _repo.silenciarProductoEstacional(productoId);
  }
}
