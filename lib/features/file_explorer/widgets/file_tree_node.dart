import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/layout_constants.dart';
import '../../../core/providers/file_icon_theme_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../editor_area/presentation/editor_area_provider.dart';
import '../models/file_node.dart';
import 'file_icon.dart';

class FileTreeNodeWidget extends ConsumerStatefulWidget {
  const FileTreeNodeWidget({
    super.key,
    required this.node,
    required this.isSelected,
    required this.onTap,
    this.onSecondaryTapUp,
  });

  final FileNode node;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(TapUpDetails details)? onSecondaryTapUp;

  @override
  ConsumerState<FileTreeNodeWidget> createState() => _FileTreeNodeWidgetState();
}

class _FileTreeNodeWidgetState extends ConsumerState<FileTreeNodeWidget> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(editorAreaProvider);
    final iconTheme = ref.watch(fileIconThemeProvider);
    final diagnostics = ref
        .read(editorAreaProvider.notifier)
        .diagnosticsForPath(
          widget.node.path,
          recursive: widget.node.isDirectory,
        );
    final indent = widget.node.depth * LayoutConstants.fileTreeIndent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: widget.onSecondaryTapUp,
        child: Container(
          height: LayoutConstants.fileTreeItemHeight,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color:
                widget.isSelected
                    ? AppColors.listActiveSelectionBackground
                    : _isHovering
                    ? AppColors.listHoverBackground
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(
              LayoutConstants.borderRadiusSmall,
            ),
          ),
          padding: EdgeInsets.only(left: 4 + indent),
          child: Row(
            children: [
              // Expand/collapse arrow for directories
              if (widget.node.isDirectory)
                Icon(
                  widget.node.isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 16,
                  color: AppColors.secondaryForeground,
                )
              else
                const SizedBox(width: 16),
              const SizedBox(width: 2),
              // File/folder icon
              FileIcon(
                name: widget.node.name,
                isDirectory: widget.node.isDirectory,
                isExpanded: widget.node.isExpanded,
                themeMode: iconTheme.themeMode,
                colorTheme: iconTheme.colorTheme,
              ),
              const SizedBox(width: 4),
              // Name
              Expanded(
                child: Text(
                  widget.node.name,
                  style: context.trStyle(
                    TextStyle(
                      fontSize: 13,
                      color:
                          widget.isSelected
                              ? AppColors.listActiveSelectionForeground
                              : AppColors.sideBarForeground,
                    ),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (diagnostics.errorCount > 0 || diagnostics.warningCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (diagnostics.errorCount > 0)
                        _SeverityBadge(
                          icon: Icons.error_outline,
                          count: diagnostics.errorCount,
                          color: AppColors.error,
                        ),
                      if (diagnostics.errorCount > 0 && diagnostics.warningCount > 0)
                        const SizedBox(width: 4),
                      if (diagnostics.warningCount > 0)
                        _SeverityBadge(
                          icon: Icons.warning_amber_outlined,
                          count: diagnostics.warningCount,
                          color: Colors.amber,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({
    required this.icon,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: context.trStyle(
              TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
