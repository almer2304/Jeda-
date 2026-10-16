import 'package:flutter/material.dart';

/// Predictable corner radii for Jeda components.
class JedaRadii {
  JedaRadii._();

  static const double r8 = 8.0;
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r20 = 20.0;
  static const double r24 = 24.0;
  static const double rFull = 999.0;

  static const BorderRadius borderR8 = BorderRadius.all(Radius.circular(r8));
  static const BorderRadius borderR12 = BorderRadius.all(Radius.circular(r12));
  static const BorderRadius borderR16 = BorderRadius.all(Radius.circular(r16));
  static const BorderRadius borderR20 = BorderRadius.all(Radius.circular(r20));
  static const BorderRadius borderR24 = BorderRadius.all(Radius.circular(r24));
  static const BorderRadius borderFull = BorderRadius.all(Radius.circular(rFull));

  static const BorderRadius sheetTop = BorderRadius.vertical(top: Radius.circular(r24));
}
