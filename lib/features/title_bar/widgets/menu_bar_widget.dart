import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bewy/core/editor/re_editor_compat.dart';
import '../../../core/providers/shortcut_settings_provider.dart';
import '../../../core/providers/multi_window_provider.dart';
import '../../../core/services/app_exit_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/providers/recent_files_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/context_menu.dart';
import '../../editor_area/presentation/editor_area.dart';
import '../../editor_area/presentation/editor_area_provider.dart';
import '../../editor_area/presentation/editor_settings_provider.dart';
import '../../file_explorer/presentation/file_explorer_provider.dart';
import '../../shell/presentation/ide_shell_provider.dart';
import '../../status_bar/presentation/status_notification_provider.dart';

class MenuBarWidget extends ConsumerStatefulWidget {
  const MenuBarWidget({
    super.key,
    this.includeHelpMenu = true,
    this.includeWindowActions = true,
    this.isChildWindow = false,
  });

  final bool includeHelpMenu;
  final bool includeWindowActions;
  final bool isChildWindow;

  @override
  ConsumerState<MenuBarWidget> createState() => _MenuBarWidgetState();
}

class _MenuBarWidgetState extends ConsumerState<MenuBarWidget> {
  String? _activeMenu;
  OverlayEntry? _overlayEntry;
  final Map<String, GlobalKey> _menuKeys = {};

  List<String> get _menuLabels =>
      widget.includeHelpMenu
          ? const ['File', 'Edit', 'Selection', 'View', 'Help']
          : const ['File', 'Edit', 'Selection', 'View'];

  String _menuTitle(BuildContext context, String id) {
    switch (id) {
      case 'File':
        return context.tr('menu.file');
      case 'Edit':
        return context.tr('menu.edit');
      case 'Selection':
        return context.tr('menu.selection');
      case 'View':
        return context.tr('menu.view');
      case 'Go':
        return context.tr('menu.go');
      case 'Help':
        return context.tr('menu.help');
      default:
        return id;
    }
  }

  @override
  void initState() {
    super.initState();
    for (final label in _menuLabels) {
      _menuKeys[label] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  List<ContextMenuItem> _buildMenuItems(String label) {
    final shortcuts = ref.read(shortcutSettingsProvider);
    String sc(ShortcutAction action) =>
        shortcuts[action]!.displayLabel(isMac: Platform.isMacOS);

    switch (label) {
      case 'File':
        return [
          ContextMenuItem(
            label: context.tr('menu.newFile'),
            icon: Icons.note_add_outlined,
            shortcut: sc(ShortcutAction.newFile),
            onTap: () => ref.read(editorAreaProvider.notifier).createNewTab(),
          ),
          ContextMenuItem(
            label: context.tr('menu.openFile'),
            icon: Icons.file_open_outlined,
            shortcut: sc(ShortcutAction.openFile),
            onTap: () async {
              final result = await FilePicker.platform.pickFiles();
              if (result != null && result.files.single.path != null) {
                final file = result.files.single;
                await ref
                    .read(editorAreaProvider.notifier)
                    .openTab(file.name, file.path!);
                ref
                    .read(recentFilesProvider.notifier)
                    .addRecent(file.name, file.path!, false);
              }
            },
          ),
          ContextMenuItem(
            label: context.tr('menu.openFolder'),
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
          ContextMenuItem(
            label: context.tr('menu.openRecent'),
            icon: Icons.history,
            onTap: () {
              // Show recent files submenu after a short delay so the current menu closes.
              Future.microtask(() {
                if (!mounted) return;
                _showRecentSubmenu();
              });
            },
          ),
          const ContextMenuSeparator(),
          ContextMenuItem(
            label: context.tr('menu.save'),
            icon: Icons.save_outlined,
            shortcut: sc(ShortcutAction.save),
            onTap: () async {
              final saved =
                  await ref.read(editorAreaProvider.notifier).saveActiveTab();
              if (saved) {
                ref
                    .read(statusNotificationProvider.notifier)
                    .show(
                      context.tr('status.fileSaved'),
                      type: StatusNotificationType.success,
                    );
              }
            },
          ),
          ContextMenuItem(
            label: context.tr('menu.saveAs'),
            icon: Icons.save_as_outlined,
            shortcut: sc(ShortcutAction.saveAs),
            onTap:
                () => ref.read(editorAreaProvider.notifier).saveActiveTabAs(),
          ),
          const ContextMenuSeparator(),
          ContextMenuItem(
            label: context.tr('menu.closeTab'),
            icon: Icons.close_outlined,
            shortcut: sc(ShortcutAction.closeTab),
            onTap: () {
              final activeId =
                  ref.read(editorAreaProvider).tabGroup.activeTabId;
              if (activeId != null) {
                handleTabCloseWithSaveCheck(context, ref, activeId);
              }
            },
          ),
          const ContextMenuSeparator(),
          ContextMenuItem(
            label: context.tr('menu.exit'),
            icon: Icons.exit_to_app_outlined,
            onTap: () async {
              if (widget.isChildWindow) {
                await ref
                    .read(multiWindowProvider.notifier)
                    .hideCurrentWindow();
                return;
              }
              await AppExitService.requestClose();
            },
          ),
        ];
      case 'Edit':
        final controller = _activeController();
        return [
          ContextMenuItem(
            label: context.tr('menu.undo'),
            icon: Icons.undo_outlined,
            shortcut: 'Ctrl+Z',
            onTap: () => controller?.undo(),
          ),
          ContextMenuItem(
            label: context.tr('menu.redo'),
            icon: Icons.redo_outlined,
            shortcut: 'Ctrl+Y',
            onTap: () => controller?.redo(),
          ),
          const ContextMenuSeparator(),
          ContextMenuItem(
            label: context.tr('menu.cut'),
            icon: Icons.content_cut_outlined,
            shortcut: 'Ctrl+X',
            onTap: () => controller?.cut(),
          ),
          ContextMenuItem(
            label: context.tr('menu.copy'),
            icon: Icons.content_copy_outlined,
            shortcut: 'Ctrl+C',
            onTap: () => controller?.copy(),
          ),
          ContextMenuItem(
            label: context.tr('menu.paste'),
            icon: Icons.content_paste_outlined,
            shortcut: 'Ctrl+V',
            onTap: () => controller?.paste(),
          ),
          const ContextMenuSeparator(),
          ContextMenuItem(
            label: context.tr('menu.find'),
            icon: Icons.search_outlined,
            shortcut: 'Ctrl+F',
            onTap:
                () =>
                    ref
                        .read(editorAreaProvider.notifier)
                        .getActiveFindController()
                        ?.findMode(),
          ),
          ContextMenuItem(
            label: context.tr('menu.replace'),
            icon: Icons.find_replace_outlined,
            shortcut: 'Ctrl+H',
            onTap:
                () =>
                    ref
                        .read(editorAreaProvider.notifier)
                        .getActiveFindController()
                        ?.replaceMode(),
          ),
          const ContextMenuSeparator(),
          ContextMenuItem(
            label: context.tr('menu.findInFiles'),
            icon: Icons.manage_search_outlined,
            shortcut: sc(ShortcutAction.findInFiles),
            onTap: () async {
              final rootPath = ref.read(fileExplorerProvider).rootPath;
              if (rootPath == null || !context.mounted) {
                ref
                    .read(statusNotificationProvider.notifier)
                    .show(
                      context.tr('status.workspaceSearchFolderRequired'),
                      type: StatusNotificationType.info,
                    );
                return;
              }
              await AppDialog.showWorkspaceSearchAndReplace(
                context,
                rootPath: rootPath,
                onOpenResult: (filePath, line) async {
                  final name = filePath.split(RegExp(r'[/\\]')).last;
                  await ref
                      .read(editorAreaProvider.notifier)
                      .openTab(name, filePath);
                  final activeId =
                      ref.read(editorAreaProvider).tabGroup.activeTabId;
                  if (activeId == null) return;
                  final controller = ref
                      .read(editorAreaProvider.notifier)
                      .getController(activeId);
                  if (controller == null) return;
                  final target = (line - 1).clamp(0, controller.lineCount - 1);
                  controller.selection = CodeLineSelection.collapsed(
                    index: target,
                    offset: 0,
                  );
                  controller.makeCursorCenterIfInvisible();
                },
              );
            },
          ),
          ContextMenuItem(
            label: context.tr('menu.replaceInFiles'),
            icon: Icons.find_replace_outlined,
            shortcut: sc(ShortcutAction.replaceInFiles),
            onTap: () async {
              final rootPath = ref.read(fileExplorerProvider).rootPath;
              if (rootPath == null || !context.mounted) {
                ref
                    .read(statusNotificationProvider.notifier)
                    .show(
                      context.tr('status.workspaceSearchFolderRequired'),
                      type: StatusNotificationType.info,
                    );
                return;
              }
              await AppDialog.showWorkspaceSearchAndReplace(
                context,
                rootPath: rootPath,
                initialReplaceMode: true,
                onOpenResult: (filePath, line) async {
                  final name = filePath.split(RegExp(r'[/\\]')).last;
                  await ref
                      .read(editorAreaProvider.notifier)
                      .openTab(name, filePath);
                  final activeId =
                      ref.read(editorAreaProvider).tabGroup.activeTabId;
                  if (activeId == null) return;
                  final controller = ref
                      .read(editorAreaProvider.notifier)
                      .getController(activeId);
                  if (controller == null) return;
                  final target = (line - 1).clamp(0, controller.lineCount - 1);
                  controller.selection = CodeLineSelection.collapsed(
                    index: target,
                    offset: 0,
                  );
                  controller.makeCursorCenterIfInvisible();
                },
              );
            },
          ),
          ContextMenuItem(
            label: context.tr('menu.formatDocument'),
            icon: Icons.auto_fix_high_outlined,
            shortcut: sc(ShortcutAction.formatDocument),
            onTap: () async {
              final result =
                  await ref.read(editorAreaProvider.notifier).formatActiveTab();
              if (!mounted) return;
              if (!result.supported) {
                ref
                    .read(statusNotificationProvider.notifier)
                    .show(
                      context.tr('status.formatUnsupported'),
                      type: StatusNotificationType.error,
                    );
                return;
              }
              if (result.changed) {
                ref
                    .read(statusNotificationProvider.notifier)
                    .show(
                      context.tr('status.formatted'),
                      type: StatusNotificationType.success,
                    );
              } else {
                ref
                    .read(statusNotificationProvider.notifier)
                    .show(
                      context.tr('status.formatNoChange'),
                      type: StatusNotificationType.info,
                    );
              }
            },
          ),
          const ContextMenuSeparator(),
          ContextMenuItem(
            label: context.tr('menu.selectAll'),
            icon: Icons.select_all_outlined,
            shortcut: 'Ctrl+A',
            onTap: () => controller?.selectAll(),
          ),
        ];
      case 'Selection':
        final controller = _activeController();
        return [
          ContextMenuItem(
            label: context.tr('menu.selectAll'),
            icon: Icons.select_all_outlined,
            shortcut: 'Ctrl+A',
            onTap: () => controller?.selectAll(),
          ),
          const ContextMenuSeparator(),
          ContextMenuItem(
            label: context.tr('menu.copyLineUp'),
            icon: Icons.keyboard_double_arrow_up_outlined,
            shortcut: sc(ShortcutAction.duplicateLineUp),
            onTap: () => _duplicateSelectionLine(up: true),
          ),
          ContextMenuItem(
            label: context.tr('menu.copyLineDown'),
            icon: Icons.keyboard_double_arrow_down_outlined,
            shortcut: sc(ShortcutAction.duplicateLineDown),
            onTap: () => _duplicateSelectionLine(up: false),
          ),
          ContextMenuItem(
            label: context.tr('menu.moveLineUp'),
            icon: Icons.arrow_upward_outlined,
            shortcut: 'Alt+\u2191',
            onTap: () => controller?.moveSelectionLinesUp(),
          ),
          ContextMenuItem(
            label: context.tr('menu.moveLineDown'),
            icon: Icons.arrow_downward_outlined,
            shortcut: 'Alt+\u2193',
            onTap: () => controller?.moveSelectionLinesDown(),
          ),
        ];
      case 'View':
        final shell = ref.read(ideShellProvider);
        return [
          ContextMenuItem(
            label: context.tr('menu.wordWrap'),
            icon: Icons.wrap_text_outlined,
            shortcut: sc(ShortcutAction.toggleWordWrap),
            onTap:
                () =>
                    ref.read(editorSettingsProvider.notifier).toggleWordWrap(),
          ),
          const ContextMenuSeparator(),
          ContextMenuItem(
            label: context.tr('menu.zoomIn'),
            icon: Icons.zoom_in_outlined,
            shortcut: sc(ShortcutAction.zoomIn),
            onTap: () => ref.read(editorSettingsProvider.notifier).zoomIn(),
          ),
          ContextMenuItem(
            label: context.tr('menu.zoomOut'),
            icon: Icons.zoom_out_outlined,
            shortcut: sc(ShortcutAction.zoomOut),
            onTap: () => ref.read(editorSettingsProvider.notifier).zoomOut(),
          ),
          ContextMenuItem(
            label: context.tr('menu.resetZoom'),
            icon: Icons.center_focus_strong_outlined,
            shortcut: sc(ShortcutAction.resetZoom),
            onTap: () => ref.read(editorSettingsProvider.notifier).resetZoom(),
          ),
          const ContextMenuSeparator(),
          if (!widget.isChildWindow) ...[
            ContextMenuItem(
              label:
                  shell.isZenMode
                      ? context.tr('menu.exitZenMode')
                      : context.tr('menu.zenMode'),
              icon:
                  shell.isZenMode
                      ? Icons.fullscreen_exit_outlined
                      : Icons.fullscreen_outlined,
              onTap: () => ref.read(ideShellProvider.notifier).toggleZenMode(),
            ),
            const ContextMenuSeparator(),
            ContextMenuItem(
              label: context.tr('menu.toggleSidebar'),
              icon: Icons.view_sidebar_outlined,
              shortcut: sc(ShortcutAction.toggleSidebar),
              onTap: () => ref.read(ideShellProvider.notifier).toggleSidebar(),
            ),
            ContextMenuItem(
              label: context.tr('menu.toggleEditor'),
              icon: Icons.edit_outlined,
              shortcut: sc(ShortcutAction.toggleEditor),
              onTap: () => ref.read(ideShellProvider.notifier).toggleEditor(),
            ),
            ContextMenuItem(
              label: context.tr('menu.togglePanel'),
              icon: Icons.space_dashboard_outlined,
              shortcut: sc(ShortcutAction.togglePanel),
              onTap:
                  () => ref.read(ideShellProvider.notifier).toggleBottomPanel(),
            ),
          ],
          const ContextMenuSeparator(),
          ContextMenuItem(
            label: context.tr('menu.toggleMinimap'),
            icon: Icons.map_outlined,
            shortcut: sc(ShortcutAction.toggleMinimap),
            onTap:
                () => ref.read(editorSettingsProvider.notifier).toggleMinimap(),
          ),
          if (widget.includeWindowActions) ...[
            const ContextMenuSeparator(),
            ContextMenuItem(
              label: context.tr('menu.newWindow'),
              icon: Icons.add_to_queue_outlined,
              onTap:
                  () =>
                      ref
                          .read(multiWindowProvider.notifier)
                          .createChildWindow(),
            ),
            ContextMenuItem(
              label: context.tr('menu.closeAllChildWindows'),
              icon: Icons.window_outlined,
              onTap:
                  () =>
                      ref
                          .read(multiWindowProvider.notifier)
                          .closeAllChildWindows(),
            ),
          ],
        ];
      case 'Go':
        return [
          ContextMenuItem(
            label: context.tr('menu.goToLine'),
            icon: Icons.format_list_numbered_outlined,
            shortcut: sc(ShortcutAction.goToLine),
            onTap: () async {
              final activeId =
                  ref.read(editorAreaProvider).tabGroup.activeTabId;
              if (activeId == null) return;
              final controller = ref
                  .read(editorAreaProvider.notifier)
                  .getController(activeId);
              if (controller == null) return;
              final result = await AppDialog.showInputDialog(
                context,
                title: context.tr('dialog.goToLine.title'),
                hintText: context.tr('dialog.goToLine.hint'),
                confirmLabel: context.tr('dialog.goToLine.confirm'),
              );
              if (result == null || result.isEmpty) return;
              final line = int.tryParse(result);
              if (line == null || line < 1) return;
              final target = (line - 1).clamp(0, controller.lineCount - 1);
              controller.selection = CodeLineSelection.collapsed(
                index: target,
                offset: 0,
              );
              controller.makeCursorCenterIfInvisible();
            },
          ),
          ContextMenuItem(
            label: context.tr('menu.goToFile'),
            icon: Icons.description_outlined,
            shortcut: 'Ctrl+P',
            onTap: () {},
          ),
        ];
      case 'Help':
        return [
          ContextMenuItem(
            label: context.tr('settings.editor'),
            icon: Icons.edit_note_outlined,
            onTap:
                () => ref
                    .read(editorAreaProvider.notifier)
                    .openSettingsTab(
                      title: context.tr('settings.title'),
                      section: 'editor',
                    ),
          ),
          ContextMenuItem(
            label: context.tr('settings.terminal'),
            icon: Icons.terminal_outlined,
            onTap:
                () => ref
                    .read(editorAreaProvider.notifier)
                    .openSettingsTab(
                      title: context.tr('settings.title'),
                      section: 'terminal',
                    ),
          ),
          ContextMenuItem(
            label: context.tr('settings.languageServer'),
            icon: Icons.memory_outlined,
            onTap:
                () => ref
                    .read(editorAreaProvider.notifier)
                    .openSettingsTab(
                      title: context.tr('settings.title'),
                      section: 'language_server',
                    ),
          ),
          ContextMenuItem(
            label: context.tr('menu.keyboardShortcuts'),
            icon: Icons.keyboard_outlined,
            onTap:
                () => ref
                    .read(editorAreaProvider.notifier)
                    .openSettingsTab(
                      title: context.tr('settings.title'),
                      section: 'shortcuts',
                    ),
          ),
          ContextMenuItem(
            label: context.tr('settings.appearance'),
            icon: Icons.palette_outlined,
            onTap:
                () => ref
                    .read(editorAreaProvider.notifier)
                    .openSettingsTab(
                      title: context.tr('settings.title'),
                      section: 'appearance',
                    ),
          ),
          ContextMenuItem(
            label: context.tr('settings.codeStats'),
            icon: Icons.pie_chart_outline,
            onTap:
                () => ref
                    .read(editorAreaProvider.notifier)
                    .openSettingsTab(
                      title: context.tr('settings.title'),
                      section: 'code_stats',
                    ),
          ),
          ContextMenuItem(
            label: context.tr('settings.openSource'),
            icon: Icons.code_outlined,
            onTap:
                () => ref
                    .read(editorAreaProvider.notifier)
                    .openSettingsTab(
                      title: context.tr('settings.title'),
                      section: 'open_source',
                    ),
          ),
          const ContextMenuSeparator(),
          ContextMenuItem(
            label: context.tr('menu.about'),
            icon: Icons.info_outline,
            onTap:
                () => ref
                    .read(editorAreaProvider.notifier)
                    .openSettingsTab(
                      title: context.tr('settings.title'),
                      section: 'about',
                    ),
          ),
        ];
      default:
        return [];
    }
  }

  CodeLineEditingController? _activeController() {
    final activeId = ref.read(editorAreaProvider).tabGroup.activeTabId;
    if (activeId == null) return null;
    return ref.read(editorAreaProvider.notifier).getController(activeId);
  }

  void _duplicateSelectionLine({required bool up}) {
    final controller = _activeController();
    if (controller == null) return;
    final sel = controller.selection;
    final lines = controller.codeLines;
    final startLine = sel.startIndex;
    final endLine = sel.endIndex;
    final buffer = StringBuffer();
    for (int i = startLine; i <= endLine; i++) {
      if (i > startLine) buffer.write('\n');
      buffer.write(lines[i].text);
    }
    final duplicatedText = buffer.toString();
    final lineCount = endLine - startLine + 1;

    controller.runRevocableOp(() {
      if (up) {
        final insertPos = CodeLineSelection.collapsed(
          index: startLine,
          offset: 0,
        );
        controller.replaceSelection('$duplicatedText\n', insertPos);
        controller.selection = CodeLineSelection.collapsed(
          index: startLine,
          offset: sel.extentOffset,
        );
      } else {
        final insertPos = CodeLineSelection.collapsed(
          index: endLine,
          offset: lines[endLine].text.length,
        );
        controller.replaceSelection('\n$duplicatedText', insertPos);
        controller.selection = CodeLineSelection.collapsed(
          index: endLine + lineCount,
          offset: sel.extentOffset,
        );
      }
      controller.makeCursorCenterIfInvisible();
    });
  }

  Map<String, Rect> _computeButtonRects() {
    final rects = <String, Rect>{};
    for (final entry in _menuKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final pos = box.localToGlobal(Offset.zero);
        rects[entry.key] = pos & box.size;
      }
    }
    return rects;
  }

  void _toggleMenu(String label) {
    if (_activeMenu == label) {
      _closeMenu();
    } else {
      _showMenuDropdown(label);
    }
  }

  void _switchToMenu(String label) {
    if (_activeMenu == label) return;
    _showMenuDropdown(label);
  }

  void _showMenuDropdown(String label) {
    _removeOverlay();

    final key = _menuKeys[label];
    if (key == null) return;

    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final items = _buildMenuItems(label);
    final buttonRects = _computeButtonRects();

    setState(() => _activeMenu = label);

    _overlayEntry = OverlayEntry(
      builder:
          (ctx) => _MenuDropdown(
            position: Offset(position.dx, position.dy + size.height),
            items: items,
            onDismiss: _closeMenu,
            menuButtonRects: buttonRects,
            onHoverButton: _switchToMenu,
            onClickButton: _toggleMenu,
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _closeMenu() {
    _removeOverlay();
    if (_activeMenu != null) {
      setState(() => _activeMenu = null);
    }
  }

  void _showRecentSubmenu() {
    final recentFiles = ref.read(recentFilesProvider);
    if (recentFiles.isEmpty) return;

    final key = _menuKeys['File'];
    if (key == null) return;
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final items =
        recentFiles.map((entry) {
          return ContextMenuItem(
            label: entry.name,
            subtitle: entry.path,
            icon:
                entry.isFolder
                    ? Icons.folder_outlined
                    : Icons.description_outlined,
            onTap: () {
              if (entry.isFolder) {
                ref.read(fileExplorerProvider.notifier).openFolder(entry.path);
              } else {
                ref
                    .read(editorAreaProvider.notifier)
                    .openTab(entry.name, entry.path);
              }
              ref
                  .read(recentFilesProvider.notifier)
                  .addRecent(entry.name, entry.path, entry.isFolder);
            },
          );
        }).toList();

    _removeOverlay();
    setState(() => _activeMenu = 'File');

    _overlayEntry = OverlayEntry(
      builder:
          (ctx) => _MenuDropdown(
            position: Offset(position.dx, position.dy + size.height),
            items: items,
            onDismiss: _closeMenu,
            menuButtonRects: _computeButtonRects(),
            onHoverButton: _switchToMenu,
            onClickButton: _toggleMenu,
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          if (_activeMenu != null) {
            _closeMenu();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            _menuLabels.map((label) {
              final isActive = _activeMenu == label;
              return _TopLevelMenuItem(
                key: _menuKeys[label],
                label: _menuTitle(context, label),
                isActive: isActive,
                onTap: () => _toggleMenu(label),
              );
            }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top-level menu button (e.g. "File", "Edit")
// ---------------------------------------------------------------------------

class _TopLevelMenuItem extends StatefulWidget {
  const _TopLevelMenuItem({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_TopLevelMenuItem> createState() => _TopLevelMenuItemState();
}

class _TopLevelMenuItemState extends State<_TopLevelMenuItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                widget.isActive
                    ? AppColors.listActiveSelectionBackground
                    : _isHovering
                    ? AppColors.hoverHighlight
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.label,
            style: context.trStyle(AppTextStyles.menuItem),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dropdown overlay panel
// ---------------------------------------------------------------------------

class _MenuDropdown extends StatelessWidget {
  const _MenuDropdown({
    required this.position,
    required this.items,
    required this.onDismiss,
    required this.menuButtonRects,
    required this.onHoverButton,
    required this.onClickButton,
  });

  final Offset position;
  final List<ContextMenuItem> items;
  final VoidCallback onDismiss;
  final Map<String, Rect> menuButtonRects;
  final ValueChanged<String> onHoverButton;
  final ValueChanged<String> onClickButton;

  String? _hitTestButton(Offset globalPosition) {
    for (final entry in menuButtonRects.entries) {
      if (entry.value.contains(globalPosition)) {
        return entry.key;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const menuWidth = 220.0;

    double menuHeight = 0;
    for (final item in items) {
      if (item is ContextMenuSeparator) {
        menuHeight += 9;
      } else {
        menuHeight += 28;
      }
    }
    menuHeight += 8;

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
        // Dismiss layer 鈥?uses Listener for instant response + hover tracking
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              final label = _hitTestButton(event.position);
              if (label != null) {
                onClickButton(label);
              } else {
                onDismiss();
              }
            },
            onPointerHover: (event) {
              final label = _hitTestButton(event.position);
              if (label != null) {
                onHoverButton(label);
              }
            },
            child: const SizedBox.expand(),
          ),
        ),
        // Menu panel
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
                      return _DropdownMenuItem(
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

// ---------------------------------------------------------------------------
// Individual dropdown menu item
// ---------------------------------------------------------------------------

class _DropdownMenuItem extends StatefulWidget {
  const _DropdownMenuItem({required this.item, required this.onDismiss});

  final ContextMenuItem item;
  final VoidCallback onDismiss;

  @override
  State<_DropdownMenuItem> createState() => _DropdownMenuItemState();
}

class _DropdownMenuItemState extends State<_DropdownMenuItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  widget.item.label,
                  style: context.trStyle(
                    AppTextStyles.uiSmall.copyWith(color: AppColors.foreground),
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
                    zhDelta: -0.6,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
