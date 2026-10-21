import 'package:flutter/material.dart';

enum CategoriaInsight {
  stockProveedor,       // Quiebres de stock o pedido al camión repartidor
  finanzasSemanales,    // Balance semanal de retiros del dueño vs ganancia
  rotacionLicores,      // Rotación de cervezas, combos de destilados o vitrina
  cobranzaFiados,       // Deudores con mora > 15 días
  saludComercial,       // Felicitación cuando todo está al día
}

enum NivelUrgencia {
  critico,    // Rojo / Alerta: Riesgo de perder plata o venta
  atencion,   // Naranja / Precaución: Revisar en los próximos días
  oportunidad,// Verde / Celeste: Dinero extra, combo o reposición a tiempo
}

enum TipoAccionInsight {
  abrirPedidoProveedor, // Abre WhatsApp con el pedido mayorista formateado
  abrirCobroVecino,     // Abre modal de cobro por WhatsApp para el deudor
  abrirEdicionProducto, // Abre formulario del producto para ajustar precio/stock
  silenciarEstacional,  // Marca el producto como estacional para no alertar
  soloLectura,          // Información o felicitación
}

/// Modelo de sugerencia comercial inteligente generada por el Smart Engine local
class InsightModel {
  final String id;
  final CategoriaInsight categoria;
  final NivelUrgencia urgencia;
  final String titulo;
  final String badgeTexto;
  final Color badgeColor;
  final IconData icono;
  final String descripcion;
  final String accionLabel;
  final TipoAccionInsight tipoAccion;
  final String? entidadId; // ID de producto, proveedor o cliente
  final Map<String, dynamic> metadata;
  final int scorePrioridad; // 0 a 100 para ordenar las más urgentes

  const InsightModel({
    required this.id,
    required this.categoria,
    required this.urgencia,
    required this.titulo,
    required this.badgeTexto,
    required this.badgeColor,
    required this.icono,
    required this.descripcion,
    required this.accionLabel,
    required this.tipoAccion,
    this.entidadId,
    this.metadata = const {},
    required this.scorePrioridad,
  });

  InsightModel copyWith({
    String? id,
    CategoriaInsight? categoria,
    NivelUrgencia? urgencia,
    String? titulo,
    String? badgeTexto,
    Color? badgeColor,
    IconData? icono,
    String? descripcion,
    String? accionLabel,
    TipoAccionInsight? tipoAccion,
    String? entidadId,
    Map<String, dynamic>? metadata,
    int? scorePrioridad,
  }) {
    return InsightModel(
      id: id ?? this.id,
      categoria: categoria ?? this.categoria,
      urgencia: urgencia ?? this.urgencia,
      titulo: titulo ?? this.titulo,
      badgeTexto: badgeTexto ?? this.badgeTexto,
      badgeColor: badgeColor ?? this.badgeColor,
      icono: icono ?? this.icono,
      descripcion: descripcion ?? this.descripcion,
      accionLabel: accionLabel ?? this.accionLabel,
      tipoAccion: tipoAccion ?? this.tipoAccion,
      entidadId: entidadId ?? this.entidadId,
      metadata: metadata ?? this.metadata,
      scorePrioridad: scorePrioridad ?? this.scorePrioridad,
    );
  }
}
