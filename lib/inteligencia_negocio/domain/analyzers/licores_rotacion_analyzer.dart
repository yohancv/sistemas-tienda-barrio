import 'package:flutter/material.dart';
import '../../data/models/insight_model.dart';

class LicoresRotacionAnalyzer {
  /// Analiza bebidas y licores aplicando las 3 categorías comerciales acordadas
  static List<InsightModel> analizar({
    required List<Map<String, dynamic>> productosBebidas,
    required Set<String> idsSilenciados,
  }) {
    if (productosBebidas.isEmpty) return [];

    final now = DateTime.now();
    final List<InsightModel> insights = [];

    for (final p in productosBebidas) {
      final id = p['id'] as String;
      if (idsSilenciados.contains(id)) continue;

      final nombre = p['nombre'] as String;
      final subcat = (p['subcategoria'] as String? ?? '').toLowerCase();
      final cat = (p['categoria'] as String? ?? '').toLowerCase();
      final stockActual = (p['stock_actual'] as num).toDouble();

      final ultimaVentaStr = p['ultima_venta'] as String?;
      final DateTime? ultimaVenta = ultimaVentaStr != null ? DateTime.tryParse(ultimaVentaStr) : null;
      final int diasSinVenta = ultimaVenta != null ? now.difference(ultimaVenta).inDays : 30;

      final bool esCervezaOHielo = cat.contains('cerveza') ||
          subcat.contains('cerveza') ||
          nombre.toLowerCase().contains('hielo') ||
          nombre.toLowerCase().contains('paceña') ||
          nombre.toLowerCase().contains('huari') ||
          nombre.toLowerCase().contains('taquiña');

      final bool esDestiladoPopular = subcat.contains('ron') ||
          subcat.contains('singani') ||
          subcat.contains('fernet') ||
          nombre.toLowerCase().contains('ron') ||
          nombre.toLowerCase().contains('singani') ||
          nombre.toLowerCase().contains('fernet');

      final bool esPremiumVitrina = subcat.contains('whisky') ||
          subcat.contains('tequila') ||
          subcat.contains('vodka') ||
          nombre.toLowerCase().contains('whisky') ||
          nombre.toLowerCase().contains('tequila');

      // -------------------------------------------------------------
      // NIVEL 1: Cervezas & Hielo (Rotación rápida de fin de semana)
      // -------------------------------------------------------------
      if (esCervezaOHielo && diasSinVenta >= 14 && stockActual >= 4) {
        insights.add(
          InsightModel(
            id: 'licor_cerveza_$id',
            categoria: CategoriaInsight.rotacionLicores,
            urgencia: NivelUrgencia.atencion,
            titulo: 'Cerveza sin rotación: $nombre',
            badgeTexto: '$diasSinVenta días sin salir',
            badgeColor: const Color(0xFFF59E0B),
            icono: Icons.sports_bar_rounded,
            descripcion:
                'Lleva más de 2 fines de semana sin registrar ventas. Revisa si está bien fría en el exhibidor, si hay hielo disponible o si el precio quedó desfasado.',
            accionLabel: '❄️ ES DE TEMPORADA / IGNORAR',
            tipoAccion: TipoAccionInsight.silenciarEstacional,
            entidadId: id,
            scorePrioridad: 78,
          ),
        );
      }

      // -------------------------------------------------------------
      // NIVEL 2: Destilados Populares (Sugerencia comercial de Combo)
      // -------------------------------------------------------------
      else if (esDestiladoPopular && diasSinVenta >= 25 && stockActual >= 2) {
        String sugerenciaCombo;
        if (nombre.toLowerCase().contains('singani')) {
          sugerenciaCombo = 'Arma un "Combo Chuflay" en mostrador: $nombre + 2 Sprite 2L + Bolsa de Hielo.';
        } else if (nombre.toLowerCase().contains('fernet')) {
          sugerenciaCombo = 'Arma un "Combo Fernet" en mostrador: $nombre + 2 Coca Cola 2L + Bolsa de Hielo.';
        } else {
          sugerenciaCombo = 'Arma un "Combo Rumbero": $nombre emparejado con Coca Cola 2L para incentivar la venta del fin de semana.';
        }

        insights.add(
          InsightModel(
            id: 'licor_combo_$id',
            categoria: CategoriaInsight.rotacionLicores,
            urgencia: NivelUrgencia.oportunidad,
            titulo: 'Oportunidad de Combo: $nombre',
            badgeTexto: 'Impulsar salida',
            badgeColor: const Color(0xFF00E676),
            icono: Icons.wine_bar_rounded,
            descripcion:
                '$nombre lleva $diasSinVenta días sin rotar. $sugerenciaCombo El cliente nocturno busca la conveniencia de llevarse el combo listo.',
            accionLabel: '❄️ ES DE TEMPORADA / IGNORAR',
            tipoAccion: TipoAccionInsight.silenciarEstacional,
            entidadId: id,
            scorePrioridad: 76,
          ),
        );
      }

      // -------------------------------------------------------------
      // NIVEL 3: Licores Premium de Vitrina (Tolerancia 75-90 días)
      // -------------------------------------------------------------
      else if (esPremiumVitrina && diasSinVenta >= 75 && stockActual >= 2) {
        insights.add(
          InsightModel(
            id: 'licor_vitrina_$id',
            categoria: CategoriaInsight.rotacionLicores,
            urgencia: NivelUrgencia.atencion,
            titulo: 'Licor de vitrina estancado: $nombre',
            badgeTexto: '$diasSinVenta días en vitrina',
            badgeColor: const Color(0xFF64748B),
            icono: Icons.liquor_rounded,
            descripcion:
                'Es un producto de ocasión especial pero lleva más de 2 meses y medio sin movimiento. Considera destacarlo para regalos de fin de semana o eventos.',
            accionLabel: '❄️ ES DE TEMPORADA / IGNORAR',
            tipoAccion: TipoAccionInsight.silenciarEstacional,
            entidadId: id,
            scorePrioridad: 55,
          ),
        );
      }
    }

    return insights;
  }
}
