import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bewy/core/editor/re_editor_compat.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/providers/app_boot_provider.dart';
import '../../../core/providers/multi_window_provider.dart';
import '../../../core/providers/recent_files_provider.dart';
import '../../../core/providers/shortcut_settings_provider.dart';
import '../../../core/services/app_log_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../editor_area/presentation/editor_area.dart';
import '../../editor_area/presentation/editor_area_provider.dart';
import '../../editor_area/presentation/editor_settings_provider.dart';
import '../../file_explorer/presentation/file_explorer_provider.dart';
import 'package:bewy/features/title_bar/widgets/menu_bar_widget.dart';

class ChildWindowShell extends ConsumerStatefulWidget {
  const ChildWindowShell({super.key});

  @override
  ConsumerState<ChildWindowShell> createState() => _ChildWindowShellState();
}

class _ChildWindowShellState extends ConsumerState<ChildWindowShell>
    with WindowListener {
  bool _isAutoHiding = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
    AppLogService.instance.info('window', 'childWindow init');
    ref.read(multiWindowProvider.notifier).ensureInitialized();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    final initial = ref.read(appBootProvider).initialTabPayload;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final editor = ref.read(editorAreaProvider.notifier);
      if (initial != null) {
        await editor.openTransferredTab(initial, activate: true);
        return;
      }
      if (ref.read(editorAreaProvider).tabGroup.tabs.isEmpty) {
        editor.createNewTab();
      }
    });

    ref.listen<EditorAreaState>(editorAreaProvider, (prev, next) {
      if (_isAutoHiding) return;
      if (next.tabGroup.tabs.isEmpty) {
        _isAutoHiding = true;
        ref
            .read(multiWindowProvider.notifier)
            .hideCurrentWindow()
            .whenComplete(() => _isAutoHiding = false);
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    windowManager.removeListener(this);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    for (final action in ShortcutAction.values) {
      final matched = ref
          .read(shortcutSettingsProvider.notifier)
          .matches(action, event);
      if (matched) {
        _runShortcutAction(action);
        return true;
      }
    }
    return false;
  }

  void _runShortcutAction(ShortcutAction action) {
    if (!mounted) return;
    AppLogService.instance.info('shortcut', 'childAction=${action.name}');
    switch (action) {
      case ShortcutAction.undo:
        _getActiveController()?.undo();
        break;
      case ShortcutAction.redo:
        _getActiveController()?.redo();
        break;
      case ShortcutAction.cut:
        _getActiveController()?.cut();
        break;
      case ShortcutAction.copy:
        _getActiveController()?.copy();
        break;
      case ShortcutAction.paste:
        _getActiveController()?.paste();
        break;
      case ShortcutAction.selectAll:
        _getActiveController()?.selectAll();
        break;
      case ShortcutAction.toggleWordWrap:
        ref.read(editorSettingsProvider.notifier).toggleWordWrap();
        break;
      case ShortcutAction.toggleMinimap:
        ref.read(editorSettingsProvider.notifier).toggleMinimap();
        break;
      case ShortcutAction.save:
        ref.read(editorAreaProvider.notifier).saveActiveTab();
        break;
      case ShortcutAction.saveAs:
        ref.read(editorAreaProvider.notifier).saveActiveTabAs();
        break;
      case ShortcutAction.newFile:
        ref.read(editorAreaProvider.notifier).createNewTab();
        break;
      case ShortcutAction.closeTab:
        final activeId = ref.read(editorAreaProvider).tabGroup.activeTabId;
        if (activeId != null) {
          handleTabCloseWithSaveCheck(context, ref, activeId);
        }
        break;
      case ShortcutAction.openFile:
        () async {
          final result = await FilePicker.platform.pickFiles();
          if (result != null && result.files.single.path != null && mounted) {
            final file = result.files.single;
            await ref
                .read(editorAreaProvider.notifier)
                .openTab(file.name, file.path!);
            ref
                .read(recentFilesProvider.notifier)
                .addRecent(file.name, file.path!, false);
          }
        }();
        break;
      case ShortcutAction.nextTab:
        ref.read(editorAreaProvider.notifier).activateNextTab();
        break;
      case ShortcutAction.previousTab:
        ref.read(editorAreaProvider.notifier).activatePreviousTab();
        break;
      case ShortcutAction.find:
        ref
            .read(editorAreaProvider.notifier)
            .getActiveFindController()
            ?.findMode();
        break;
      case ShortcutAction.replace:
        ref
            .read(editorAreaProvider.notifier)
            .getActiveFindController()
            ?.replaceMode();
        break;
      case ShortcutAction.findInFiles:
        _openWorkspaceSearchDialog(initialReplaceMode: false);
        break;
      case ShortcutAction.replaceInFiles:
        _openWorkspaceSearchDialog(initialReplaceMode: true);
        break;
      case ShortcutAction.formatDocument:
        ref.read(editorAreaProvider.notifier).formatActiveTab();
        break;
      case ShortcutAction.goToLine:
        _showGoToLineDialog();
        break;
      case ShortcutAction.zoomIn:
        ref.read(editorSettingsProvider.notifier).zoomIn();
        break;
      case ShortcutAction.zoomOut:
        ref.read(editorSettingsProvider.notifier).zoomOut();
        break;
      case ShortcutAction.resetZoom:
        ref.read(editorSettingsProvider.notifier).resetZoom();
        break;
      case ShortcutAction.duplicateLineUp:
      case ShortcutAction.duplicateLineDown:
      case ShortcutAction.toggleSidebar:
      case ShortcutAction.togglePanel:
      case ShortcutAction.toggleEditor:
        break;
      case ShortcutAction.showCodeActions:
        () async {
          final controller = _getActiveController();
          if (controller == null) return;
          final applied = await controller.applyFirstCodeAction();
          if (!mounted) return;
          final message =
              applied
                  ? context.tr('status.codeActionApplied')
                  : context.tr('status.codeActionUnavailable');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }();
        break;
      case ShortcutAction.signatureHelp:
        () async {
          final controller = _getActiveController();
          if (controller == null) return;
          final ok = await controller.requestSignatureHelp();
          if (!mounted || ok) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('status.signatureHelpUnavailable')),
            ),
          );
        }();
        break;
    }
  }

  Future<void> _openWorkspaceSearchDialog({
    required bool initialReplaceMode,
  }) async {
    final rootPath = ref.read(fileExplorerProvider).rootPath;
    if (rootPath == null || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('status.workspaceSearchFolderRequired')),
        ),
      );
      return;
    }

    await AppDialog.showWorkspaceSearchAndReplace(
      context,
      rootPath: rootPath,
      initialReplaceMode: initialReplaceMode,
      onOpenResult: (filePath, line) async {
        final name = filePath.split(RegExp(r'[/\\]')).last;
        await ref.read(editorAreaProvider.notifier).openTab(name, filePath);
        final activeId = ref.read(editorAreaProvider).tabGroup.activeTabId;
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
  }

  Future<void> _showGoToLineDialog() async {
    final activeId = ref.read(editorAreaProvider).tabGroup.activeTabId;
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
  }

  CodeLineEditingController? _getActiveController() {
    final activeId = ref.read(editorAreaProvider).tabGroup.activeTabId;
    if (activeId == null) return null;
    return ref.read(editorAreaProvider.notifier).getController(activeId);
  }

  Future<void> _closeWindowNow() async {
    if (_isClosing) return;
    _isClosing = true;
    AppLogService.instance.info('window', 'childWindow closeRequested');

    final notifier = ref.read(editorAreaProvider.notifier);
    if (!notifier.hasUnsavedChanges()) {
      await _terminateWindowNow();
      return;
    }

    if (!mounted) {
      _isClosing = false;
      return;
    }

    final modifiedTabs = notifier.getModifiedTabs();
    final fileNames = modifiedTabs.map((t) => t.fileName).toList();
    final result = await AppDialog.showConfirmSaveAll(context, fileNames);

    if (result == 'save') {
      for (final tab in modifiedTabs) {
        await notifier.saveTab(tab.id);
      }
      AppLogService.instance.info('window', 'childWindow closeAfterSave');
      await _terminateWindowNow();
    } else if (result == 'discard') {
      AppLogService.instance.info('window', 'childWindow closeDiscard');
      await _terminateWindowNow();
    } else {
      AppLogService.instance.info('window', 'childWindow closeCancelled');
      _isClosing = false;
    }
  }

  Future<void> _terminateWindowNow() async {
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  @override
  void onWindowClose() {
    if (_isClosing) return;
    if (ref.read(multiWindowProvider.notifier).isForceClosingCurrentWindow) {
      return;
    }
    _closeWindowNow();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(editorSettingsProvider, (prev, next) {
      ref.read(editorAreaProvider.notifier).autoSaveMode = next.autoSaveMode;
      ref.read(editorAreaProvider.notifier).autoSaveDelayMs =
          next.autoSaveDelayMs;
      ref.read(editorAreaProvider.notifier).autoFormatOnSave =
          next.autoFormatOnSave;
      ref.read(editorAreaProvider.notifier).indentSize = next.indentSize;
      ref.read(editorAreaProvider.notifier).trimTrailingWhitespace =
          next.trimTrailingWhitespace;
      ref.read(editorAreaProvider.notifier).defaultFileEncoding =
          next.defaultFileEncoding;
    });

    return Scaffold(
      backgroundColor: AppColors.deepBackground,
      body: Column(
        children: [
          Container(
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.titleBarBackground,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                _DraggableArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Image.asset(
                      'assets/icons/logo.png',
                      width: 14,
                      height: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const MenuBarWidget(
                  includeHelpMenu: false,
                  includeWindowActions: false,
                  isChildWindow: true,
                ),
                const Expanded(child: _DraggableArea(child: SizedBox.expand())),
                _ChildCloseButton(onTap: _closeWindowNow),
              ],
            ),
          ),
          const Expanded(child: EditorArea()),
        ],
      ),
    );
  }
}

class _ChildCloseButton extends StatefulWidget {
  const _ChildCloseButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  State<_ChildCloseButton> createState() => _ChildCloseButtonState();
}

class _ChildCloseButtonState extends State<_ChildCloseButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () => widget.onTap(),
        child: Container(
          width: 36,
          height: 30,
          color:
              _hovering
                  ? AppColors.error.withValues(alpha: 0.8)
                  : Colors.transparent,
          alignment: Alignment.center,
          child: Icon(
            Icons.close,
            size: 14,
            color: _hovering ? Colors.white : AppColors.secondaryForeground,
          ),
        ),
      ),
    );
  }
}

class _DraggableArea extends StatelessWidget {
  const _DraggableArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      child: child,
    );
  }
}
