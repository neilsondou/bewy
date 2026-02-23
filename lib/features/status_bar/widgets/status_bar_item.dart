import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';

class StatusBarItem extends StatefulWidget {
  const StatusBarItem({
    super.key,
    this.icon,
    this.label,
    this.tooltip,
    this.onTap,
  });

  final IconData? icon;
  final String? label;
  final String? tooltip;
  final void Function(BuildContext itemContext)? onTap;

  @override
  State<StatusBarItem> createState() => _StatusBarItemState();
}

class _StatusBarItemState extends State<StatusBarItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final content = MouseRegion(
      cursor:
          widget.onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap != null ? () => widget.onTap!(context) : null,
        child: Container(
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color:
                _isHovering && widget.onTap != null
                    ? AppColors.listActiveSelectionBackground
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 14,
                  color: AppColors.statusBarForeground,
                ),
                if (widget.label != null) const SizedBox(width: 3),
              ],
              if (widget.label != null)
                Text(
                  widget.label!,
                  style: context.trStyle(AppTextStyles.statusBar),
                ),
            ],
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        child: content,
      );
    }
    return content;
  }
}
