import 'package:flutter/material.dart';
import '../theme/jeda_colors.dart';
import '../theme/jeda_radii.dart';
import '../theme/jeda_typography.dart';

enum JedaBadgeVariant { success, neutral, warning, error, info }

class JedaBadge extends StatelessWidget {
  final String label;
  final JedaBadgeVariant variant;
  final IconData? icon;

  const JedaBadge({
    super.key,
    required this.label,
    this.variant = JedaBadgeVariant.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (variant) {
      case JedaBadgeVariant.success:
        bg = JedaColors.successSoft;
        fg = JedaColors.success;
        break;
      case JedaBadgeVariant.neutral:
        bg = JedaColors.surfaceSecondary;
        fg = JedaColors.textSecondary;
        break;
      case JedaBadgeVariant.warning:
        bg = JedaColors.warningSoft;
        fg = JedaColors.warning;
        break;
      case JedaBadgeVariant.error:
        bg = JedaColors.errorSoft;
        fg = JedaColors.error;
        break;
      case JedaBadgeVariant.info:
        bg = JedaColors.informationSoft;
        fg = JedaColors.information;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: JedaRadii.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: JedaTypography.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
