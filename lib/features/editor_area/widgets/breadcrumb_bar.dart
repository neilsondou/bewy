import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/layout_constants.dart';
import '../../../core/providers/recent_files_provider.dart';
import '../presentation/editor_area_provider.dart';

class BreadcrumbBar extends ConsumerStatefulWidget {
  const BreadcrumbBar({super.key, this.filePath});

  final String? filePath;

  @override
  ConsumerState<BreadcrumbBar> createState() => _BreadcrumbBarState();
}

class _BreadcrumbBarState extends ConsumerState<BreadcrumbBar> {
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Build the absolute path for a given segment index.
  String _buildPath(List<String> parts, int index) {
    // On Windows paths start with a drive letter like C:
    final sub = parts.sublist(0, index + 1);
    if (sub.first.endsWith(':')) {
      return '${sub.first}\\${sub.skip(1).join('\\')}';
    }
    return '/${sub.join('/')}';
  }

  void _onSegmentTap(
    BuildContext segmentContext,
    List<String> parts,
    int index,
  ) {
    _removeOverlay();
    final dirPath = _buildPath(parts, index);
    final box = segmentContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    _overlayEntry = OverlayEntry(
      builder:
          (_) => _BreadcrumbDropdown(
            position: Offset(pos.dx, pos.dy + size.height + 2),
            dirPath: dirPath,
            onDismiss: () => _removeOverlay(),
            onFileSelected: (name, path) {
              _removeOverlay();
              ref.read(editorAreaProvider.notifier).openTab(name, path);
              ref
                  .read(recentFilesProvider.notifier)
                  .addRecent(name, path, false);
            },
          ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.filePath == null) return const SizedBox.shrink();

    final parts =
        widget.filePath!
            .replaceAll('\\', '/')
            .split('/')
            .where((p) => p.isNotEmpty)
            .toList();

    return Container(
      height: LayoutConstants.breadcrumbHeight,
      color: AppColors.breadcrumbBackground,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (int i = 0; i < parts.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: AppColors.breadcrumbForeground.withValues(alpha: 0.6),
                ),
              ),
            _BreadcrumbSegment(
              label: parts[i],
              isLast: i == parts.length - 1,
              isDirectory: i < parts.length - 1,
              onTap:
                  i < parts.length - 1
                      ? (ctx) => _onSegmentTap(ctx, parts, i)
                      : null,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single breadcrumb segment (clickable for directories)
// ---------------------------------------------------------------------------

class _BreadcrumbSegment extends StatefulWidget {
  const _BreadcrumbSegment({
    required this.label,
    required this.isLast,
    required this.isDirectory,
    this.onTap,
  });

  final String label;
  final bool isLast;
  final bool isDirectory;
  final void Function(BuildContext context)? onTap;

  @override
  State<_BreadcrumbSegment> createState() => _BreadcrumbSegmentState();
}

class _BreadcrumbSegmentState extends State<_BreadcrumbSegment> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          widget.onTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap != null ? () => widget.onTap!(context) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color:
                _hovering && widget.onTap != null
                    ? AppColors.hoverHighlight
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style:
                widget.isLast
                    ? AppTextStyles.breadcrumb.copyWith(
                      color: AppColors.breadcrumbFocusForeground,
                    )
                    : AppTextStyles.breadcrumb,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dropdown showing directory children — lazy loaded, max 5 initially
// ---------------------------------------------------------------------------

class _BreadcrumbDropdown extends StatefulWidget {
  const _BreadcrumbDropdown({
    required this.position,
    required this.dirPath,
    required this.onDismiss,
    required this.onFileSelected,
  });

  final Offset position;
  final String dirPath;
  final VoidCallback onDismiss;
  final void Function(String name, String path) onFileSelected;

  @override
  State<_BreadcrumbDropdown> createState() => _BreadcrumbDropdownState();
}

class _BreadcrumbDropdownState extends State<_BreadcrumbDropdown> {
  List<FileSystemEntity>? _entries;
  late String _currentDir;

  @override
  void initState() {
    super.initState();
    _currentDir = widget.dirPath;
    _loadEntries();
  }

  void _loadEntries() async {
    setState(() => _entries = null);
    try {
      final dir = Directory(_currentDir);
      final raw = await dir.list().toList();
      // Sort: directories first, then alphabetical.
      raw.sort((a, b) {
        final aDir = a is Directory;
        final bDir = b is Directory;
        if (aDir != bDir) return aDir ? -1 : 1;
        return a.path
            .split(Platform.pathSeparator)
            .last
            .toLowerCase()
            .compareTo(b.path.split(Platform.pathSeparator).last.toLowerCase());
      });
      if (mounted) setState(() => _entries = raw);
    } catch (_) {
      if (mounted) setState(() => _entries = []);
    }
  }

  void _navigateToDir(String dirPath) {
    _currentDir = dirPath;
    _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const menuWidth = 240.0;

    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => widget.onDismiss(),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: widget.position.dx.clamp(0, screenSize.width - menuWidth),
          top: widget.position.dy,
          child: Material(
            color: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            child: Container(
              width: menuWidth,
              constraints: const BoxConstraints(maxHeight: 300),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: _buildContent(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_entries == null) {
      return Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.mutedForeground,
          ),
        ),
      );
    }

    if (_entries!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Empty folder',
          style: AppTextStyles.uiSmall.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: _entries!.length,
      itemBuilder: (context, index) => _buildItem(_entries![index]),
    );
  }

  Widget _buildItem(FileSystemEntity entry) {
    final name = entry.path.split(Platform.pathSeparator).last;
    final isDir = entry is Directory;

    return _DropdownItem(
      label: name,
      icon: isDir ? Icons.folder_outlined : Icons.description_outlined,
      onTap: () {
        if (isDir) {
          _navigateToDir(entry.path);
        } else {
          widget.onFileSelected(name, entry.path);
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Dropdown item
// ---------------------------------------------------------------------------

class _DropdownItem extends StatefulWidget {
  const _DropdownItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_DropdownItem> createState() => _DropdownItemState();
}

class _DropdownItemState extends State<_DropdownItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color:
                _hovering ? AppColors.listHoverBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 14, color: AppColors.secondaryForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: AppTextStyles.uiSmall.copyWith(
                    color: AppColors.foreground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
