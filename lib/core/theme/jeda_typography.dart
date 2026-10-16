import 'package:flutter/material.dart';
import 'jeda_colors.dart';

/// Typography hierarchy with appropriate sp sizing, line heights, and weights.
class JedaTypography {
  JedaTypography._();

  static const TextStyle display = TextStyle(
    fontSize: 32.0,
    fontWeight: FontWeight.bold,
    height: 1.25,
    color: JedaColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle heading1 = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: JedaColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: JedaColors.textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: JedaColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.normal,
    height: 1.45,
    color: JedaColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.normal,
    height: 1.45,
    color: JedaColors.textPrimary,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.normal,
    height: 1.45,
    color: JedaColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: JedaColors.textSecondary,
  );

  static const TextStyle labelBold = TextStyle(
    fontSize: 13.0,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: JedaColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.normal,
    height: 1.35,
    color: JedaColors.textTertiary,
  );
}
