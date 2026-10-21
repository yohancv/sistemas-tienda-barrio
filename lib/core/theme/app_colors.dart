import 'package:flutter/material.dart';

/// Paleta de colores unificada para LicorPOS
/// Diseñada con soporte para:
/// 1. "Pure Clean Retail" (Modo Claro - Shopify / Apple Store)
/// 2. "Midnight Obsidian POS" (Modo Oscuro - Terminal de alta gama)
class AppColors {
  AppColors._();

  // Primarios de Pure Clean Retail
  static const Color primary = Color(0xFF2563EB); // Azul ultramar retail moderno
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color secondary = Color(0xFF0D9488); // Teal accesible
  static const Color retailBlue = Color(0xFF2563EB); // Alias oficial Pure Clean Retail
  static const Color retailGreen = Color(0xFF16A34A); // Alias oficial Pure Clean Retail

  // Estados y acciones
  static const Color success = Color(0xFF16A34A); // Verde esmeralda retail para confirmación / ventas / abonos
  static const Color danger = Color(0xFFDC2626); // Rojo alerta / límite de fiado
  static const Color warning = Color(0xFFD97706); // Ámbar advertencias
  static const Color info = Color(0xFF2563EB); // Azul informativo
  static const Color whatsapp = Color(0xFF25D366); // Verde corporativo WhatsApp

  // Fondos y superficies (Modo Claro - Pure Clean Retail)
  static const Color background = Color(0xFFF8FAFC); // Slate 50 cálido y descansado
  static const Color surface = Color(0xFFFFFFFF); // Blanco puro
  static const Color surfaceMuted = Color(0xFFF1F5F9); // Slate 100

  // Textos de alta legibilidad
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900 casi negro para máximo contraste
  static const Color textSecondary = Color(0xFF334155); // Slate 700
  static const Color textMuted = Color(0xFF64748B); // Slate 500

  // Bordes y divisores
  static const Color border = Color(0xFFE2E8F0); // Slate 200 limpio y nítido
  static const Color borderStrong = Color(0xFFCBD5E1); // Slate 300

  // Banners y gradientes de Pure Clean Retail
  static const Color bannerFiadosStart = Color(0xFF0F172A); // Slate 900
  static const Color bannerFiadosEnd = Color(0xFF1E293B); // Slate 800

  // Tokens para Modo Oscuro: "Modern Slate Fintech" (Stripe Terminal / Clover POS)
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800 para cards y appbars
  static const Color darkSurfaceMuted = Color(0xFF334155); // Slate 700 para inputs y chips inactivos
  static const Color darkBorder = Color(0xFF334155); // Slate 700 bordes y divisores limpios
  static const Color darkBorderStrong = Color(0xFF475569); // Slate 600 bordes con énfasis
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50 máxima legibilidad
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400 subtítulos y labels
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Alias compatible
  static const Color darkTextMuted = Color(0xFF64748B); // Slate 500 placeholders
  static const Color darkAccent = Color(0xFF38BDF8); // Sky 400 acentos fintech y nav activa
  static const Color darkSuccess = Color(0xFF10B981); // Emerald 500 botones fintech / éxito
  static const Color darkSuccessBright = Color(0xFF34D399); // Emerald 400 montos monetarios en modo oscuro
  static const Color darkSuccessDark = Color(0xFF064E3B); // Emerald 950 texto sobre botones verdes
  static const Color darkBannerStart = Color(0xFF1E293B); // Slate 800 inicio banner hero
  static const Color darkBannerEnd = Color(0xFF0F172A); // Slate 900 fin banner hero
}

