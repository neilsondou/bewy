import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/layout_constants.dart';

/// A draggable divider between panels.
class ResizableDivider extends StatefulWidget {
  const ResizableDivider({
    super.key,
    required this.isHorizontal,
    required this.onDrag,
    this.onDoubleTap,
  });

  final bool isHorizontal;
  final void Function(double delta) onDrag;
  final VoidCallback? onDoubleTap;

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final isActive = _isHovering || _isDragging;

    return MouseRegion(
      cursor:
          widget.isHorizontal
              ? SystemMouseCursors.resizeRow
              : SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onDoubleTap: widget.onDoubleTap,
        onVerticalDragStart:
            widget.isHorizontal
                ? (_) => setState(() => _isDragging = true)
                : null,
        onVerticalDragUpdate:
            widget.isHorizontal
                ? (details) => widget.onDrag(details.delta.dy)
                : null,
        onVerticalDragEnd:
            widget.isHorizontal
                ? (_) => setState(() => _isDragging = false)
                : null,
        onHorizontalDragStart:
            !widget.isHorizontal
                ? (_) => setState(() => _isDragging = true)
                : null,
        onHorizontalDragUpdate:
            !widget.isHorizontal
                ? (details) => widget.onDrag(details.delta.dx)
                : null,
        onHorizontalDragEnd:
            !widget.isHorizontal
                ? (_) => setState(() => _isDragging = false)
                : null,
        child: Container(
          width:
              widget.isHorizontal
                  ? double.infinity
                  : LayoutConstants.dividerHitArea,
          height:
              widget.isHorizontal
                  ? LayoutConstants.dividerHitArea
                  : double.infinity,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width:
                  widget.isHorizontal
                      ? double.infinity
                      : LayoutConstants.dividerThickness,
              height:
                  widget.isHorizontal
                      ? LayoutConstants.dividerThickness
                      : double.infinity,
              color: isActive ? AppColors.accent : AppColors.border,
            ),
          ),
        ),
      ),
    );
  }
}
