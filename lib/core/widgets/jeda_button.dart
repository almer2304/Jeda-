import 'package:flutter/material.dart';
import '../theme/jeda_colors.dart';
import '../theme/jeda_radii.dart';
import '../theme/jeda_typography.dart';

enum JedaButtonVariant { primary, secondary, ghost, destructive }

class JedaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final JedaButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final double height;

  const JedaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = JedaButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case JedaButtonVariant.primary:
        bg = JedaColors.primary;
        fg = JedaColors.textOnPrimary;
        break;
      case JedaButtonVariant.secondary:
        bg = JedaColors.surface;
        fg = JedaColors.textPrimary;
        border = const BorderSide(color: JedaColors.border, width: 1.0);
        break;
      case JedaButtonVariant.ghost:
        bg = Colors.transparent;
        fg = JedaColors.primary;
        break;
      case JedaButtonVariant.destructive:
        bg = JedaColors.errorSoft;
        fg = JedaColors.error;
        border = const BorderSide(color: Color(0xFFF2CBC8), width: 1.0);
        break;
    }

    final effectiveOnPressed = isLoading ? null : onPressed;

    Widget content;
    if (isLoading) {
      content = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: fg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: JedaTypography.labelBold.copyWith(
                color: effectiveOnPressed == null ? fg.withValues(alpha: 0.5) : fg,
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: height,
      child: Material(
        color: effectiveOnPressed == null && variant == JedaButtonVariant.primary
            ? bg.withValues(alpha: 0.6)
            : bg,
        shape: RoundedRectangleBorder(
          borderRadius: JedaRadii.borderR12,
          side: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: effectiveOnPressed,
          splashColor: fg.withValues(alpha: 0.12),
          highlightColor: fg.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
