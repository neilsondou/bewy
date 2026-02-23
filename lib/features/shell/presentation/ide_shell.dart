import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bewy/core/editor/re_editor_compat.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/layout_constants.dart';
import '../../../core/providers/app_boot_provider.dart';
import '../../../core/providers/recent_files_provider.dart';
import '../../../core/providers/multi_window_provider.dart';
import '../../../core/providers/shortcut_settings_provider.dart';
import '../../../core/services/app_exit_service.dart';
import '../../../core/services/app_log_service.dart';
import '../../../core/services/config_service.dart';
import '../../../core/services/exit_guardian_service.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../l10n/app_localizations.dart';
import 'ide_shell_provider.dart';
import '../widgets/resizable_divider.dart';
import '../../title_bar/presentation/title_bar.dart';
import '../../file_explorer/presentation/file_explorer.dart';
import '../../file_explorer/presentation/file_explorer_provider.dart';
import '../../editor_area/presentation/editor_area.dart';
import '../../editor_area/presentation/editor_area_provider.dart';
import '../../editor_area/presentation/editor_settings_provider.dart';
import '../../editor_area/widgets/welcome_tab.dart';
import '../../bottom_panel/presentation/bottom_panel.dart';
import '../../status_bar/presentation/status_bar.dart';
import '../../status_bar/presentation/status_notification_provider.dart';

/// Root layout widget 閳?glassmorphism IDE shell.
class IDEShell extends ConsumerStatefulWidget {
  const IDEShell({super.key});

  @override
  ConsumerState<IDEShell> createState() => _IDEShellState();
}

class _IDEShellState extends ConsumerState<IDEShell> with WindowListener {
  bool _isClosing = false;
  bool _isDragHovering = false;
  bool _applyingZenMode = false;
  bool _privacyDialogShown = false;
  StreamSubscription<ExternalFileSyncEvent>? _externalSyncSubscription;

  bool _restoredFolder = false;
  String? _lastPrewarmWorkspace;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
    AppLogService.instance.info('window', 'mainWindow init');
    AppExitService.registerCloseHandler(_requestWindowClose);
    ref.read(multiWindowProvider.notifier).ensureInitialized();
    final boot = ref.read(appBootProvider);
    if (!boot.isChildWindow) {
      unawaited(ExitGuardianService.ensureStarted());
      unawaited(ref.read(editorAreaProvider.notifier).restoreHotExitSnapshot());
      unawaited(_ensurePrivacyConsent());
      final startupWorkspace = ref.read(fileExplorerProvider).rootPath;
      if (startupWorkspace != null && startupWorkspace.isNotEmpty) {
        _lastPrewarmWorkspace = startupWorkspace;
        unawaited(
          ref
              .read(editorAreaProvider.notifier)
              .startWorkspaceDiagnostics(workspacePath: startupWorkspace),
        );
      }
    }
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _externalSyncSubscription = ref
        .read(editorAreaProvider.notifier)
        .externalFileSyncEvents
        .listen((event) {
          if (!mounted) return;
          final notifier = ref.read(statusNotificationProvider.notifier);
          if (event.type == ExternalFileSyncType.reloaded) {
            notifier.show(
              '${context.tr('status.externalSyncReloadedPrefix')}${event.fileName}',
              type: StatusNotificationType.info,
            );
          } else {
            notifier.show(
              '${context.tr('status.externalSyncConflictPrefix')}${event.fileName}',
              type: StatusNotificationType.error,
            );
          }
        });
  }

  @override
  void dispose() {
    _externalSyncSubscription?.cancel();
    AppExitService.unregisterCloseHandler();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    windowManager.removeListener(this);
    super.dispose();
  }

  // 閳光偓閳光偓 Global keyboard shortcut handler 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
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
    AppLogService.instance.info('shortcut', 'action=${action.name}');
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
      case ShortcutAction.duplicateLineUp:
        _duplicateLine(up: true);
        break;
      case ShortcutAction.duplicateLineDown:
        _duplicateLine(up: false);
        break;
      case ShortcutAction.toggleSidebar:
        ref.read(ideShellProvider.notifier).toggleSidebar();
        break;
      case ShortcutAction.togglePanel:
        ref.read(ideShellProvider.notifier).toggleBottomPanel();
        break;
      case ShortcutAction.toggleEditor:
        ref.read(ideShellProvider.notifier).toggleEditor();
        break;
      case ShortcutAction.toggleMinimap:
        ref.read(editorSettingsProvider.notifier).toggleMinimap();
        break;
      case ShortcutAction.save:
        () async {
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
        }();
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
            ref
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
        () async {
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
        }();
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
      case ShortcutAction.showCodeActions:
        () async {
          final controller = _getActiveController();
          if (controller == null) return;
          final applied = await controller.applyFirstCodeAction();
          if (!mounted) return;
          if (applied) {
            ref
                .read(statusNotificationProvider.notifier)
                .show(
                  context.tr('status.codeActionApplied'),
                  type: StatusNotificationType.success,
                );
            return;
          }
          final available = controller.availableCodeActionCount;
          ref
              .read(statusNotificationProvider.notifier)
              .show(
                available > 0
                    ? context.tr('status.codeActionNotApplicable')
                    : context.tr('status.codeActionUnavailable'),
                type: StatusNotificationType.info,
              );
        }();
        break;
      case ShortcutAction.signatureHelp:
        () async {
          final controller = _getActiveController();
          if (controller == null) return;
          final ok = await controller.requestSignatureHelp();
          if (!mounted || ok) return;
          ref
              .read(statusNotificationProvider.notifier)
              .show(
                context.tr('status.signatureHelpUnavailable'),
                type: StatusNotificationType.info,
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

  void _showGoToLineDialog() async {
    final controller = _getActiveController();
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

    final targetLine = (line - 1).clamp(0, controller.lineCount - 1);
    controller.selection = CodeLineSelection.collapsed(
      index: targetLine,
      offset: 0,
    );
    controller.makeCursorCenterIfInvisible();
  }

  CodeLineEditingController? _getActiveController() {
    final activeId = ref.read(editorAreaProvider).tabGroup.activeTabId;
    if (activeId == null) return null;
    return ref.read(editorAreaProvider.notifier).getController(activeId);
  }

  void _duplicateLine({required bool up}) {
    final controller = _getActiveController();
    if (controller == null) return;

    final sel = controller.selection;
    final startLine = sel.startIndex;
    final endLine = sel.endIndex;

    // Collect the text of lines to duplicate
    final lines = controller.codeLines;
    final buffer = StringBuffer();
    for (int i = startLine; i <= endLine; i++) {
      if (i > startLine) buffer.write('\n');
      buffer.write(lines[i].text);
    }
    final duplicatedText = buffer.toString();
    final lineCount = endLine - startLine + 1;

    controller.runRevocableOp(() {
      if (up) {
        // Insert duplicated lines above the current selection
        // Place the text at the start of startLine
        final insertPos = CodeLineSelection.collapsed(
          index: startLine,
          offset: 0,
        );
        controller.replaceSelection('$duplicatedText\n', insertPos);
        // Move cursor back to the original position (now shifted down)
        controller.selection = CodeLineSelection.collapsed(
          index: startLine,
          offset: sel.extentOffset,
        );
      } else {
        // Insert duplicated lines below the current selection
        final lineText = lines[endLine].text;
        final insertPos = CodeLineSelection.collapsed(
          index: endLine,
          offset: lineText.length,
        );
        controller.replaceSelection('\n$duplicatedText', insertPos);
        // Move cursor to the duplicated lines
        controller.selection = CodeLineSelection.collapsed(
          index: endLine + lineCount,
          offset: sel.extentOffset,
        );
      }
    });
  }

  // 閳光偓閳光偓 Window close handler 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
  @override
  void onWindowClose() {
    _requestWindowClose();
  }

  Future<void> _requestWindowClose() async {
    if (_isClosing) return;
    _isClosing = true;
    AppLogService.instance.info('window', 'mainWindow closeRequested');
    await _handleWindowClose();
  }

  // 閳光偓閳光偓 Window blur handler (auto-save on focus lost) 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
  @override
  void onWindowBlur() {
    final autoSave = ref.read(editorSettingsProvider).autoSaveMode;
    if (autoSave == AutoSaveMode.onFocusLost) {
      ref.read(editorAreaProvider.notifier).saveAllModifiedTabs();
    }
  }

  Future<void> _handleWindowClose() async {
    final notifier = ref.read(editorAreaProvider.notifier);
    final childUnsaved =
        await ref
            .read(multiWindowProvider.notifier)
            .collectUnsavedFileNamesFromChildren();
    final localModifiedTabs = notifier.getModifiedTabs();

    if (localModifiedTabs.isEmpty && childUnsaved.isEmpty) {
      AppLogService.instance.info('window', 'closeWithoutUnsavedChanges');
      await _shutdownApplication();
      return;
    }

    if (!mounted) {
      _isClosing = false;
      return;
    }

    final fileNames = <String>[
      ...localModifiedTabs.map((t) => t.fileName),
      ...childUnsaved,
    ];
    final result = await AppDialog.showConfirmSaveAll(context, fileNames);

    if (result == 'save') {
      AppLogService.instance.info('window', 'closeFlow saveAll');
      for (final tab in localModifiedTabs) {
        final saved = await notifier.saveTab(tab.id);
        if (!saved) {
          AppLogService.instance.warn(
            'window',
            'closeAborted saveFailed tab=${tab.fileName}',
          );
          _isClosing = false;
          return;
        }
      }
      final childSaved =
          await ref.read(multiWindowProvider.notifier).saveUnsavedInChildren();
      if (!childSaved) {
        AppLogService.instance.warn('window', 'closeAborted childSaveFailed');
        _isClosing = false;
        return;
      }
      await _shutdownApplication();
    } else if (result == 'discard') {
      AppLogService.instance.info('window', 'closeFlow discardAll');
      await _shutdownApplication();
    } else {
      AppLogService.instance.info('window', 'closeFlow cancelled');
      _isClosing = false;
    }
  }

  Future<void> _shutdownApplication() async {
    AppLogService.instance.info('window', 'shutdown begin');
    await AppLogService.instance.flush();
    await ref.read(editorAreaProvider.notifier).clearHotExitSnapshot();
    await ExitGuardianService.requestKillAll();
    try {
      await ref
          .read(multiWindowProvider.notifier)
          .terminateAllChildWindows()
          .timeout(const Duration(milliseconds: 1200));
    } catch (_) {}
    try {
      await windowManager.setPreventClose(false);
      await windowManager.close().timeout(
        const Duration(milliseconds: 600),
        onTimeout: () {},
      );
    } catch (_) {
      AppLogService.instance.error('window', 'shutdown closeFailed');
      _isClosing = false;
      return;
    }

    // Final fallback: avoid main process hanging when window manager close
    // does not terminate due to multi-window/plugin edge cases.
    if (Platform.isWindows) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      await AppLogService.instance.flush();
      exit(0);
    }
  }

  Future<void> _applyZenModeWindow(bool enabled) async {
    if (_applyingZenMode) return;
    _applyingZenMode = true;
    try {
      await windowManager.setFullScreen(enabled);
    } catch (_) {
    } finally {
      _applyingZenMode = false;
    }
  }

  Future<void> _ensurePrivacyConsent() async {
    if (!mounted || _privacyDialogShown) return;
    final data = await ConfigService.load();
    if ((data['privacyConsentAccepted'] as bool?) == true) return;
    _privacyDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final accepted = await AppDialog.showPrivacyConsent(context) ?? false;
      if (accepted) {
        final latest = await ConfigService.load();
        latest['privacyConsentAccepted'] = true;
        await ConfigService.save(latest);
        AppLogService.instance.info('privacy', 'consent accepted');
        return;
      }
      AppLogService.instance.warn('privacy', 'consent declined');
      await _forceCloseAfterPrivacyDeclined();
    });
  }

  Future<void> _forceCloseAfterPrivacyDeclined() async {
    try {
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (_) {}
    if (Platform.isWindows) {
      exit(0);
    }
  }

  // 閳光偓閳光偓 Build 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
  @override
  Widget build(BuildContext context) {
    final shell = ref.watch(ideShellProvider);

    // Sync auto-save mode and delay to editor area notifier.
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

    // Auto-open the most recent folder on startup (once).
    ref.listen(recentFilesProvider, (prev, next) {
      final shouldRestoreFolder =
          ref.read(editorSettingsProvider).openLastFolderOnStartup;
      if (!_restoredFolder && shouldRestoreFolder && next.isNotEmpty) {
        _restoredFolder = true;
        final lastFolder = next.where((e) => e.isFolder).firstOrNull;
        if (lastFolder != null && Directory(lastFolder.path).existsSync()) {
          ref.read(fileExplorerProvider.notifier).openFolder(lastFolder.path);
        }
      }
    });

    ref.listen(fileExplorerProvider, (prev, next) {
      final root = next.rootPath;
      if (root == null || root.isEmpty) return;
      if (_lastPrewarmWorkspace == root) return;
      _lastPrewarmWorkspace = root;
      unawaited(
        ref
            .read(editorAreaProvider.notifier)
            .startWorkspaceDiagnostics(workspacePath: root),
      );
    });

    ref.listen(ideShellProvider, (prev, next) {
      if (prev?.isZenMode != next.isZenMode) {
        unawaited(_applyZenModeWindow(next.isZenMode));
      }
    });

    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: Scaffold(
        backgroundColor: AppColors.deepBackground,
        body: DropTarget(
          onDragDone: (details) {
            for (final file in details.files) {
              final path = file.path;
              final name = path.split(RegExp(r'[/\\]')).last;
              ref.read(editorAreaProvider.notifier).openTab(name, path);
              ref
                  .read(recentFilesProvider.notifier)
                  .addRecent(name, path, false);
            }
            setState(() => _isDragHovering = false);
          },
          onDragEntered: (_) => setState(() => _isDragHovering = true),
          onDragExited: (_) => setState(() => _isDragHovering = false),
          child: Stack(
            children: [
              Column(
                children: [
                  if (!shell.isZenMode) const TitleBar(),
                  Expanded(
                    child: Row(
                      children: [
                        if (shell.sideBarWidth > 0) ...[
                          SizedBox(
                            width: shell.sideBarWidth,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.sideBarBackground,
                              ),
                              child: const FileExplorer(),
                            ),
                          ),
                          ResizableDivider(
                            isHorizontal: false,
                            onDrag: (delta) {
                              ref
                                  .read(ideShellProvider.notifier)
                                  .setSideBarWidth(shell.sideBarWidth + delta);
                            },
                            onDoubleTap: () {
                              ref
                                  .read(ideShellProvider.notifier)
                                  .setSideBarWidth(
                                    LayoutConstants.sideBarDefaultWidth,
                                  );
                            },
                          ),
                        ],
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child:
                                    shell.editorVisible
                                        ? const EditorArea()
                                        : const WelcomeTab(),
                              ),
                              if (!shell.isZenMode &&
                                  shell.bottomPanelVisible) ...[
                                ResizableDivider(
                                  isHorizontal: true,
                                  onDrag: (delta) {
                                    ref
                                        .read(ideShellProvider.notifier)
                                        .setBottomPanelHeight(
                                          shell.bottomPanelHeight - delta,
                                        );
                                  },
                                  onDoubleTap: () {
                                    ref
                                        .read(ideShellProvider.notifier)
                                        .setBottomPanelHeight(
                                          LayoutConstants
                                              .bottomPanelDefaultHeight,
                                        );
                                  },
                                ),
                                SizedBox(
                                  height: shell.bottomPanelHeight,
                                  child: const BottomPanel(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!shell.isZenMode) const StatusBar(),
                ],
              ),
              // Drag hover overlay.
              if (_isDragHovering)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              if (shell.isZenMode)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _ZenExitButton(
                    label: context.tr('menu.exitZenMode'),
                    onTap:
                        () =>
                            ref.read(ideShellProvider.notifier).toggleZenMode(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent &&
        HardwareKeyboard.instance.isControlPressed) {
      if (event.scrollDelta.dy < 0) {
        ref.read(editorSettingsProvider.notifier).zoomIn();
      } else if (event.scrollDelta.dy > 0) {
        ref.read(editorSettingsProvider.notifier).zoomOut();
      }
    }
  }
}

class _ZenExitButton extends StatefulWidget {
  const _ZenExitButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_ZenExitButton> createState() => _ZenExitButtonState();
}

class _ZenExitButtonState extends State<_ZenExitButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color:
                _hovering
                    ? AppColors.listActiveSelectionBackground
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(widget.label, style: AppTextStyles.uiSmall),
        ),
      ),
    );
  }
}
