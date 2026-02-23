import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bewy/core/editor/re_editor_compat.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/icon_button_small.dart';
import '../../../shared/widgets/context_menu.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../core/providers/recent_files_provider.dart';
import '../../../core/providers/multi_window_provider.dart';
import '../../../core/providers/timeline_provider.dart';
import '../../../core/services/app_log_service.dart';
import '../../../core/models/timeline_event.dart';
import '../../../core/models/timeline_compare_request.dart';
import '../../../l10n/app_localizations.dart';
import '../../shell/presentation/ide_shell_provider.dart';
import 'file_explorer_provider.dart';
import '../widgets/file_tree_node.dart';
import '../models/file_node.dart';
import '../../editor_area/presentation/editor_area_provider.dart';

class FileExplorer extends ConsumerStatefulWidget {
  const FileExplorer({super.key});

  @override
  ConsumerState<FileExplorer> createState() => _FileExplorerWidgetState();

  static List<FileNode> flattenNodes(List<FileNode> nodes) {
    final result = <FileNode>[];
    for (final node in nodes) {
      result.add(node);
      if (node.isDirectory && node.isExpanded) {
        result.addAll(flattenNodes(node.children));
      }
    }
    return result;
  }
}

/// Clipboard state for file explorer copy/cut operations.
class _ClipboardState {
  static String? sourcePath;
  static bool isCut = false;
}

class _FileExplorerWidgetState extends ConsumerState<FileExplorer> {
  bool _showSearch = false;
  bool _timelineExpanded = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fileExplorerProvider);
    final timeline = ref.watch(timelineProvider);
    final hasFolder = state.rootPath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header toolbar
        GestureDetector(
          onSecondaryTapUp: (details) {
            showAppContextMenu(context, details.globalPosition, [
              ContextMenuItem(
                label: context.tr('explorer.hideSidebar'),
                icon: Icons.visibility_off_outlined,
                shortcut: 'Ctrl+B',
                onTap:
                    () => ref.read(ideShellProvider.notifier).toggleSidebar(),
              ),
            ]);
          },
          child: Container(
            height: 35,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasFolder
                        ? state.rootPath!.split(Platform.pathSeparator).last
                        : context.tr('explorer.title'),
                    style: context.trStyle(
                      AppTextStyles.sideBarTitle.copyWith(fontSize: 11),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasFolder) ...[
                  Opacity(
                    opacity: state.canUndo ? 1.0 : 0.4,
                    child: IconButtonSmall(
                      icon: Icons.undo,
                      onPressed: () {
                        if (state.canUndo) {
                          ref.read(fileExplorerProvider.notifier).undo();
                        }
                      },
                      tooltip: context.tr('explorer.undo'),
                    ),
                  ),
                  IconButtonSmall(
                    icon: Icons.search,
                    onPressed: () {
                      setState(() {
                        _showSearch = !_showSearch;
                        if (!_showSearch) {
                          _searchController.clear();
                          ref
                              .read(fileExplorerProvider.notifier)
                              .setFilterQuery('');
                        }
                      });
                    },
                    tooltip: context.tr('explorer.searchFiles'),
                  ),
                  IconButtonSmall(
                    icon: Icons.manage_search_outlined,
                    onPressed: () async {
                      final rootPath = state.rootPath;
                      if (rootPath == null) return;
                      await AppDialog.showWorkspaceSearchAndReplace(
                        context,
                        rootPath: rootPath,
                        onOpenResult: (filePath, line) async {
                          await _openFileFromExplorer(ref, '', filePath);
                          final activeId =
                              ref.read(editorAreaProvider).tabGroup.activeTabId;
                          if (activeId == null) return;
                          final controller = ref
                              .read(editorAreaProvider.notifier)
                              .getController(activeId);
                          if (controller == null) return;
                          final target = (line - 1).clamp(
                            0,
                            controller.lineCount - 1,
                          );
                          controller.selection = CodeLineSelection.collapsed(
                            index: target,
                            offset: 0,
                          );
                          controller.makeCursorCenterIfInvisible();
                        },
                      );
                    },
                    tooltip: context.tr('menu.findInFiles'),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Search input
        if (hasFolder && _showSearch)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
            child: Container(
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  Icon(
                    Icons.search,
                    size: 14,
                    color: AppColors.secondaryForeground,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: context.trStyle(
                        AppTextStyles.uiSmall.copyWith(fontSize: 11),
                      ),
                      decoration: InputDecoration(
                        hintText: context.tr('explorer.filterFiles'),
                        hintStyle: context.trStyle(
                          AppTextStyles.uiSmall.copyWith(
                            fontSize: 11,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                      onChanged: (value) {
                        ref
                            .read(fileExplorerProvider.notifier)
                            .setFilterQuery(value);
                      },
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButtonSmall(
                      icon: Icons.close,
                      size: 16,
                      iconSize: 12,
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(fileExplorerProvider.notifier)
                            .setFilterQuery('');
                      },
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child:
                    hasFolder
                        ? state.filterQuery.isNotEmpty
                            ? _FilteredFileList(
                              filteredNodes:
                                  ref
                                      .read(fileExplorerProvider.notifier)
                                      .getFilteredNodes(),
                              selectedPath: state.selectedPath,
                            )
                            : _FileTreeListView(
                              rootNodes: state.rootNodes,
                              selectedPath: state.selectedPath,
                              rootPath: state.rootPath!,
                            )
                        : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.tr('explorer.openFolderToStart'),
                                  style: context.trStyle(
                                    AppTextStyles.uiSmall.copyWith(
                                      color: AppColors.secondaryForeground,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => _openFolder(ref),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        context.tr('explorer.openFolder'),
                                        style: context.trStyle(
                                          AppTextStyles.uiSmall.copyWith(
                                            color: AppColors.buttonForeground,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
              ),
              if (hasFolder && _timelineExpanded)
                _TimelinePanel(
                  events: timeline.events,
                  onTapEvent: (event) => _openTimelineEvent(event),
                ),
              if (hasFolder)
                _TimelineToggleBar(
                  expanded: _timelineExpanded,
                  onToggle:
                      () => setState(
                        () => _timelineExpanded = !_timelineExpanded,
                      ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openFolder(WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      ref.read(fileExplorerProvider.notifier).openFolder(result);
      AppLogService.instance.info(
        'explorer',
        'openFolderFromPicker path=$result',
      );
      final folderName = result.split(Platform.pathSeparator).last;
      ref
          .read(recentFilesProvider.notifier)
          .addRecent(folderName, result, true);
    }
  }

  Future<void> _openTimelineEvent(TimelineEvent event) async {
    if (event.beforeContent == null || event.beforeContent!.isEmpty) return;
    final file = File(event.filePath);
    if (!await file.exists()) return;
    final result = await ref
        .read(editorAreaProvider.notifier)
        .openTimelineComparison(
          filePath: event.filePath,
          fileName: event.fileName,
          beforeContent: event.beforeContent!,
          labelSuffix: context.tr('timeline.beforeLabel'),
        );
    if (result == null) return;
    AppLogService.instance.info(
      'timeline',
      'openComparison file=${event.filePath}',
    );
    ref
        .read(timelineCompareRequestProvider.notifier)
        .state = TimelineCompareRequest(
      currentTabId: result.currentTabId,
      snapshotTabId: result.snapshotTabId,
    );
  }
}

class _FilteredFileList extends ConsumerWidget {
  const _FilteredFileList({required this.filteredNodes, this.selectedPath});

  final List<FileNode> filteredNodes;
  final String? selectedPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (filteredNodes.isEmpty) {
      return Center(
        child: Text(
          context.tr('explorer.noMatchingFiles'),
          style: context.trStyle(
            AppTextStyles.uiSmall.copyWith(
              color: AppColors.secondaryForeground,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: filteredNodes.length,
      itemExtent: 22,
      itemBuilder: (context, index) {
        final node = filteredNodes[index];
        return FileTreeNodeWidget(
          key: ValueKey(node.path),
          node: node.copyWith(depth: 0),
          isSelected: node.path == selectedPath,
          onTap: () {
            if (node.isDirectory) {
              ref.read(fileExplorerProvider.notifier).toggleExpand(node.path);
            } else {
              ref.read(fileExplorerProvider.notifier).selectFile(node.path);
              _openFileFromExplorer(ref, node.name, node.path);
            }
          },
        );
      },
    );
  }
}

class _TimelineToggleBar extends StatelessWidget {
  const _TimelineToggleBar({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.panelBase,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.expand_more : Icons.expand_less,
              size: 14,
              color: AppColors.secondaryForeground,
            ),
            const SizedBox(width: 6),
            Text(
              context.tr('timeline.title'),
              style: context.trStyle(
                AppTextStyles.uiSmall.copyWith(
                  fontSize: 11,
                  color: AppColors.secondaryForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.events, required this.onTapEvent});

  final List<TimelineEvent> events;
  final Future<void> Function(TimelineEvent event) onTapEvent;

  String _eventLabel(BuildContext context, TimelineEvent event) {
    switch (event.type) {
      case TimelineEventType.saved:
        return context.tr('timeline.event.saved');
      case TimelineEventType.moved:
        return context.tr('timeline.event.moved');
      case TimelineEventType.renamed:
        return context.tr('timeline.event.renamed');
      case TimelineEventType.deleted:
        return context.tr('timeline.event.deleted');
      case TimelineEventType.createdFile:
        return context.tr('timeline.event.createdFile');
      case TimelineEventType.createdFolder:
        return context.tr('timeline.event.createdFolder');
    }
  }

  String _formatTime(DateTime ts) {
    final h = ts.hour.toString().padLeft(2, '0');
    final m = ts.minute.toString().padLeft(2, '0');
    final s = ts.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      decoration: BoxDecoration(
        color: AppColors.panelBase,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child:
          events.isEmpty
              ? Center(
                child: Text(
                  context.tr('timeline.empty'),
                  style: context.trStyle(
                    AppTextStyles.uiSmall.copyWith(
                      color: AppColors.secondaryForeground,
                    ),
                  ),
                ),
              )
              : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: events.length,
                separatorBuilder:
                    (_, __) => Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, index) {
                  final event = events[index];
                  final label = _eventLabel(context, event);
                  final time = _formatTime(event.timestamp.toLocal());
                  return InkWell(
                    onTap: () => onTapEvent(event),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$label ${event.fileName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.trStyle(AppTextStyles.uiSmall),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: context.trStyle(
                              AppTextStyles.uiSmall.copyWith(
                                color: AppColors.secondaryForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class _FileTreeListView extends ConsumerStatefulWidget {
  const _FileTreeListView({
    required this.rootNodes,
    this.selectedPath,
    required this.rootPath,
  });

  final List<FileNode> rootNodes;
  final String? selectedPath;
  final String rootPath;

  @override
  ConsumerState<_FileTreeListView> createState() => _FileTreeListViewState();
}

class _FileTreeListViewState extends ConsumerState<_FileTreeListView> {
  String? _dragTargetPath;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _copyNode(String path) {
    _ClipboardState.sourcePath = path;
    _ClipboardState.isCut = false;
    AppLogService.instance.info('explorer', 'copy path=$path');
  }

  void _cutNode(String path) {
    _ClipboardState.sourcePath = path;
    _ClipboardState.isCut = true;
    AppLogService.instance.info('explorer', 'cut path=$path');
  }

  Future<bool> _pathExists(String path) async {
    final type = FileSystemEntity.typeSync(path);
    return type != FileSystemEntityType.notFound;
  }

  Future<void> _deletePath(String path) async {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.file) {
      await File(path).delete();
    } else if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    }
  }

  Future<bool> _confirmOverwritePath(String path) async {
    final name = path.split(Platform.pathSeparator).last;
    final confirmed = await AppDialog.showConfirmOverwrite(
      context,
      name: name,
      path: path,
    );
    return confirmed == true;
  }

  Future<bool> _prepareOverwriteIfNeeded(String path) async {
    if (!await _pathExists(path)) return true;
    final overwrite = await _confirmOverwritePath(path);
    if (!overwrite) return false;
    await _deletePath(path);
    return true;
  }

  Future<void> _handleDropMove(String source, String targetDir) async {
    final name = source.split(Platform.pathSeparator).last;
    final destPath = '$targetDir${Platform.pathSeparator}$name';
    if (source == destPath) return;
    final before = await _snapshotTextForTimeline(source);
    final canProceed = await _prepareOverwriteIfNeeded(destPath);
    if (!canProceed) return;
    await ref.read(fileExplorerProvider.notifier).moveNode(source, targetDir);
    AppLogService.instance.info(
      'explorer',
      'dragMove source=$source targetDir=$targetDir',
    );
    _recordTimeline(
      TimelineEvent(
        id: 'tl_${DateTime.now().microsecondsSinceEpoch}',
        type: TimelineEventType.moved,
        fileName: name,
        filePath: destPath,
        timestamp: DateTime.now(),
        beforeContent: before,
      ),
    );
  }

  Future<void> _pasteNode(String targetDir) async {
    final source = _ClipboardState.sourcePath;
    if (source == null) return;

    final name = source.split(Platform.pathSeparator).last;
    final destPath = '$targetDir${Platform.pathSeparator}$name';

    if (source == destPath) return;

    try {
      final canProceed = await _prepareOverwriteIfNeeded(destPath);
      if (!canProceed) return;

      if (_ClipboardState.isCut) {
        final before = await _snapshotTextForTimeline(source);
        await ref
            .read(fileExplorerProvider.notifier)
            .moveNode(source, targetDir);
        AppLogService.instance.info(
          'explorer',
          'pasteMove source=$source targetDir=$targetDir',
        );
        _recordTimeline(
          TimelineEvent(
            id: 'tl_${DateTime.now().microsecondsSinceEpoch}',
            type: TimelineEventType.moved,
            fileName: name,
            filePath: destPath,
            timestamp: DateTime.now(),
            beforeContent: before,
          ),
        );
        _ClipboardState.sourcePath = null;
      } else {
        // Copy operation.
        final type = FileSystemEntity.typeSync(source);
        if (type == FileSystemEntityType.file) {
          await File(source).copy(destPath);
          AppLogService.instance.info(
            'explorer',
            'pasteCopyFile source=$source target=$destPath',
          );
        } else if (type == FileSystemEntityType.directory) {
          await _copyDirectory(Directory(source), Directory(destPath));
          AppLogService.instance.info(
            'explorer',
            'pasteCopyDir source=$source target=$destPath',
          );
        }
        await ref.read(fileExplorerProvider.notifier).refreshTree();
      }
    } catch (_) {}
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list()) {
      final newPath =
          '${destination.path}${Platform.pathSeparator}${entity.path.split(Platform.pathSeparator).last}';
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }

  void _recordTimeline(TimelineEvent event) {
    ref
        .read(multiWindowProvider.notifier)
        .publishTimelineEvent(event.toPayload());
  }

  Future<String?> _snapshotTextForTimeline(String path) async {
    try {
      final type = FileSystemEntity.typeSync(path);
      if (type != FileSystemEntityType.file) return null;
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return '';
      if (bytes.contains(0)) return null;
      if (bytes.length > 512 * 1024) return null;
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  List<ContextMenuItem> _commonContextItems(FileNode node) {
    return [
      const ContextMenuSeparator(),
      ContextMenuItem(
        label: context.tr('explorer.copy'),
        icon: Icons.copy_outlined,
        shortcut: 'Ctrl+C',
        onTap: () => _copyNode(node.path),
      ),
      ContextMenuItem(
        label: context.tr('explorer.cut'),
        icon: Icons.content_cut_outlined,
        shortcut: 'Ctrl+X',
        onTap: () => _cutNode(node.path),
      ),
      if (node.isDirectory && _ClipboardState.sourcePath != null)
        ContextMenuItem(
          label: context.tr('explorer.paste'),
          icon: Icons.paste_outlined,
          shortcut: 'Ctrl+V',
          onTap: () => _pasteNode(node.path),
        ),
      const ContextMenuSeparator(),
      ContextMenuItem(
        label: context.tr('explorer.copyPath'),
        icon: Icons.link,
        shortcut: 'Ctrl+Shift+C',
        onTap: () => Clipboard.setData(ClipboardData(text: node.path)),
      ),
      ContextMenuItem(
        label: context.tr('explorer.revealInExplorer'),
        icon: Icons.folder_open,
        onTap: () => Process.run('explorer', ['/select,', node.path]),
      ),
    ];
  }

  void _showFileContextMenu(
    BuildContext context,
    WidgetRef ref,
    FileNode node,
    Offset position,
  ) {
    showAppContextMenu(context, position, [
      ContextMenuItem(
        label: context.tr('explorer.open'),
        icon: Icons.open_in_new,
        onTap: () {
          ref.read(fileExplorerProvider.notifier).selectFile(node.path);
          _openFileFromExplorer(ref, node.name, node.path);
        },
      ),
      const ContextMenuSeparator(),
      ContextMenuItem(
        label: context.tr('explorer.rename'),
        icon: Icons.edit_outlined,
        onTap: () async {
          final newName = await AppDialog.showInputDialog(
            context,
            title: context.tr('explorer.rename'),
            hintText: context.tr('common.newName'),
            initialValue: node.name,
            confirmLabel: context.tr('explorer.rename'),
          );
          if (newName != null && newName.isNotEmpty && newName != node.name) {
            final parent = File(node.path).parent.path;
            final targetPath = '$parent${Platform.pathSeparator}$newName';
            final before = await _snapshotTextForTimeline(node.path);
            final canProceed = await _prepareOverwriteIfNeeded(targetPath);
            if (!canProceed) return;
            await ref
                .read(fileExplorerProvider.notifier)
                .renameNode(node.path, newName);
            _recordTimeline(
              TimelineEvent(
                id: 'tl_${DateTime.now().microsecondsSinceEpoch}',
                type: TimelineEventType.renamed,
                fileName: newName,
                filePath: targetPath,
                timestamp: DateTime.now(),
                beforeContent: before,
              ),
            );
          }
        },
      ),
      ContextMenuItem(
        label: context.tr('explorer.delete'),
        icon: Icons.delete_outline,
        isDanger: true,
        onTap: () async {
          final before = await _snapshotTextForTimeline(node.path);
          final confirmed = await AppDialog.showConfirmDelete(
            context,
            node.name,
          );
          if (confirmed == true) {
            await ref.read(fileExplorerProvider.notifier).deleteNode(node.path);
            _recordTimeline(
              TimelineEvent(
                id: 'tl_${DateTime.now().microsecondsSinceEpoch}',
                type: TimelineEventType.deleted,
                fileName: node.name,
                filePath: node.path,
                timestamp: DateTime.now(),
                beforeContent: before,
              ),
            );
          }
        },
      ),
      ..._commonContextItems(node),
    ]);
  }

  void _showFolderContextMenu(
    BuildContext context,
    WidgetRef ref,
    FileNode node,
    Offset position,
  ) {
    showAppContextMenu(context, position, [
      ContextMenuItem(
        label: context.tr('explorer.newFileHere'),
        icon: Icons.note_add_outlined,
        onTap: () async {
          final name = await AppDialog.showInputDialog(
            context,
            title: context.tr('explorer.newFile'),
            hintText: context.tr('common.fileNameHint'),
            confirmLabel: context.tr('common.create'),
          );
          if (name != null && name.isNotEmpty) {
            await ref
                .read(fileExplorerProvider.notifier)
                .createFileInDir(node.path, name);
            final filePath = '${node.path}${Platform.pathSeparator}$name';
            _recordTimeline(
              TimelineEvent(
                id: 'tl_${DateTime.now().microsecondsSinceEpoch}',
                type: TimelineEventType.createdFile,
                fileName: name,
                filePath: filePath,
                timestamp: DateTime.now(),
              ),
            );
            ref.read(editorAreaProvider.notifier).openTab(name, filePath);
          }
        },
      ),
      ContextMenuItem(
        label: context.tr('explorer.newFolder'),
        icon: Icons.create_new_folder_outlined,
        onTap: () async {
          final name = await AppDialog.showInputDialog(
            context,
            title: context.tr('explorer.newFolder'),
            hintText: context.tr('common.folderName'),
            confirmLabel: context.tr('common.create'),
          );
          if (name != null && name.isNotEmpty) {
            await ref
                .read(fileExplorerProvider.notifier)
                .createSubFolder(node.path, name);
            _recordTimeline(
              TimelineEvent(
                id: 'tl_${DateTime.now().microsecondsSinceEpoch}',
                type: TimelineEventType.createdFolder,
                fileName: name,
                filePath: '${node.path}${Platform.pathSeparator}$name',
                timestamp: DateTime.now(),
              ),
            );
          }
        },
      ),
      const ContextMenuSeparator(),
      ContextMenuItem(
        label: context.tr('explorer.rename'),
        icon: Icons.edit_outlined,
        onTap: () async {
          final newName = await AppDialog.showInputDialog(
            context,
            title: context.tr('explorer.rename'),
            hintText: context.tr('common.newName'),
            initialValue: node.name,
            confirmLabel: context.tr('explorer.rename'),
          );
          if (newName != null && newName.isNotEmpty && newName != node.name) {
            final parent = Directory(node.path).parent.path;
            final targetPath = '$parent${Platform.pathSeparator}$newName';
            final canProceed = await _prepareOverwriteIfNeeded(targetPath);
            if (!canProceed) return;
            await ref
                .read(fileExplorerProvider.notifier)
                .renameNode(node.path, newName);
            _recordTimeline(
              TimelineEvent(
                id: 'tl_${DateTime.now().microsecondsSinceEpoch}',
                type: TimelineEventType.renamed,
                fileName: newName,
                filePath: targetPath,
                timestamp: DateTime.now(),
              ),
            );
          }
        },
      ),
      ContextMenuItem(
        label: context.tr('explorer.delete'),
        icon: Icons.delete_outline,
        isDanger: true,
        onTap: () async {
          final confirmed = await AppDialog.showConfirmDelete(
            context,
            node.name,
          );
          if (confirmed == true) {
            await ref.read(fileExplorerProvider.notifier).deleteNode(node.path);
            _recordTimeline(
              TimelineEvent(
                id: 'tl_${DateTime.now().microsecondsSinceEpoch}',
                type: TimelineEventType.deleted,
                fileName: node.name,
                filePath: node.path,
                timestamp: DateTime.now(),
              ),
            );
          }
        },
      ),
      ..._commonContextItems(node),
    ]);
  }

  /// Context menu for the root directory background (empty space).
  void _showRootContextMenu(BuildContext context, Offset position) {
    final rootPath = widget.rootPath;
    showAppContextMenu(context, position, [
      ContextMenuItem(
        label: context.tr('explorer.newFile'),
        icon: Icons.note_add_outlined,
        onTap: () async {
          final name = await AppDialog.showInputDialog(
            context,
            title: context.tr('explorer.newFile'),
            hintText: context.tr('common.fileNameHint'),
            confirmLabel: context.tr('common.create'),
          );
          if (name != null && name.isNotEmpty) {
            await ref
                .read(fileExplorerProvider.notifier)
                .createFileInDir(rootPath, name);
            final filePath = '$rootPath${Platform.pathSeparator}$name';
            _recordTimeline(
              TimelineEvent(
                id: 'tl_${DateTime.now().microsecondsSinceEpoch}',
                type: TimelineEventType.createdFile,
                fileName: name,
                filePath: filePath,
                timestamp: DateTime.now(),
              ),
            );
            ref.read(editorAreaProvider.notifier).openTab(name, filePath);
          }
        },
      ),
      ContextMenuItem(
        label: context.tr('explorer.newFolder'),
        icon: Icons.create_new_folder_outlined,
        onTap: () async {
          final name = await AppDialog.showInputDialog(
            context,
            title: context.tr('explorer.newFolder'),
            hintText: context.tr('common.folderName'),
            confirmLabel: context.tr('common.create'),
          );
          if (name != null && name.isNotEmpty) {
            await ref
                .read(fileExplorerProvider.notifier)
                .createSubFolder(rootPath, name);
            _recordTimeline(
              TimelineEvent(
                id: 'tl_${DateTime.now().microsecondsSinceEpoch}',
                type: TimelineEventType.createdFolder,
                fileName: name,
                filePath: '$rootPath${Platform.pathSeparator}$name',
                timestamp: DateTime.now(),
              ),
            );
          }
        },
      ),
      if (_ClipboardState.sourcePath != null) ...[
        const ContextMenuSeparator(),
        ContextMenuItem(
          label: context.tr('explorer.paste'),
          icon: Icons.paste_outlined,
          shortcut: 'Ctrl+V',
          onTap: () => _pasteNode(rootPath),
        ),
      ],
      const ContextMenuSeparator(),
      ContextMenuItem(
        label: context.tr('explorer.openFolderMenu'),
        icon: Icons.folder_open_outlined,
        onTap: () async {
          final result = await FilePicker.platform.getDirectoryPath();
          if (result != null) {
            ref.read(fileExplorerProvider.notifier).openFolder(result);
            final folderName = result.split(Platform.pathSeparator).last;
            ref
                .read(recentFilesProvider.notifier)
                .addRecent(folderName, result, true);
          }
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final flatNodes = FileExplorer.flattenNodes(widget.rootNodes);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (details) {
        _showRootContextMenu(context, details.globalPosition);
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        itemCount: flatNodes.length,
        itemExtent: 22,
        itemBuilder: (context, index) {
          final node = flatNodes[index];
          return _DraggableNode(
            node: node,
            isSelected: node.path == widget.selectedPath,
            dragTargetPath: _dragTargetPath,
            onTap: () {
              if (node.isDirectory) {
                ref.read(fileExplorerProvider.notifier).toggleExpand(node.path);
              } else {
                ref.read(fileExplorerProvider.notifier).selectFile(node.path);
                _openFileFromExplorer(ref, node.name, node.path);
              }
            },
            onSecondaryTapUp: (details) {
              if (node.isDirectory) {
                _showFolderContextMenu(
                  context,
                  ref,
                  node,
                  details.globalPosition,
                );
              } else {
                _showFileContextMenu(
                  context,
                  ref,
                  node,
                  details.globalPosition,
                );
              }
            },
            onDragTargetChange: (path) {
              setState(() => _dragTargetPath = path);
            },
            onAccept: (source, target) async {
              setState(() => _dragTargetPath = null);
              await _handleDropMove(source, target);
            },
          );
        },
      ),
    );
  }
}

Future<void> _openFileFromExplorer(
  WidgetRef ref,
  String fileName,
  String filePath,
) async {
  AppLogService.instance.info('explorer', 'openFile path=$filePath');
  final resolvedName =
      fileName.isEmpty ? filePath.split(Platform.pathSeparator).last : fileName;
  final focused = await ref
      .read(multiWindowProvider.notifier)
      .focusChildWindowForFile(filePath);
  if (!focused) {
    await ref.read(editorAreaProvider.notifier).openTab(resolvedName, filePath);
  }
  ref
      .read(recentFilesProvider.notifier)
      .addRecent(resolvedName, filePath, false);
}

/// Individual draggable + drop-target node, separated to limit rebuilds.
class _DraggableNode extends StatelessWidget {
  const _DraggableNode({
    required this.node,
    required this.isSelected,
    required this.dragTargetPath,
    required this.onTap,
    required this.onSecondaryTapUp,
    required this.onDragTargetChange,
    required this.onAccept,
  });

  final FileNode node;
  final bool isSelected;
  final String? dragTargetPath;
  final VoidCallback onTap;
  final void Function(TapUpDetails) onSecondaryTapUp;
  final ValueChanged<String?> onDragTargetChange;
  final Future<void> Function(String sourcePath, String targetPath) onAccept;

  @override
  Widget build(BuildContext context) {
    Widget nodeWidget = FileTreeNodeWidget(
      key: ValueKey(node.path),
      node: node,
      isSelected: isSelected,
      onTap: onTap,
      onSecondaryTapUp: onSecondaryTapUp,
    );

    final draggable = Draggable<FileNode>(
      data: node,
      feedback: Material(
        color: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(node.name, style: context.trStyle(AppTextStyles.uiSmall)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: nodeWidget),
      child: nodeWidget,
    );

    // All nodes (files and directories) are drop targets.
    // For directories, the target is the directory itself.
    // For files, the target is the file's parent directory.
    final targetDir =
        node.isDirectory
            ? node.path
            : node.path.substring(
              0,
              node.path.lastIndexOf(Platform.pathSeparator),
            );

    return DragTarget<FileNode>(
      key: ValueKey('drop_${node.path}'),
      onWillAcceptWithDetails: (details) {
        final source = details.data;
        if (source.path == node.path) return false;
        // Reject if source is already a direct child of the target directory.
        final sourceParent = source.path.substring(
          0,
          source.path.lastIndexOf(Platform.pathSeparator),
        );
        if (sourceParent == targetDir) return false;
        // Reject if the target directory is inside the source (prevents moving a folder into itself).
        if (targetDir.startsWith('${source.path}${Platform.pathSeparator}')) {
          return false;
        }
        onDragTargetChange(targetDir);
        return true;
      },
      onLeave: (_) {
        if (dragTargetPath == targetDir) {
          onDragTargetChange(null);
        }
      },
      onAcceptWithDetails: (details) {
        onAccept(details.data.path, targetDir);
      },
      builder: (context, candidateData, rejectedData) {
        if (dragTargetPath == targetDir && candidateData.isNotEmpty) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.listActiveSelectionBackground,
              borderRadius: BorderRadius.circular(2),
            ),
            child: draggable,
          );
        }
        return draggable;
      },
    );
  }
}
