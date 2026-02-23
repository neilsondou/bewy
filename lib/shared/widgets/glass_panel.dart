import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/layout_constants.dart';

/// A reusable panel container.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = LayoutConstants.borderRadius,
    this.opacity = 0.7,
    this.showBorder = true,
    this.padding,
  });

  final Widget child;
  final double borderRadius;
  final double opacity;
  final bool showBorder;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassBackground.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(borderRadius),
        border:
            showBorder ? Border.all(color: AppColors.border, width: 0.5) : null,
      ),
      padding: padding,
      child: child,
    );
  }
}
