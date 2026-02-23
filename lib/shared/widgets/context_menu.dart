import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../l10n/app_localizations.dart';

/// A context menu item definition.
class ContextMenuItem {
  const ContextMenuItem({
    required this.label,
    this.subtitle,
    this.icon,
    this.shortcut,
    this.onTap,
    this.isDanger = false,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final String? shortcut;
  final VoidCallback? onTap;
  final bool isDanger;
}

/// A separator in the context menu.
class ContextMenuSeparator extends ContextMenuItem {
  const ContextMenuSeparator() : super(label: '');
}

/// Shows a custom dark-themed context menu at [position].
Future<void> showAppContextMenu(
  BuildContext context,
  Offset position,
  List<ContextMenuItem> items,
) async {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder:
        (ctx) => _ContextMenuOverlay(
          position: position,
          items: items,
          onDismiss: () => entry.remove(),
        ),
  );

  overlay.insert(entry);
}

class _ContextMenuOverlay extends StatelessWidget {
  const _ContextMenuOverlay({
    required this.position,
    required this.items,
    required this.onDismiss,
  });

  final Offset position;
  final List<ContextMenuItem> items;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const menuWidth = 220.0;
    // Estimate menu height.
    double menuHeight = 0;
    for (final item in items) {
      if (item is ContextMenuSeparator) {
        menuHeight += 9;
      } else {
        menuHeight += item.subtitle != null ? 38 : 28;
      }
    }
    menuHeight += 8; // padding

    // Adjust position to stay on screen.
    double left = position.dx;
    double top = position.dy;
    if (left + menuWidth > screenSize.width) {
      left = screenSize.width - menuWidth - 4;
    }
    if (top + menuHeight > screenSize.height) {
      top = screenSize.height - menuHeight - 4;
    }

    return Stack(
      children: [
        // Dismiss layer.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            onSecondaryTap: onDismiss,
            child: const SizedBox.expand(),
          ),
        ),
        // Menu.
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            child: Container(
              width: menuWidth,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children:
                    items.map((item) {
                      if (item is ContextMenuSeparator) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.border,
                          ),
                        );
                      }
                      return _ContextMenuItemWidget(
                        item: item,
                        onDismiss: onDismiss,
                      );
                    }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContextMenuItemWidget extends StatefulWidget {
  const _ContextMenuItemWidget({required this.item, required this.onDismiss});

  final ContextMenuItem item;
  final VoidCallback onDismiss;

  @override
  State<_ContextMenuItemWidget> createState() => _ContextMenuItemWidgetState();
}

class _ContextMenuItemWidgetState extends State<_ContextMenuItemWidget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final textColor =
        widget.item.isDanger ? AppColors.error : AppColors.foreground;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () {
          widget.onDismiss();
          widget.item.onTap?.call();
        },
        child: Container(
          height: widget.item.subtitle != null ? 38 : 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color:
                _hovering ? AppColors.listHoverBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              if (widget.item.icon != null) ...[
                Icon(
                  widget.item.icon,
                  size: 14,
                  color:
                      widget.item.isDanger
                          ? AppColors.error
                          : AppColors.secondaryForeground,
                ),
                const SizedBox(width: 8),
              ] else
                const SizedBox(width: 22),
              Expanded(
                child:
                    widget.item.subtitle != null
                        ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.item.label,
                              style: context.trStyle(
                                AppTextStyles.uiSmall.copyWith(
                                  color: textColor,
                                ),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.item.subtitle!,
                              style: context.trStyle(
                                AppTextStyles.uiSmall.copyWith(
                                  color: AppColors.mutedForeground,
                                  fontSize: 9,
                                ),
                                zhDelta: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                        : Text(
                          widget.item.label,
                          style: context.trStyle(
                            AppTextStyles.uiSmall.copyWith(color: textColor),
                          ),
                        ),
              ),
              if (widget.item.shortcut != null)
                Text(
                  widget.item.shortcut!,
                  style: context.trStyle(
                    AppTextStyles.uiSmall.copyWith(
                      color: AppColors.mutedForeground,
                      fontSize: 10,
                    ),
                    zhDelta: -0.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
