import 'package:flutter/material.dart';
import '../theme/jeda_colors.dart';
import '../theme/jeda_radii.dart';
import '../theme/jeda_spacing.dart';

class JedaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;

  const JedaCard({
    super.key,
    required this.child,
    this.padding = JedaSpacing.cardPadding,
    this.onTap,
    this.backgroundColor = JedaColors.surface,
    this.borderColor = JedaColors.border,
    this.borderWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: JedaRadii.borderR16,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: JedaRadii.borderR16,
        child: InkWell(
          onTap: onTap,
          borderRadius: JedaRadii.borderR16,
          child: content,
        ),
      );
    }

    return content;
  }
}
