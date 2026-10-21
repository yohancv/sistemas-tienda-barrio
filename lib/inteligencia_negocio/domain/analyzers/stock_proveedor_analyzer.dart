import 'package:flutter/material.dart';
import '../../data/models/insight_model.dart';

class StockProveedorAnalyzer {
  static const _nombresDias = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  /// Analiza quiebres de inventario y cruza con los días de visita de los distribuidores
  static List<InsightModel> analizar(List<Map<String, dynamic>> productosBajos) {
    if (productosBajos.isEmpty) return [];

    final hoyIndex = DateTime.now().weekday - 1; // 0 = Lunes, 6 = Domingo
    final mananaIndex = (hoyIndex + 1) % 7;
    final nombreManana = _nombresDias[mananaIndex];

    final List<InsightModel> insights = [];

    // Agrupamos por proveedor si existe
    final Map<String, List<Map<String, dynamic>>> porProveedor = {};
    final List<Map<String, dynamic>> sinProveedor = [];

    for (final p in productosBajos) {
      final provId = p['proveedor_id'] as String?;
      if (provId != null && provId.isNotEmpty) {
        porProveedor.putIfAbsent(provId, () => []).add(p);
      } else {
        sinProveedor.add(p);
      }
    }

    // 1. Prioridad: Proveedor que visita mañana según dias_visita
    porProveedor.forEach((provId, items) {
      final primerItem = items.first;
      final provNombre = primerItem['proveedor_nombre'] as String? ?? 'Proveedor';
      final provDias = (primerItem['proveedor_dias_visita'] as String? ?? '').toLowerCase();

      final bool visitaManana = provDias.contains(nombreManana.toLowerCase());

      final nombresProductos = items.take(2).map((it) => it['nombre'] as String).join(' y ');
      final int totalItems = items.length;
      final stockMinimo = (primerItem['stock_minimo'] as num).toDouble();
      final stockActual = (primerItem['stock_actual'] as num).toDouble();

      int score = 85;
      NivelUrgencia urgencia = NivelUrgencia.atencion;
      String badgeTexto = '$totalItems por agotarse';
      Color badgeColor = const Color(0xFFF59E0B); // Amber

      String descripcion;
      if (visitaManana) {
        score = 98; // Máxima prioridad por visita de camión
        urgencia = NivelUrgencia.critico;
        badgeTexto = 'Camión visita mañana $nombreManana';
        badgeColor = const Color(0xFFE11D48); // Rose/Red
        descripcion = 'Mañana visita $provNombre. Tienes $nombresProductos al límite (quedan ${stockActual.toInt()} de ${stockMinimo.toInt()} mín.). Envía el pedido hoy para no quedarte sin stock.';
      } else {
        descripcion = 'Tienes $totalItems productos de $provNombre bajo stock mínimo ($nombresProductos). Prepara tu pedido para la próxima entrega.';
      }

      insights.add(
        InsightModel(
          id: 'stock_prov_$provId',
          categoria: CategoriaInsight.stockProveedor,
          urgencia: urgencia,
          titulo: visitaManana ? 'Pedido urgente a $provNombre' : 'Reposición con $provNombre',
          badgeTexto: badgeTexto,
          badgeColor: badgeColor,
          icono: Icons.local_shipping_rounded,
          descripcion: descripcion,
          accionLabel: 'PEDIR POR WHATSAPP A $provNombre',
          tipoAccion: TipoAccionInsight.abrirPedidoProveedor,
          entidadId: provId,
          metadata: {
            'proveedor_id': provId,
            'proveedor_nombre': provNombre,
            'proveedor_telefono': primerItem['proveedor_telefono'],
            'items': items,
          },
          scorePrioridad: score,
        ),
      );
    });

    // 2. Productos sin proveedor que están totalmente en cero
    for (final p in sinProveedor) {
      final stockActual = (p['stock_actual'] as num).toDouble();
      if (stockActual <= 0) {
        final nombre = p['nombre'] as String;
        insights.add(
          InsightModel(
            id: 'stock_cero_${p['id']}',
            categoria: CategoriaInsight.stockProveedor,
            urgencia: NivelUrgencia.critico,
            titulo: 'Producto Agotado: $nombre',
            badgeTexto: 'Stock en 0 un.',
            badgeColor: const Color(0xFFE11D48),
            icono: Icons.production_quantity_limits_rounded,
            descripcion: '$nombre está completamente agotado y estás perdiendo ventas de clientes que lo buscan.',
            accionLabel: 'VER EN INVENTARIO',
            tipoAccion: TipoAccionInsight.abrirEdicionProducto,
            entidadId: p['id'] as String,
            scorePrioridad: 92,
          ),
        );
      }
    }

    return insights;
  }
}
