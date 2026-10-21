import 'package:flutter/services.dart';

/// Utilidad centralizada de respuesta táctil háptica (Haptic Feedback)
/// Diseñada para proporcionar sensaciones táctiles nativas y ultra-rápidas
/// sin bloquear el hilo de la interfaz de usuario en teléfonos base como el Tecno Spark 8C.
class AppHaptics {
  AppHaptics._();

  /// Vibración muy suave y corta (ej. al presionar botones rápidos, agregar al carrito, cambiar toggle)
  static void light() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Vibración de confirmación media (ej. al registrar recarga, completar cobro o guardar compra)
  static void medium() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Vibración de selección rápida (ej. al alternar entre tabs, chips o filtros de lista)
  static void selection() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Vibración intensa para acciones críticas o irreversibles
  static void heavy() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Vibración de éxito o confirmación completada
  static void success() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }
}
