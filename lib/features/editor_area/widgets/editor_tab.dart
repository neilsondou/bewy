import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/layout_constants.dart';
import '../../../shared/widgets/icon_button_small.dart';
import '../models/editor_tab_model.dart';
import '../presentation/editor_area_provider.dart';

const int _kMiddleMouseButton = 4;

class EditorTab extends ConsumerStatefulWidget {
  const EditorTab({
    super.key,
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
    this.onSecondaryTapUp,
  });

  final EditorTabModel tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final void Function(TapUpDetails details)? onSecondaryTapUp;

  @override
  ConsumerState<EditorTab> createState() => _EditorTabState();
}

class _EditorTabState extends ConsumerState<EditorTab> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    // Watch the provider to get notified when modified state changes.
    ref.watch(editorAreaProvider);
    final isModified = ref
        .read(editorAreaProvider.notifier)
        .isModified(widget.tab.id);
    final diagnostics =
        widget.tab.filePath == null
            ? const FileDiagnosticsSummary(
              errorCount: 0,
              warningCount: 0,
              infoCount: 0,
            )
            : ref
                .read(editorAreaProvider.notifier)
                .diagnosticsForPath(widget.tab.filePath!, recursive: false);
    final isPinned = widget.tab.isPinned;
    final isSnapshot = ref
        .read(editorAreaProvider.notifier)
        .isSnapshotTab(widget.tab.id);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Listener(
        onPointerDown: (event) {
          if (event.buttons == _kMiddleMouseButton) {
            widget.onClose();
          }
        },
        child: GestureDetector(
          onTap: widget.onTap,
          onSecondaryTapUp: widget.onSecondaryTapUp,
          child: Container(
            height: LayoutConstants.tabBarHeight,
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color:
                  widget.isActive
                      ? AppColors.tabActiveBackground
                      : _isHovering
                      ? AppColors.hoverHighlight
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPinned) ...[
                  Icon(
                    Icons.push_pin,
                    size: 12,
                    color: AppColors.secondaryForeground,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  widget.tab.fileName,
                  style:
                      widget.isActive
                          ? AppTextStyles.tabActive
                          : AppTextStyles.tabInactive,
                ),
                const SizedBox(width: 8),
                if (!isPinned && diagnostics.errorCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${diagnostics.errorCount}',
                      style: AppTextStyles.uiSmall.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                if (isSnapshot && (_isHovering || widget.isActive))
                  _RestoreButton(
                    onTap: () => ref
                        .read(editorAreaProvider.notifier)
                        .restoreTimelineVersion(widget.tab.id),
                  ),
                if (isPinned)
                  // Pinned tabs: no close button, no modified indicator.
                  const SizedBox(width: 16)
                else if (isModified && !_isHovering)
                  Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.modifiedIndicator,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                else if (_isHovering || widget.isActive)
                  IconButtonSmall(
                    icon: Icons.close,
                    onPressed: widget.onClose,
                    size: 16,
                    iconSize: 12,
                  )
                else
                  const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _RestoreButton extends StatefulWidget {
  const _RestoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_RestoreButton> createState() => _RestoreButtonState();
}

class _RestoreButtonState extends State<_RestoreButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Restore this version',
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _hovering
                  ? AppColors.accent.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Icon(
              Icons.restore,
              size: 14,
              color: _hovering ? AppColors.accent : AppColors.secondaryForeground,
            ),
          ),
        ),
      ),
    );
  }
}
