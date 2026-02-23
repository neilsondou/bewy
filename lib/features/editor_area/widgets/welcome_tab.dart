import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/models/recent_entry.dart';
import '../../../core/providers/recent_files_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/context_menu.dart';
import '../../editor_area/presentation/editor_area_provider.dart';
import '../../file_explorer/presentation/file_explorer_provider.dart';

class WelcomeTab extends ConsumerWidget {
  const WelcomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentFiles = ref.watch(recentFilesProvider);
    final visibleEntries = recentFiles.take(5).toList();

    return Container(
      color: AppColors.editorBackground,
      child: Row(
        children: [
          // Left column: logo + title row, then action buttons
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo and title on the same row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icons/logo.png',
                        width: 42,
                        height: 42,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Bewy',
                            style: context.trStyle(AppTextStyles.welcomeTitle),
                          ),
                          Text(
                            'v0.0.2',
                            style: AppTextStyles.uiSmall.copyWith(
                              color: AppColors.mutedForeground,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Borderless action buttons
                  _WelcomeActionButton(
                    icon: Icons.description_outlined,
                    label: context.tr('welcome.openFile'),
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles();
                      if (result != null && result.files.single.path != null) {
                        final file = result.files.single;
                        ref
                            .read(editorAreaProvider.notifier)
                            .openTab(file.name, file.path!);
                        ref
                            .read(recentFilesProvider.notifier)
                            .addRecent(file.name, file.path!, false);
                      }
                    },
                  ),
                  _WelcomeActionButton(
                    icon: Icons.folder_outlined,
                    label: context.tr('welcome.openFolder'),
                    onTap: () async {
                      final result =
                          await FilePicker.platform.getDirectoryPath();
                      if (result != null) {
                        ref
                            .read(fileExplorerProvider.notifier)
                            .openFolder(result);
                        final folderName =
                            result.split(Platform.pathSeparator).last;
                        ref
                            .read(recentFilesProvider.notifier)
                            .addRecent(folderName, result, true);
                      }
                    },
                  ),
                  _WelcomeActionButton(
                    icon: Icons.note_add_outlined,
                    label: context.tr('welcome.newFile'),
                    onTap: () {
                      ref.read(editorAreaProvider.notifier).createNewTab();
                    },
                  ),
                ],
              ),
            ),
          ),
          // Right column: recent files
          Expanded(
            child: Center(
              child:
                  visibleEntries.isNotEmpty
                      ? _RecentFilesPanel(entries: visibleEntries)
                      : Text(
                        context.tr('welcome.noRecentFiles'),
                        style: context.trStyle(
                          AppTextStyles.uiSmall.copyWith(
                            color: AppColors.secondaryForeground,
                          ),
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeActionButton extends StatefulWidget {
  const _WelcomeActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_WelcomeActionButton> createState() => _WelcomeActionButtonState();
}

class _WelcomeActionButtonState extends State<_WelcomeActionButton> {
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
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _hovering ? AppColors.hoverHighlight : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: AppColors.welcomeLinkForeground,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: context.trStyle(AppTextStyles.welcomeLink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentFilesPanel extends ConsumerWidget {
  const _RecentFilesPanel({required this.entries});

  final List<RecentEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              context.tr('welcome.recent'),
              style: context.trStyle(
                AppTextStyles.uiSmall.copyWith(
                  color: AppColors.secondaryForeground,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          for (final entry in entries) _RecentEntryItem(entry: entry),
        ],
      ),
    );
  }
}

class _RecentEntryItem extends ConsumerStatefulWidget {
  const _RecentEntryItem({required this.entry});

  final RecentEntry entry;

  @override
  ConsumerState<_RecentEntryItem> createState() => _RecentEntryItemState();
}

class _RecentEntryItemState extends ConsumerState<_RecentEntryItem> {
  bool _hovering = false;

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.month}/${time.day}';
  }

  void _openEntry() {
    if (widget.entry.isFolder) {
      ref.read(fileExplorerProvider.notifier).openFolder(widget.entry.path);
    } else {
      ref
          .read(editorAreaProvider.notifier)
          .openTab(widget.entry.name, widget.entry.path);
    }
    ref
        .read(recentFilesProvider.notifier)
        .addRecent(widget.entry.name, widget.entry.path, widget.entry.isFolder);
  }

  void _showContextMenu(Offset position) {
    showAppContextMenu(context, position, [
      ContextMenuItem(
        label:
            widget.entry.isFolder
                ? context.tr('welcome.openFolderItem')
                : context.tr('welcome.openFileItem'),
        icon: widget.entry.isFolder ? Icons.folder_open : Icons.open_in_new,
        onTap: _openEntry,
      ),
      ContextMenuItem(
        label: context.tr('explorer.revealInExplorer'),
        icon: Icons.launch,
        onTap: () {
          if (widget.entry.isFolder) {
            Process.run('explorer', [widget.entry.path]);
          } else {
            Process.run('explorer', ['/select,', widget.entry.path]);
          }
        },
      ),
      const ContextMenuSeparator(),
      ContextMenuItem(
        label: context.tr('welcome.removeFromRecent'),
        icon: Icons.delete_outline,
        isDanger: true,
        onTap: () {
          ref
              .read(recentFilesProvider.notifier)
              .removeRecent(widget.entry.path);
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: _openEntry,
        onSecondaryTapUp: (details) => _showContextMenu(details.globalPosition),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
          decoration: BoxDecoration(
            color: _hovering ? AppColors.hoverHighlight : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                widget.entry.isFolder
                    ? Icons.folder_outlined
                    : Icons.description_outlined,
                size: 13,
                color: AppColors.secondaryForeground,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.entry.name,
                      style: context.trStyle(
                        AppTextStyles.welcomeLink.copyWith(fontSize: 11),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.entry.path,
                      style: context.trStyle(
                        AppTextStyles.uiSmall.copyWith(
                          color: AppColors.mutedForeground,
                          fontSize: 9,
                        ),
                        zhDelta: -0.6,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _formatTimeAgo(widget.entry.lastOpened),
                style: context.trStyle(
                  AppTextStyles.uiSmall.copyWith(
                    color: AppColors.mutedForeground,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
