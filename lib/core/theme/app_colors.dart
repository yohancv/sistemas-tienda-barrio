import 'package:flutter/material.dart';

/// Paleta de colores de alto contraste pensada para accesibilidad
/// de usuarios mayores en dispositivos móviles.
class AppColors {
  // Primarios de alto contraste
  static const Color primary = Color(0xFF1E3A8A); // Azul profundo legible
  static const Color primaryDark = Color(0xFF172554);
  static const Color secondary = Color(0xFF0D9488); // Teal accesible

  // Estados y acciones
  static const Color success = Color(0xFF15803D); // Verde confirmación / venta
  static const Color danger = Color(0xFFB91C1C); // Rojo alerta / límite de fiado
  static const Color warning = Color(0xFFD97706); // Ámbar advertencias
  static const Color info = Color(0xFF2563EB); // Azul informativo

  // Fondos y superficies
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);

  // Textos de alta legibilidad
  static const Color textPrimary = Color(0xFF0F172A); // Casi negro para máximo contraste
  static const Color textSecondary = Color(0xFF334155);
  static const Color textMuted = Color(0xFF64748B);

  // Bordes y divisores
  static const Color border = Color(0xFFCBD5E1);
  static const Color borderStrong = Color(0xFF94A3B8);
}
