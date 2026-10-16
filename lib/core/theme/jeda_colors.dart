import 'package:flutter/material.dart';

/// Single source of truth for Jeda Design System color tokens.
/// Adheres to Calm Technology principles: warm, grounded, non-judgmental.
class JedaColors {
  JedaColors._();

  // Primary & Accent
  static const Color primary = Color(0xFF587563);
  static const Color primaryDark = Color(0xFF344E40);
  static const Color primarySoft = Color(0xFFE4EDE5);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF7F6F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFEFF1E9);

  // Typography & Content
  static const Color textPrimary = Color(0xFF242B26);
  static const Color textSecondary = Color(0xFF68736B);
  static const Color textTertiary = Color(0xFF9AA39C);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Outlines & Dividers
  static const Color border = Color(0xFFE2E6DE);
  static const Color borderSubtle = Color(0xFFECEFE8);

  // Semantic Status (Purpose-driven, never purely decorative)
  static const Color success = Color(0xFF397653);
  static const Color successSoft = Color(0xFFE5EFE9);
  
  static const Color warning = Color(0xFF986A28);
  static const Color warningSoft = Color(0xFFFBF4E8);
  
  static const Color error = Color(0xFFB64B45);
  static const Color errorSoft = Color(0xFFFAEBEA);
  
  static const Color information = Color(0xFF456C8B);
  static const Color informationSoft = Color(0xFFE9F1F6);
}
