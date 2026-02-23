import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// A widget that shows a highlight color on hover.
class HoverHighlight extends StatefulWidget {
  const HoverHighlight({
    super.key,
    required this.child,
    this.hoverColor,
    this.borderRadius,
    this.onTap,
    this.onDoubleTap,
    this.cursor = SystemMouseCursors.click,
  });

  final Widget child;
  final Color? hoverColor;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final MouseCursor cursor;

  @override
  State<HoverHighlight> createState() => _HoverHighlightState();
}

class _HoverHighlightState extends State<HoverHighlight> {
  bool _isHovering = false;
  DateTime _lastTapTime = DateTime(0);

  void _handleTap() {
    final now = DateTime.now();
    widget.onTap?.call();
    if (widget.onDoubleTap != null &&
        now.difference(_lastTapTime).inMilliseconds < 300) {
      widget.onDoubleTap!();
    }
    _lastTapTime = now;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          decoration: BoxDecoration(
            color:
                _isHovering
                    ? (widget.hoverColor ?? AppColors.listHoverBackground)
                    : Colors.transparent,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(6),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
