import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// A small icon button styled for the glassmorphism UI.
class IconButtonSmall extends StatefulWidget {
  const IconButtonSmall({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 20.0,
    this.iconSize = 14.0,
    this.tooltip,
    this.color,
    this.hoverColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final String? tooltip;
  final Color? color;
  final Color? hoverColor;

  @override
  State<IconButtonSmall> createState() => _IconButtonSmallState();
}

class _IconButtonSmallState extends State<IconButtonSmall> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color:
                _isHovering
                    ? (widget.hoverColor ?? AppColors.hoverHighlight)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: widget.color ?? AppColors.foreground,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        child: button,
      );
    }
    return button;
  }
}
