import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'jeda_colors.dart';
import 'jeda_typography.dart';
import 'jeda_radii.dart';

class JedaTheme {
  JedaTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: JedaColors.background,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: JedaColors.primary,
        onPrimary: JedaColors.textOnPrimary,
        primaryContainer: JedaColors.primarySoft,
        onPrimaryContainer: JedaColors.primaryDark,
        secondary: JedaColors.primaryDark,
        onSecondary: JedaColors.textOnPrimary,
        secondaryContainer: JedaColors.surfaceSecondary,
        onSecondaryContainer: JedaColors.textPrimary,
        surface: JedaColors.surface,
        onSurface: JedaColors.textPrimary,
        error: JedaColors.error,
        onError: JedaColors.textOnPrimary,
        outline: JedaColors.border,
        outlineVariant: JedaColors.borderSubtle,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: JedaColors.background,
        foregroundColor: JedaColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: JedaTypography.heading2,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      cardTheme: const CardThemeData(
        color: JedaColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: JedaRadii.borderR16,
          side: BorderSide(color: JedaColors.border, width: 1.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: JedaColors.primary,
          foregroundColor: JedaColors.textOnPrimary,
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: JedaRadii.borderR12,
          ),
          textStyle: JedaTypography.labelBold.copyWith(color: JedaColors.textOnPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: JedaColors.textPrimary,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: JedaColors.border, width: 1.0),
          shape: const RoundedRectangleBorder(
            borderRadius: JedaRadii.borderR12,
          ),
          textStyle: JedaTypography.labelBold,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: JedaColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: const RoundedRectangleBorder(
            borderRadius: JedaRadii.borderR8,
          ),
          textStyle: JedaTypography.labelBold.copyWith(color: JedaColors.primary),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: JedaColors.border,
        thickness: 1.0,
        space: 1.0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: JedaColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: JedaTypography.bodySecondary.copyWith(color: JedaColors.textTertiary),
        labelStyle: JedaTypography.bodySecondary,
        border: const OutlineInputBorder(
          borderRadius: JedaRadii.borderR12,
          borderSide: BorderSide(color: JedaColors.border, width: 1.0),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: JedaRadii.borderR12,
          borderSide: BorderSide(color: JedaColors.border, width: 1.0),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: JedaRadii.borderR12,
          borderSide: BorderSide(color: JedaColors.primary, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: JedaRadii.borderR12,
          borderSide: BorderSide(color: JedaColors.error, width: 1.0),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: JedaRadii.borderR12,
          borderSide: BorderSide(color: JedaColors.error, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: JedaColors.surface,
        indicatorColor: JedaColors.primarySoft,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return JedaTypography.caption.copyWith(
              color: JedaColors.primaryDark,
              fontWeight: FontWeight.w600,
            );
          }
          return JedaTypography.caption.copyWith(
            color: JedaColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: JedaColors.primaryDark, size: 24);
          }
          return const IconThemeData(color: JedaColors.textSecondary, size: 24);
        }),
      ),
    );
  }
}
