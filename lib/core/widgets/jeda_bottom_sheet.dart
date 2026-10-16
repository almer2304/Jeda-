import 'package:flutter/material.dart';
import '../theme/jeda_colors.dart';
import '../theme/jeda_radii.dart';
import '../theme/jeda_typography.dart';
import 'jeda_button.dart';

class JedaBottomSheet {
  JedaBottomSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Widget child,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: JedaColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: JedaRadii.sheetTop),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top drag handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: JedaColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(title, style: JedaTypography.heading3),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle, style: JedaTypography.bodySecondary),
                    ],
                    const SizedBox(height: 20),
                    child,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Batal',
    bool isDestructive = false,
    IconData? icon,
  }) {
    return show<bool>(
      context: context,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDestructive ? JedaColors.errorSoft : JedaColors.primarySoft,
                borderRadius: JedaRadii.borderR12,
              ),
              child: Icon(
                icon,
                color: isDestructive ? JedaColors.error : JedaColors.primary,
                size: 24,
              ),
            ),
          ],
          Text(message, style: JedaTypography.body.copyWith(height: 1.5)),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: JedaButton(
                  label: cancelLabel,
                  variant: JedaButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: JedaButton(
                  label: confirmLabel,
                  variant: isDestructive
                      ? JedaButtonVariant.destructive
                      : JedaButtonVariant.primary,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
