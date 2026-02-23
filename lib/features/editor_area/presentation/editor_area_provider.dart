import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:charset/charset.dart' as charset;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bewy/core/editor/re_editor_compat.dart';
import '../../../core/models/timeline_event.dart';
import '../../../core/providers/timeline_provider.dart';
import '../../../core/services/app_log_service.dart';
import '../../../core/services/code_format_service.dart';
import '../../../core/services/config_service.dart';
import '../../../core/services/tree_sitter_service.dart';
import '../models/editor_tab_model.dart';
import '../models/tab_group_model.dart';
import 'editor_settings_provider.dart';

class EditorAreaState {
  const EditorAreaState({this.tabGroup = const TabGroupModel()});

  final TabGroupModel tabGroup;

  EditorAreaState copyWith({TabGroupModel? tabGroup}) {
    return EditorAreaState(tabGroup: tabGroup ?? this.tabGroup);
  }
}

enum ExternalFileSyncType { reloaded, conflict }

class ExternalFileSyncEvent {
  const ExternalFileSyncEvent({
    required this.tabId,
    required this.fileName,
    required this.type,
  });

  final String tabId;
  final String fileName;
  final ExternalFileSyncType type;
}

class EditorDiagnosticItem {
  const EditorDiagnosticItem({
    required this.tabId,
    required this.fileName,
    required this.filePath,
    required this.diagnostic,
  });

  final String tabId;
  final String fileName;
  final String? filePath;
  final CodeLspDiagnostic diagnostic;
}

class EditorLspConnectionItem {
  const EditorLspConnectionItem({
    required this.tabId,
    required this.fileName,
    required this.filePath,
    required this.languageId,
    required this.workspacePath,
    required this.serverExecutable,
  });

  final String tabId;
  final String fileName;
  final String? filePath;
  final String languageId;
  final String? workspacePath;
  final String? serverExecutable;
}

class EditorDiagnosticsSummary {
  const EditorDiagnosticsSummary({
    required this.errorCount,
    required this.warningCount,
    required this.infoCount,
  });

  final int errorCount;
  final int warningCount;
  final int infoCount;
}

class FileDiagnosticsSummary {
  const FileDiagnosticsSummary({
    required this.errorCount,
    required this.warningCount,
    required this.infoCount,
  });

  final int errorCount;
  final int warningCount;
  final int infoCount;

  int get total => errorCount + warningCount + infoCount;
}

class WorkspaceDiagnosticsProgress {
  const WorkspaceDiagnosticsProgress({
    required this.isActive,
    required this.processed,
    required this.total,
  });

  final bool isActive;
  final int processed;
  final int total;

  double get ratio {
    if (total <= 0) return 0;
    return (processed / total).clamp(0, 1).toDouble();
  }
}

class _TransientLspRuntime {
  _TransientLspRuntime({
    required this.languageId,
    required this.serverExecutable,
    required this.workspacePath,
  });

  final String languageId;
  String? serverExecutable;
  String? workspacePath;
  int activeCount = 0;
}

class EditorAreaNotifier extends StateNotifier<EditorAreaState> {
  EditorAreaNotifier({
    Ref? ref,
    this.autoSaveMode = AutoSaveMode.off,
    this.autoSaveDelayMs = 1000,
    this.autoFormatOnSave = false,
    this.indentSize = 2,
    this.trimTrailingWhitespace = false,
    this.defaultFileEncoding = FileEncodingOption.utf8,
    this.hotExitEnabled = true,
    this.hotExitSnapshotPath,
    this.allowHotExitInTests = false,
  }) : _ref = ref,
       super(const EditorAreaState()) {
    _initHotExitSettings();
  }

  final Ref? _ref;

  AutoSaveMode autoSaveMode;
  int autoSaveDelayMs;
  bool autoFormatOnSave;
  int indentSize;
  bool trimTrailingWhitespace;
  FileEncodingOption defaultFileEncoding;
  final bool hotExitEnabled;
  final String? hotExitSnapshotPath;
  final bool allowHotExitInTests;

  final Map<String, CodeLineEditingController> _controllers = {};
  final Map<String, CodeLineEditingController> _lspWarmupControllers = {};
  final Map<String, CodeLineEditingController> _workspaceDiagnosticControllers =
      {};
  final Map<String, List<CodeLspDiagnostic>> _workspaceDiagnosticsByPath = {};
  final Map<String, CodeFindController> _findControllers = {};
  final Map<String, String> _savedContent = {};
  final Map<String, bool> _cachedModified = {};
  final Map<String, bool> _readOnlyTabs = {};
  final Map<String, String> _snapshotSourcePaths = {};
  final Map<String, Set<int>> _diffLinesByTab = {};
  final Map<String, void Function()> _diagnosticListeners = {};
  final Map<String, void Function()> _workspaceDiagnosticListeners = {};
  final Map<String, StreamSubscription<FileSystemEvent>> _fileWatchers = {};
  final Map<String, Timer> _fileWatchDebounceTimers = {};
  final Map<String, StreamSubscription<FileSystemEvent>>
  _workspaceProblemWatchers = {};
  final Map<String, Timer> _workspaceProblemDebounceTimers = {};
  final Map<String, Timer> _editedFileDiagnosticsDebounceTimers = {};
  final Map<String, _TransientLspRuntime> _transientLspRuntimeByLanguage = {};
  final Set<String> _workspacePlannedLspLanguages = {};
  final Set<String> _primaryLspLanguages = {};
  final Map<String, CodeLineEditingController> _primaryLspControllers = {};
  final Set<String> _editedTabs = {};
  final Map<String, int> _diagnosticJumpIndexByScope = {};
  final Map<String, DateTime> _lastKnownModified = {};
  final StreamController<ExternalFileSyncEvent> _externalSyncController =
      StreamController.broadcast();
  final CodeFormatService _codeFormatService = const CodeFormatService();
  int _untitledCounter = 0;
  static int _idCounter = 0;
  Timer? _autoSaveTimer;
  Timer? _hotExitSaveTimer;
  Timer? _workspaceDiagnosticsTimer;
  Timer? _workspaceProblemWatcherRefreshTimer;
  String? _workspaceDiagnosticsRoot;
  bool _workspaceDiagnosticsRunning = false;
  bool _workspaceDiagnosticsProgressActive = false;
  int _workspaceDiagnosticsProgressProcessed = 0;
  int _workspaceDiagnosticsProgressTotal = 0;
  Set<String> _cachedDisabledLspLanguages = const {};
  DateTime _lastDisabledLspLoadAt = DateTime.fromMillisecondsSinceEpoch(0);
  late final bool _resolvedHotExitEnabled;
  late final String _resolvedHotExitSnapshotPath;

  static String _nextId() =>
      'tab_${DateTime.now().millisecondsSinceEpoch}_${++_idCounter}';

  void _initHotExitSettings() {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    _resolvedHotExitEnabled =
        hotExitEnabled && (allowHotExitInTests || !isTest);
    _resolvedHotExitSnapshotPath =
        hotExitSnapshotPath ?? _defaultHotExitSnapshotPath();
  }

  static String _defaultHotExitSnapshotPath() {
    final sep = Platform.pathSeparator;
    return '${Directory.systemTemp.path}${sep}bewy${sep}hot_exit_snapshot.json';
  }

  Stream<ExternalFileSyncEvent> get externalFileSyncEvents =>
      _externalSyncController.stream;

  Future<void> restoreHotExitSnapshot() async {
    if (!_resolvedHotExitEnabled) return;
    try {
      final file = File(_resolvedHotExitSnapshotPath);
      if (!await file.exists()) return;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final tabs = decoded['tabs'];
      final activeIndex = decoded['activeIndex'] as int?;
      if (tabs is! List) return;

      final restoredIds = <String>[];
      for (int i = 0; i < tabs.length; i++) {
        final item = tabs[i];
        if (item is! Map) continue;
        final data = Map<String, dynamic>.from(item);
        final fileName = data['fileName'] as String?;
        final content = data['content'] as String?;
        if (fileName == null || content == null) continue;
        await openTransferredTab({
          'fileName': fileName,
          'filePath': data['filePath'] as String?,
          'isBinary': false,
          'isPinned': data['isPinned'] as bool? ?? false,
          'content': content,
          'savedContent': data['savedContent'] as String? ?? '',
          'isModified': true,
        }, activate: false);
        final restored =
            state.tabGroup.tabs
                .where(
                  (t) =>
                      t.fileName == fileName &&
                      ((t.filePath ?? '') ==
                          ((data['filePath'] as String?) ?? '')),
                )
                .toList();
        if (restored.isNotEmpty) {
          restoredIds.add(restored.last.id);
        }
      }

      if (restoredIds.isEmpty) {
        await clearHotExitSnapshot();
        return;
      }

      final idx = (activeIndex ?? (restoredIds.length - 1)).clamp(
        0,
        restoredIds.length - 1,
      );
      activateTab(restoredIds[idx]);
      await clearHotExitSnapshot();
    } catch (_) {}
  }

  Future<void> clearHotExitSnapshot() async {
    if (!_resolvedHotExitEnabled) return;
    _hotExitSaveTimer?.cancel();
    try {
      final file = File(_resolvedHotExitSnapshotPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  void _scheduleHotExitSnapshot() {
    if (!_resolvedHotExitEnabled) return;
    _hotExitSaveTimer?.cancel();
    _hotExitSaveTimer = Timer(
      const Duration(milliseconds: 220),
      _persistHotExitSnapshot,
    );
  }

  Future<void> _persistHotExitSnapshot() async {
    if (!_resolvedHotExitEnabled) return;
    try {
      final unsaved = <Map<String, dynamic>>[];
      int activeIndex = -1;
      final activeId = state.tabGroup.activeTabId;
      for (final tab in state.tabGroup.tabs) {
        if (tab.isBinary || tab.isSettings) continue;
        if (!isModified(tab.id)) continue;
        final controller = _controllers[tab.id];
        if (controller == null) continue;
        final entry = <String, dynamic>{
          'fileName': tab.fileName,
          'filePath': tab.filePath,
          'isPinned': tab.isPinned,
          'content': controller.text,
          'savedContent': _savedContent[tab.id] ?? '',
        };
        if (tab.id == activeId) {
          activeIndex = unsaved.length;
        }
        unsaved.add(entry);
      }

      final file = File(_resolvedHotExitSnapshotPath);
      if (unsaved.isEmpty) {
        if (await file.exists()) await file.delete();
        return;
      }

      await file.parent.create(recursive: true);
      final payload = <String, dynamic>{
        'version': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'activeIndex': activeIndex >= 0 ? activeIndex : unsaved.length - 1,
        'tabs': unsaved,
      };
      await file.writeAsString(jsonEncode(payload));
    } catch (_) {}
  }

  CodeLineEditingController? getController(String tabId) => _controllers[tabId];

  CodeFindController? getFindController(String tabId) {
    if (_findControllers.containsKey(tabId)) return _findControllers[tabId];
    final editing = _controllers[tabId];
    if (editing == null) return null;
    _findControllers[tabId] = CodeFindController(editing);
    return _findControllers[tabId];
  }

  CodeFindController? getActiveFindController() {
    final activeId = state.tabGroup.activeTabId;
    if (activeId == null) return null;
    return getFindController(activeId);
  }

  CodeLineEditingController? getActiveController() {
    final activeId = state.tabGroup.activeTabId;
    if (activeId == null) return null;
    return _controllers[activeId];
  }

  List<EditorDiagnosticItem> collectDiagnostics() {
    final tabById = <String, EditorTabModel>{
      for (final tab in state.tabGroup.tabs) tab.id: tab,
    };
    final items = <EditorDiagnosticItem>[];
    // Collect paths covered by open tabs (their diagnostics are fresher).
    final openTabCoveredPaths = <String>{};
    for (final entry in _controllers.entries) {
      final tab = tabById[entry.key];
      if (tab == null) continue;
      final tabPath = tab.filePath;
      // Only mark path as covered if the controller has diagnostics.
      // Otherwise, let the workspace cache provide the last known state.
      if (tabPath != null && entry.value.diagnostics.isNotEmpty) {
        openTabCoveredPaths.add(tabPath);
      }
      for (final diagnostic in entry.value.diagnostics) {
        items.add(
          EditorDiagnosticItem(
            tabId: entry.key,
            fileName: tab.fileName,
            filePath: tab.filePath,
            diagnostic: diagnostic,
          ),
        );
      }
    }
    // For paths NOT covered by an open tab, fall back to workspace cache.
    for (final entry in _workspaceDiagnosticsByPath.entries) {
      final filePath = entry.key;
      if (openTabCoveredPaths.contains(filePath)) continue;
      final name = filePath.split(RegExp(r'[\\/]')).last;
      for (final diagnostic in entry.value) {
        items.add(
          EditorDiagnosticItem(
            tabId: '',
            fileName: name,
            filePath: filePath,
            diagnostic: diagnostic,
          ),
        );
      }
    }
    items.sort((a, b) {
      final bySeverity = a.diagnostic.severity.compareTo(b.diagnostic.severity);
      if (bySeverity != 0) return bySeverity;
      final byFile = a.fileName.compareTo(b.fileName);
      if (byFile != 0) return byFile;
      return a.diagnostic.startLine.compareTo(b.diagnostic.startLine);
    });
    return items;
  }

  Future<bool> jumpToNextDiagnostic({
    required String scopeKey,
    int? severity,
  }) async {
    final diagnostics = collectDiagnostics()
        .where((item) {
          if (severity == null) return true;
          return item.diagnostic.severity == severity;
        })
        .toList(growable: false);
    if (diagnostics.isEmpty) return false;

    final current = _diagnosticJumpIndexByScope[scopeKey] ?? -1;
    final nextIndex = (current + 1) % diagnostics.length;
    _diagnosticJumpIndexByScope[scopeKey] = nextIndex;
    final item = diagnostics[nextIndex];
    final diagnostic = item.diagnostic;

    if (item.tabId.isNotEmpty) {
      activateTab(item.tabId);
      final controller = getController(item.tabId);
      if (controller == null) return false;
      controller.selection = CodeLineSelection.collapsed(
        index: diagnostic.startLine,
        offset: diagnostic.startCharacter,
      );
      controller.makeCursorCenterIfInvisible();
      return true;
    }
    if (item.filePath == null) return false;
    final name = item.filePath!.split(RegExp(r'[\\/]')).last;
    await openTab(name, item.filePath!);
    final activeId = state.tabGroup.activeTabId;
    if (activeId == null) return false;
    final controller = getController(activeId);
    if (controller == null) return false;
    controller.selection = CodeLineSelection.collapsed(
      index: diagnostic.startLine,
      offset: diagnostic.startCharacter,
    );
    controller.makeCursorCenterIfInvisible();
    return true;
  }

  Future<CodeLineEditingController> _createControllerForFile({
    required String text,
    required String filePath,
    String? workspacePath,
    bool bindOpenedFile = true,
  }) async {
    final useLsp = await _shouldUseLanguageServerDiagnostics();
    final disabled = await _disabledLspLanguages();
    final lspLanguageEnabled = <String, bool>{
      for (final id in disabled) id: false,
    };
    return CodeLineEditingController.fromTextForFile(
      text,
      filePath: filePath,
      workspacePath: workspacePath,
      bindOpenedFile: bindOpenedFile,
      enableLsp: useLsp,
      enableSemanticHighlighting: useLsp,
      enableDiagnostics: useLsp,
      lspLanguageEnabled: lspLanguageEnabled,
    );
  }

  EditorDiagnosticsSummary collectDiagnosticsSummary() {
    int errorCount = 0;
    int warningCount = 0;
    int infoCount = 0;
    final tabById = <String, EditorTabModel>{
      for (final tab in state.tabGroup.tabs) tab.id: tab,
    };
    // Collect paths covered by open tabs (their diagnostics are fresher).
    final openTabCoveredPaths = <String>{};
    for (final entry in _controllers.entries) {
      final tabPath = tabById[entry.key]?.filePath;
      // Only mark path as covered if the controller has diagnostics.
      if (tabPath != null && entry.value.diagnostics.isNotEmpty) {
        openTabCoveredPaths.add(tabPath);
      }
      for (final diagnostic in entry.value.diagnostics) {
        switch (diagnostic.severity) {
          case 1:
            errorCount++;
            break;
          case 2:
            warningCount++;
            break;
          case 3:
            infoCount++;
            break;
          default:
            infoCount++;
        }
      }
    }
    // For paths NOT covered by an open tab, fall back to workspace cache.
    for (final entry in _workspaceDiagnosticsByPath.entries) {
      if (openTabCoveredPaths.contains(entry.key)) continue;
      for (final diagnostic in entry.value) {
        switch (diagnostic.severity) {
          case 1:
            errorCount++;
            break;
          case 2:
            warningCount++;
            break;
          case 3:
            infoCount++;
            break;
          default:
            infoCount++;
        }
      }
    }
    return EditorDiagnosticsSummary(
      errorCount: errorCount,
      warningCount: warningCount,
      infoCount: infoCount,
    );
  }

  List<EditorLspConnectionItem> collectLspConnections() {
    if (_currentDiagnosticsEngineSync() != DiagnosticsEngine.languageServer) {
      return const [];
    }
    final tabById = <String, EditorTabModel>{
      for (final tab in state.tabGroup.tabs) tab.id: tab,
    };
    final items = <EditorLspConnectionItem>[];
    for (final entry in _controllers.entries) {
      final tab = tabById[entry.key];
      final controller = entry.value;
      if (!controller.hasLsp) continue;
      items.add(
        EditorLspConnectionItem(
          tabId: entry.key,
          fileName:
              tab?.fileName ?? '[${controller.lspLanguageId ?? 'unknown'}]',
          filePath: tab?.filePath,
          languageId: controller.lspLanguageId ?? 'unknown',
          workspacePath: controller.lspWorkspacePath,
          serverExecutable:
              controller.lspServerExecutable ??
              _fallbackServerLabelForLanguage(
                controller.lspLanguageId ?? 'unknown',
              ),
        ),
      );
    }
    for (final entry in _lspWarmupControllers.entries) {
      final controller = entry.value;
      if (!controller.hasLsp) continue;
      items.add(
        EditorLspConnectionItem(
          tabId: entry.key,
          fileName: '[${controller.lspLanguageId ?? 'unknown'}]',
          filePath: null,
          languageId: controller.lspLanguageId ?? 'unknown',
          workspacePath: controller.lspWorkspacePath,
          serverExecutable:
              controller.lspServerExecutable ??
              _fallbackServerLabelForLanguage(
                controller.lspLanguageId ?? 'unknown',
              ),
        ),
      );
    }
    for (final runtime in _transientLspRuntimeByLanguage.values) {
      if (runtime.activeCount <= 0) continue;
      items.add(
        EditorLspConnectionItem(
          tabId: 'transient_${runtime.languageId}',
          fileName: '[${runtime.languageId}]',
          filePath: null,
          languageId: runtime.languageId,
          workspacePath: runtime.workspacePath,
          serverExecutable:
              runtime.serverExecutable ??
              _fallbackServerLabelForLanguage(runtime.languageId),
        ),
      );
    }
    if (_workspaceDiagnosticsRunning) {
      for (final languageId in _workspacePlannedLspLanguages) {
        items.add(
          EditorLspConnectionItem(
            tabId: 'planned_$languageId',
            fileName: '[$languageId]',
            filePath: null,
            languageId: languageId,
            workspacePath: _workspaceDiagnosticsRoot,
            serverExecutable: _fallbackServerLabelForLanguage(languageId),
          ),
        );
      }
    }
    // Include primary (kept-alive) LSP servers
    for (final entry in _primaryLspControllers.entries) {
      final controller = entry.value;
      if (!controller.hasLsp) continue;
      items.add(
        EditorLspConnectionItem(
          tabId: 'primary_${entry.key}',
          fileName: '[${entry.key}]',
          filePath: null,
          languageId: entry.key,
          workspacePath: controller.lspWorkspacePath ?? _workspaceDiagnosticsRoot,
          serverExecutable:
              controller.lspServerExecutable ??
              _fallbackServerLabelForLanguage(entry.key),
        ),
      );
    }
    final dedup = <String>{};
    items.retainWhere((item) {
      final key = item.languageId;
      if (dedup.contains(key)) return false;
      dedup.add(key);
      return true;
    });
    items.sort((a, b) => a.languageId.compareTo(b.languageId));
    return items;
  }

  FileDiagnosticsSummary diagnosticsForPath(
    String path, {
    required bool recursive,
  }) {
    int errorCount = 0;
    int warningCount = 0;
    int infoCount = 0;
    void countFromController(CodeLineEditingController controller) {
      for (final diagnostic in controller.diagnostics) {
        switch (diagnostic.severity) {
          case 1:
            errorCount++;
            break;
          case 2:
            warningCount++;
            break;
          case 3:
            infoCount++;
            break;
          default:
            infoCount++;
        }
      }
    }

    void countFromList(List<CodeLspDiagnostic> diagnostics) {
      for (final diagnostic in diagnostics) {
        switch (diagnostic.severity) {
          case 1:
            errorCount++;
            break;
          case 2:
            warningCount++;
            break;
          case 3:
            infoCount++;
            break;
          default:
            infoCount++;
        }
      }
    }

    // Collect paths covered by open tabs (their diagnostics are fresher).
    final openTabPaths = <String>{};
    for (final entry in _controllers.entries) {
      final tab =
          state.tabGroup.tabs.where((t) => t.id == entry.key).firstOrNull;
      final tabPath = tab?.filePath;
      if (tabPath == null) continue;
      if (recursive) {
        if (!_isPathUnder(path, tabPath)) continue;
      } else if (tabPath != path) {
        continue;
      }
      // Only use controller diagnostics if non-empty; otherwise let the
      // workspace cache provide the last known diagnostics so that
      // switching tabs doesn't make indicators vanish.
      if (entry.value.diagnostics.isNotEmpty) {
        openTabPaths.add(tabPath);
        countFromController(entry.value);
      }
    }

    // For paths NOT covered by an open tab, fall back to workspace cache.
    for (final entry in _workspaceDiagnosticsByPath.entries) {
      final filePath = entry.key;
      if (openTabPaths.contains(filePath)) continue;
      if (recursive) {
        if (!_isPathUnder(path, filePath)) continue;
      } else if (filePath != path) {
        continue;
      }
      countFromList(entry.value);
    }

    return FileDiagnosticsSummary(
      errorCount: errorCount,
      warningCount: warningCount,
      infoCount: infoCount,
    );
  }

  List<CodeLspDiagnostic> diagnosticsForFile(String filePath) {
    final result = <CodeLspDiagnostic>[];
    final useLsp =
        _currentDiagnosticsEngineSync() == DiagnosticsEngine.languageServer;
    final workspace = _workspaceDiagnosticsByPath[filePath];
    if (workspace != null) {
      result.addAll(workspace);
    }
    for (final tab in state.tabGroup.tabs) {
      if (tab.filePath != filePath) continue;
      final controller = _controllers[tab.id];
      if (controller == null) continue;
      final controllerDiagnostics = controller.diagnostics;
      if (useLsp) {
        result
          ..clear()
          ..addAll(controllerDiagnostics);
      } else if (controllerDiagnostics.isNotEmpty) {
        // In simple mode, keep workspace diagnostics as baseline; use live
        // focused-file diagnostics only when the editor has non-empty results.
        result
          ..clear()
          ..addAll(controllerDiagnostics);
      }
      break;
    }
    result.sort((a, b) {
      final bySeverity = a.severity.compareTo(b.severity);
      if (bySeverity != 0) return bySeverity;
      final byLine = a.startLine.compareTo(b.startLine);
      if (byLine != 0) return byLine;
      return a.startCharacter.compareTo(b.startCharacter);
    });
    return result;
  }

  bool _isPathUnder(String root, String filePath) {
    final normalizedRoot = root.toLowerCase();
    final normalizedFile = filePath.toLowerCase();
    final sep = Platform.pathSeparator;
    return normalizedFile == normalizedRoot ||
        normalizedFile.startsWith('$normalizedRoot$sep');
  }

  String _workspacePathForFile(String filePath) {
    final root = _workspaceDiagnosticsRoot;
    if (root != null && root.isNotEmpty && _isPathUnder(root, filePath)) {
      return root;
    }
    var dir = File(filePath).parent;
    final fallback = dir.path;
    while (true) {
      final pubspec = '${dir.path}${Platform.pathSeparator}pubspec.yaml';
      if (File(pubspec).existsSync()) return dir.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return fallback;
  }

  static const List<(String lang, String relPath)> _lspWarmupSeeds = [
    ('dart', '.bewy_lsp_warmup/main.dart'),
    ('javascript', '.bewy_lsp_warmup/main.js'),
    ('typescript', '.bewy_lsp_warmup/main.ts'),
    ('python', '.bewy_lsp_warmup/main.py'),
    ('json', '.bewy_lsp_warmup/main.json'),
    ('yaml', '.bewy_lsp_warmup/main.yaml'),
    ('markdown', '.bewy_lsp_warmup/main.md'),
    ('c', '.bewy_lsp_warmup/main.c'),
    ('cpp', '.bewy_lsp_warmup/main.cpp'),
  ];

  Future<void> prewarmLspServers({required String workspacePath}) async {
    for (final entry in _lspWarmupControllers.entries.toList()) {
      entry.value.dispose();
    }
    _lspWarmupControllers.clear();
    for (final seed in _lspWarmupSeeds) {
      final tabId = 'lsp_warmup_${seed.$1}';
      final filePath = '$workspacePath${Platform.pathSeparator}${seed.$2}';
      try {
        final controller = await _createControllerForFile(
          text: '',
          filePath: filePath,
          workspacePath: workspacePath,
          bindOpenedFile: false,
        );
        if (controller.hasLsp) {
          _lspWarmupControllers[tabId] = controller;
          AppLogService.instance.info(
            'lsp',
            'prewarmConnected lang=${controller.lspLanguageId} server=${controller.lspServerExecutable ?? 'unknown'} workspace=$workspacePath',
          );
        } else {
          controller.dispose();
        }
      } catch (_) {}
    }
    if (mounted) {
      state = state.copyWith();
    }
  }

  /// Pre-start and keep alive LSP servers for the given primary languages.
  Future<void> _startPrimaryLspServers(
    String workspacePath,
    Set<String> languages,
  ) async {
    if (languages.isEmpty) return;
    final useLsp = await _shouldUseLanguageServerDiagnostics();
    if (!useLsp) return;
    final disabled = await _disabledLspLanguages();

    for (final lang in languages) {
      if (disabled.contains(lang)) continue;
      if (_primaryLspControllers.containsKey(lang)) continue;
      final key = 'primary_lsp_$lang';
      // Use a synthetic file path that matches the language extension
      final ext = _extensionForLanguage(lang);
      final filePath =
          '$workspacePath${Platform.pathSeparator}.bewy_lsp_warmup${Platform.pathSeparator}primary.$ext';
      try {
        final controller = await _createControllerForFile(
          text: '',
          filePath: filePath,
          workspacePath: workspacePath,
          bindOpenedFile: false,
        );
        if (controller.hasLsp) {
          _primaryLspControllers[lang] = controller;
          AppLogService.instance.info(
            'lsp',
            'primaryLspStarted lang=$lang server=${controller.lspServerExecutable ?? "unknown"} workspace=$workspacePath',
          );
        } else {
          controller.dispose();
        }
      } catch (e) {
        AppLogService.instance.info(
          'lsp',
          'primaryLspFailed lang=$lang error=$e',
        );
      }
    }
    if (mounted) {
      state = state.copyWith();
    }
  }

  /// Dispose all primary LSP controllers (called on workspace switch or
  /// diagnostics engine change).
  void _disposePrimaryLspServers() {
    for (final entry in _primaryLspControllers.entries) {
      AppLogService.instance.info(
        'lsp',
        'primaryLspDisposed lang=${entry.key}',
      );
      entry.value.dispose();
    }
    _primaryLspControllers.clear();
    _primaryLspLanguages.clear();
  }

  static String _extensionForLanguage(String languageId) {
    switch (languageId) {
      case 'dart': return 'dart';
      case 'javascript': return 'js';
      case 'typescript': return 'ts';
      case 'python': return 'py';
      case 'rust': return 'rs';
      case 'go': return 'go';
      case 'java': return 'java';
      case 'kotlin': return 'kt';
      case 'c': return 'c';
      case 'cpp': return 'cpp';
      case 'swift': return 'swift';
      case 'ruby': return 'rb';
      case 'php': return 'php';
      case 'lua': return 'lua';
      default: return 'txt';
    }
  }

  /// Check if any open tabs still use the given language.
  bool _hasOpenTabsForLanguage(String languageId) {
    for (final tab in state.tabGroup.tabs) {
      if (tab.filePath == null) continue;
      final lang = _languageIdForPathQuick(tab.filePath!);
      if (lang == languageId) return true;
    }
    return false;
  }

  /// Release non-primary LSP server for a language when no more files of
  /// that language are open.
  void _releaseNonPrimaryLspIfUnused(String? filePath) {
    if (filePath == null) return;
    final lang = _languageIdForPathQuick(filePath);
    if (lang == null) return;
    // Don't release if this is a primary language
    if (_primaryLspLanguages.contains(lang)) return;
    // Don't release if there are still open tabs for this language
    if (_hasOpenTabsForLanguage(lang)) return;
    // Release the shared LSP pool entry for this language
    final workspacePath = _workspacePathForFile(filePath);
    CodeLineEditingController.disposeSharedLspForLanguage(lang, workspacePath);
    AppLogService.instance.info(
      'lsp',
      'nonPrimaryLspReleased lang=$lang workspace=$workspacePath',
    );
  }

  Future<void> startWorkspaceDiagnostics({
    required String workspacePath,
  }) async {
    // Dispose old primary LSPs when switching workspace
    if (_workspaceDiagnosticsRoot != null &&
        _workspaceDiagnosticsRoot != workspacePath) {
      _disposePrimaryLspServers();
      CodeLineEditingController.disposeAllSharedLsp();
    }
    _workspaceDiagnosticsRoot = workspacePath;
    _workspaceDiagnosticsTimer?.cancel();
    _workspaceDiagnosticsTimer = null;

    // Detect primary languages and pre-start their LSP servers
    final useLsp = await _shouldUseLanguageServerDiagnostics();
    if (useLsp) {
      await _loadExcludeRules();
      final languages = _detectWorkspaceLanguages(workspacePath);
      _primaryLspLanguages
        ..clear()
        ..addAll(languages);
      await _startPrimaryLspServers(workspacePath, languages);
    }

    await _runWorkspaceDiagnosticsPass();
  }

  Future<void> restartWorkspaceDiagnosticsForCurrentRoot() async {
    final root = _workspaceDiagnosticsRoot;
    if (root == null || root.isEmpty) return;
    await startWorkspaceDiagnostics(workspacePath: root);
  }

  Future<void> refreshDiagnosticsEngineForOpenTabs() async {
    _setWorkspaceDiagnosticsProgress(isActive: false, processed: 0, total: 0);
    final fileTabs = state.tabGroup.tabs
        .where((t) => !t.isBinary && !t.isSettings && t.filePath != null)
        .toList(growable: false);
    for (final tab in fileTabs) {
      final tabId = tab.id;
      final filePath = tab.filePath!;
      final old = _controllers[tabId];
      if (old == null) continue;
      final text = old.text;
      final selection = old.selection;
      _detachDiagnosticsListener(tabId);
      old.dispose();
      final next = await _createControllerForFile(
        text: text,
        filePath: filePath,
        workspacePath: _workspacePathForFile(filePath),
        bindOpenedFile: true,
      );
      next.text = text;
      next.selection = selection;
      _controllers[tabId] = next;
      _attachDiagnosticsListener(tabId, filePath);
      _refreshDiagnosticsForOpenedFile(tabId, filePath);
      _syncInlineDiagnosticDecorations(filePath);
    }
    _transientLspRuntimeByLanguage.clear();
    _workspacePlannedLspLanguages.clear();
    // Dispose primary LSPs — they'll be re-created if LSP mode is still active
    // when workspace diagnostics restart.
    _disposePrimaryLspServers();
    if (mounted) {
      state = state.copyWith();
    }
  }

  WorkspaceDiagnosticsProgress get workspaceDiagnosticsProgress =>
      WorkspaceDiagnosticsProgress(
        isActive: _workspaceDiagnosticsProgressActive,
        processed: _workspaceDiagnosticsProgressProcessed,
        total: _workspaceDiagnosticsProgressTotal,
      );

  bool get workspaceDiagnosticsRunning => _workspaceDiagnosticsRunning;

  Future<Set<String>> _disabledLspLanguages() async {
    final now = DateTime.now();
    if (now.difference(_lastDisabledLspLoadAt).inMilliseconds < 1200) {
      return _cachedDisabledLspLanguages;
    }
    final cfg = await ConfigService.load();
    final raw = cfg['lsp.disabledLanguages'];
    final parsed =
        raw is List
            ? raw.whereType<String>().map((e) => e.trim()).toSet()
            : <String>{};
    _cachedDisabledLspLanguages = parsed;
    _lastDisabledLspLoadAt = now;
    return parsed;
  }

  void stopWorkspaceDiagnostics() {
    _workspaceDiagnosticsTimer?.cancel();
    _workspaceDiagnosticsTimer = null;
    _workspaceProblemWatcherRefreshTimer?.cancel();
    _workspaceProblemWatcherRefreshTimer = null;
    for (final timer in _editedFileDiagnosticsDebounceTimers.values) {
      timer.cancel();
    }
    _editedFileDiagnosticsDebounceTimers.clear();
    for (final timer in _workspaceProblemDebounceTimers.values) {
      timer.cancel();
    }
    _workspaceProblemDebounceTimers.clear();
    for (final watcher in _workspaceProblemWatchers.values) {
      watcher.cancel();
    }
    _workspaceProblemWatchers.clear();
    for (final entry in _workspaceDiagnosticListeners.entries) {
      final controller = _workspaceDiagnosticControllers[entry.key];
      if (controller != null) {
        controller.diagnosticsNotifier.removeListener(entry.value);
      }
    }
    _workspaceDiagnosticListeners.clear();
    for (final controller in _workspaceDiagnosticControllers.values) {
      controller.dispose();
    }
    _workspaceDiagnosticControllers.clear();
    _workspaceDiagnosticsByPath.clear();
    for (final controller in _controllers.values) {
      controller.clearSyntheticDiagnosticsDecorations();
    }
    _transientLspRuntimeByLanguage.clear();
    _workspacePlannedLspLanguages.clear();
    _workspaceDiagnosticsRoot = null;
    if (mounted) {
      state = state.copyWith();
    }
  }

  Future<void> _runWorkspaceDiagnosticsPass() async {
    if (_workspaceDiagnosticsRunning) return;
    final root = _workspaceDiagnosticsRoot;
    if (root == null || root.isEmpty) return;
    if (!Directory(root).existsSync()) return;
    _workspaceDiagnosticsRunning = true;
    try {
      await _loadExcludeRules();
      final disabledLanguages = await _disabledLspLanguages();
      final candidates = _scanWorkspaceCandidates(root);
      _setWorkspaceDiagnosticsProgress(
        isActive: true,
        processed: 0,
        total: candidates.length,
      );
      AppLogService.instance.info(
        'lsp',
        'workspaceScanStart root=$root candidates=${candidates.length}',
      );
      final nextDiagnostics = <String, List<CodeLspDiagnostic>>{};
      final useLsp = await _shouldUseLanguageServerDiagnostics();
      final groups = <String, List<String>>{};
      var processed = 0;

      for (final filePath in candidates) {
        final languageId = _languageIdForPathQuick(filePath);
        if (languageId == null) continue;
        if (disabledLanguages.contains(languageId)) continue;
        groups.putIfAbsent(languageId, () => []).add(filePath);
      }
      _workspacePlannedLspLanguages.clear();
      if (useLsp) {
        // Only plan LSP scan for primary languages (detected from workspace)
        for (final lang in groups.keys) {
          if (_primaryLspLanguages.contains(lang)) {
            _workspacePlannedLspLanguages.add(lang);
          }
        }
      }
      if (mounted) {
        state = state.copyWith();
      }

      if (!useLsp) {
        for (int i = 0; i < candidates.length; i++) {
          final filePath = candidates[i];
          processed++;
          if (processed % 8 == 0 || processed == candidates.length) {
            _setWorkspaceDiagnosticsProgress(
              isActive: true,
              processed: processed,
              total: candidates.length,
            );
          }
          try {
            nextDiagnostics[filePath] = await _scanSingleFileDiagnostics(
              filePath: filePath,
              workspacePath: root,
              warmupScan: i == 0,
            );
          } catch (_) {
            nextDiagnostics[filePath] = const [];
          }
          if (processed % 14 == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 1));
          }
        }
        _workspaceDiagnosticsByPath
          ..clear()
          ..addAll(nextDiagnostics);
        for (final path in nextDiagnostics.keys) {
          _syncInlineDiagnosticDecorations(
            path,
            diagnostics: nextDiagnostics[path],
          );
        }
        _scheduleWorkspaceProblemWatcherRefresh();
        if (mounted) {
          state = state.copyWith();
        }
        AppLogService.instance.info(
          'diag',
          'workspaceSimpleScanDone root=$root files=${_workspaceDiagnosticsByPath.length}',
        );
        return;
      }

      for (final entry in groups.entries) {
        final languageId = entry.key;
        final files = entry.value;
        if (files.isEmpty) continue;
        // Only start LSP servers for primary languages detected from workspace
        if (!_primaryLspLanguages.contains(languageId)) {
          // Skip non-primary languages — count them as processed
          processed += files.length;
          _setWorkspaceDiagnosticsProgress(
            isActive: true,
            processed: processed,
            total: candidates.length,
          );
          continue;
        }
        CodeLineEditingController? controller;
        try {
          final firstPath = files.first;
          final firstContent = await _readTextSafely(firstPath);
          controller = await _createControllerForFile(
            text: firstContent,
            filePath: firstPath,
            workspacePath: root,
            bindOpenedFile: true,
          );
          if (!controller.hasLsp) {
            controller.dispose();
            continue;
          }
          _markTransientLspStart(controller);

          for (int i = 0; i < files.length; i++) {
            final filePath = files[i];
            processed++;
            if (processed % 4 == 0 || processed == candidates.length) {
              _setWorkspaceDiagnosticsProgress(
                isActive: true,
                processed: processed,
                total: candidates.length,
              );
            }
            if (processed % 8 == 0) {
              await Future<void>.delayed(const Duration(milliseconds: 1));
            }
            try {
              final content = await _readTextSafely(filePath);
              controller.delegate.openedFile = filePath;
              controller.text = content;
              final diagnostics = await _awaitDiagnosticsForCurrentFile(
                controller: controller,
                languageId: languageId,
                warmupScan: i == 0,
              );
              nextDiagnostics[filePath] = diagnostics;
            } catch (_) {
              nextDiagnostics[filePath] = const [];
            }
            if (_heavyLspLanguages.contains(languageId)) {
              await Future<void>.delayed(const Duration(milliseconds: 8));
            }
          }
        } catch (_) {
          continue;
        } finally {
          if (controller != null) {
            _markTransientLspEnd(controller);
            controller.dispose();
          }
        }
      }

      _workspaceDiagnosticsByPath
        ..clear()
        ..addAll(nextDiagnostics);
      for (final path in nextDiagnostics.keys) {
        _syncInlineDiagnosticDecorations(
          path,
          diagnostics: nextDiagnostics[path],
        );
      }
      _scheduleWorkspaceProblemWatcherRefresh();
      if (mounted) {
        state = state.copyWith();
      }
      AppLogService.instance.info(
        'lsp',
        'workspaceScanDone root=$root files=${_workspaceDiagnosticsByPath.length}',
      );
    } finally {
      _workspaceDiagnosticsRunning = false;
      _workspacePlannedLspLanguages.clear();
      _setWorkspaceDiagnosticsProgress(
        isActive: false,
        processed: _workspaceDiagnosticsProgressTotal,
        total: _workspaceDiagnosticsProgressTotal,
      );
    }
  }

  static const Set<String> _workspaceScanIgnoreDirs = {
    '.git',
    '.svn',
    '.hg',
    '.idea',
    '.vscode',
    '.vs',
    'build',
    'out',
    'dist',
    'target',
    '.dart_tool',
    '.pub-cache',
    '.pub',
    'node_modules',
    'bower_components',
    'jspm_packages',
    '__pycache__',
    '.pytest_cache',
    '.mypy_cache',
    '.tox',
    '.venv',
    'venv',
    'env',
    '.gradle',
    '.m2',
    'vendor',
    'Pods',
    '.cache',
    '.parcel-cache',
    '.turbo',
    '.next',
    '.nuxt',
    'coverage',
    '.nyc_output',
    '.terraform',
    '.serverless',
    'bin',
    'obj',
    'tmp',
    'temp',
    'logs',
  };

  static const List<String> _defaultExcludePatterns = [
    '*.min.js',
    '*.min.css',
    '*.map',
    '*.lock',
    'package-lock.json',
    'yarn.lock',
    'pnpm-lock.yaml',
    'Podfile.lock',
    '*.g.dart',
    '*.freezed.dart',
    '*.mocks.dart',
    '*.generated.*',
    '*.gen.*',
    '*.pb.dart',
    '*.pb.go',
    '*.pb.cc',
    '*.pb.h',
    '*.o',
    '*.a',
    '*.so',
    '*.dll',
    '*.dylib',
    '*.exe',
    '*.pyc',
    '*.pyo',
    '*.class',
    '*.jar',
  ];

  static const Set<String> _heavyLspLanguages = {'c', 'cpp'};

  static const Set<String> _workspaceScanExts = {
    '.dart',
    '.js',
    '.jsx',
    '.ts',
    '.tsx',
    '.py',
    '.json',
    '.yaml',
    '.yml',
    '.md',
    '.c',
    '.h',
    '.hpp',
    '.hh',
    '.hxx',
    '.cpp',
    '.cc',
    '.cxx',
    '.swift',
    '.plist',
    '.entitlements',
    '.kt',
    '.kts',
    '.java',
    '.go',
    '.rs',
    '.rb',
    '.xml',
    '.html',
    '.css',
    '.scss',
    '.toml',
    '.ini',
    '.cfg',
    '.php',
    '.lua',
    '.sql',
    '.ps1',
    '.sh',
  };

  String? _languageIdForPathQuick(String filePath) {
    final lower = filePath.toLowerCase();
    final name = lower.split(RegExp(r'[\\/]')).last;
    if (name == 'dockerfile') return 'dockerfile';
    if (name == 'makefile') return 'makefile';
    if (lower.endsWith('.dart')) return 'dart';
    if (lower.endsWith('.js') || lower.endsWith('.jsx')) return 'javascript';
    if (lower.endsWith('.ts') || lower.endsWith('.tsx')) return 'typescript';
    if (lower.endsWith('.py')) return 'python';
    if (lower.endsWith('.json')) return 'json';
    if (lower.endsWith('.yaml') || lower.endsWith('.yml')) return 'yaml';
    if (lower.endsWith('.md')) return 'markdown';
    if (lower.endsWith('.swift')) return 'swift';
    if (lower.endsWith('.kt') || lower.endsWith('.kts')) return 'kotlin';
    if (lower.endsWith('.java')) return 'java';
    if (lower.endsWith('.go')) return 'go';
    if (lower.endsWith('.rs')) return 'rust';
    if (lower.endsWith('.rb')) return 'ruby';
    if (lower.endsWith('.xml') ||
        lower.endsWith('.html') ||
        lower.endsWith('.htm')) {
      return 'xml';
    }
    if (lower.endsWith('.css')) return 'css';
    if (lower.endsWith('.scss')) return 'scss';
    if (lower.endsWith('.toml') ||
        lower.endsWith('.ini') ||
        lower.endsWith('.cfg')) {
      return 'ini';
    }
    if (lower.endsWith('.php')) return 'php';
    if (lower.endsWith('.lua')) return 'lua';
    if (lower.endsWith('.sql')) return 'sql';
    if (lower.endsWith('.ps1')) return 'powershell';
    if (lower.endsWith('.sh') || lower.endsWith('.bash')) return 'bash';
    if (lower.endsWith('.c')) return 'c';
    if (lower.endsWith('.h') ||
        lower.endsWith('.hpp') ||
        lower.endsWith('.hh') ||
        lower.endsWith('.hxx') ||
        lower.endsWith('.cpp') ||
        lower.endsWith('.cc') ||
        lower.endsWith('.cxx')) {
      return 'cpp';
    }
    return null;
  }

  Set<String> _configExcludeDirs = {};
  List<String> _configExcludePatterns = [];

  Future<void> _loadExcludeRules() async {
    final cfg = await ConfigService.load();
    final dirs = cfg['diagnostics.excludeDirs'];
    final patterns = cfg['diagnostics.excludePatterns'];
    _configExcludeDirs =
        dirs is List ? dirs.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toSet() : {};
    _configExcludePatterns =
        patterns is List ? patterns.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : [];
  }

  bool _matchesExcludePattern(String fileName) {
    final lower = fileName.toLowerCase();
    for (final pattern in _defaultExcludePatterns) {
      if (_globMatch(lower, pattern.toLowerCase())) return true;
    }
    for (final pattern in _configExcludePatterns) {
      if (_globMatch(lower, pattern.toLowerCase())) return true;
    }
    return false;
  }

  static bool _globMatch(String input, String pattern) {
    // Simple glob matching supporting * and exact match.
    if (pattern == input) return true;
    if (!pattern.contains('*')) return input == pattern;
    // Convert glob pattern to regex.
    final regexStr = '^${pattern.replaceAll('.', r'\.').replaceAll('*', '.*')}\$';
    try {
      return RegExp(regexStr).hasMatch(input);
    } catch (_) {
      return false;
    }
  }

  /// LSP-capable language IDs (excludes config/markup languages that don't
  /// benefit from a persistent LSP server).
  static const Set<String> _lspCapableLanguages = {
    'dart', 'javascript', 'typescript', 'python', 'rust', 'go',
    'java', 'kotlin', 'c', 'cpp', 'swift', 'ruby', 'php', 'lua',
  };

  /// Detect the primary programming language(s) for a workspace folder.
  ///
  /// Phase 1: Check marker files in the top 2 directory levels.
  /// Phase 2: If ambiguous or no markers, scan file counts and return the
  /// top 3 most common LSP-capable languages.
  Set<String> _detectWorkspaceLanguages(String root) {
    final detected = <String>{};

    // Phase 1 — marker file detection (top 2 levels)
    const markerMap = <String, String>{
      'pubspec.yaml': 'dart',
      'pubspec.lock': 'dart',
      'Cargo.toml': 'rust',
      'go.mod': 'go',
      'requirements.txt': 'python',
      'setup.py': 'python',
      'pyproject.toml': 'python',
      'Pipfile': 'python',
      'Gemfile': 'ruby',
      'composer.json': 'php',
      'CMakeLists.txt': 'cpp',
      'pom.xml': 'java',
    };

    void checkDir(String dirPath) {
      try {
        for (final entity in Directory(dirPath).listSync(followLinks: false)) {
          if (entity is! File) continue;
          final name = entity.path.split(RegExp(r'[\\/]')).last;
          if (markerMap.containsKey(name)) {
            detected.add(markerMap[name]!);
          }
          // package.json → check for .ts files to decide js vs ts
          if (name == 'package.json') {
            detected.add('javascript');
          }
          // Gradle files → java/kotlin
          if (name == 'build.gradle' || name == 'build.gradle.kts') {
            detected.add('java');
          }
        }
      } catch (_) {}
    }

    // Check root directory
    checkDir(root);

    // Check second-level directories
    try {
      for (final entity in Directory(root).listSync(followLinks: false)) {
        if (entity is Directory) {
          final name = entity.path.split(RegExp(r'[\\/]')).last;
          if (!name.startsWith('.') &&
              !_workspaceScanIgnoreDirs.contains(name)) {
            checkDir(entity.path);
          }
        }
      }
    } catch (_) {}

    // If package.json detected, check if there are .ts/.tsx files → prefer typescript
    if (detected.contains('javascript')) {
      try {
        final hasTs = Directory(root)
            .listSync(recursive: true, followLinks: false)
            .take(2000)
            .any((e) =>
                e is File &&
                (e.path.endsWith('.ts') || e.path.endsWith('.tsx')) &&
                !e.path.contains('node_modules'));
        if (hasTs) {
          detected.remove('javascript');
          detected.add('typescript');
        }
      } catch (_) {}
    }

    // Filter to only LSP-capable languages
    detected.retainAll(_lspCapableLanguages);

    // If we got a clear set of markers (1-3), return them directly
    if (detected.isNotEmpty && detected.length <= 3) {
      AppLogService.instance.info(
        'lsp',
        'workspaceLanguageDetection root=$root markers=${detected.join(",")}',
      );
      return detected;
    }

    // Phase 2 — file count scan (fallback when ambiguous or no markers)
    final candidates = _scanWorkspaceCandidates(root);
    final counts = <String, int>{};
    for (final filePath in candidates) {
      final lang = _languageIdForPathQuick(filePath);
      if (lang != null && _lspCapableLanguages.contains(lang)) {
        counts[lang] = (counts[lang] ?? 0) + 1;
      }
    }

    if (counts.isEmpty) {
      // Fall back to marker results, capped at 3
      final capped = detected.take(3).toSet();
      AppLogService.instance.info(
        'lsp',
        'workspaceLanguageDetection root=$root result=${capped.join(",")}',
      );
      return capped;
    }

    // Sort by count descending, take top 3 only
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(3).map((e) => e.key).toSet();

    AppLogService.instance.info(
      'lsp',
      'workspaceLanguageDetection root=$root fileCount=${top.join(",")}',
    );
    return top;
  }

  List<String> _scanWorkspaceCandidates(String root) {
    final allIgnoreDirs = {..._workspaceScanIgnoreDirs, ..._configExcludeDirs};
    final results = <String>[];
    final stack = <Directory>[Directory(root)];
    while (stack.isNotEmpty) {
      final dir = stack.removeLast();
      List<FileSystemEntity> entities;
      try {
        entities = dir.listSync(followLinks: false);
      } catch (_) {
        continue;
      }
      for (final entity in entities) {
        if (entity is Directory) {
          final name = entity.path.split(RegExp(r'[\\/]')).last;
          if (allIgnoreDirs.contains(name)) continue;
          stack.add(entity);
          continue;
        }
        if (entity is! File) continue;
        try {
          // Skip large files in startup scan to prevent UI stalls.
          if (entity.lengthSync() > 256 * 1024) continue;
        } catch (_) {
          continue;
        }
        final path = entity.path;
        final fileName = path.split(RegExp(r'[\\/]')).last;
        if (_matchesExcludePattern(fileName)) continue;
        final lower = path.toLowerCase();
        final ext = _workspaceScanExts.firstWhere(
          (e) => lower.endsWith(e),
          orElse: () => '',
        );
        if (ext.isEmpty) continue;
        results.add(path);
      }
    }
    return results;
  }

  Future<String> _readTextSafely(String filePath) async {
    try {
      return await File(filePath).readAsString();
    } catch (_) {
      final bytes = await File(filePath).readAsBytes();
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  void _setWorkspaceDiagnosticsProgress({
    required bool isActive,
    required int processed,
    required int total,
  }) {
    if (_workspaceDiagnosticsProgressActive == isActive &&
        _workspaceDiagnosticsProgressProcessed == processed &&
        _workspaceDiagnosticsProgressTotal == total) {
      return;
    }
    _workspaceDiagnosticsProgressActive = isActive;
    _workspaceDiagnosticsProgressProcessed = processed;
    _workspaceDiagnosticsProgressTotal = total;
    if (mounted) {
      state = state.copyWith();
    }
  }

  void _markTransientLspStart(CodeLineEditingController controller) {
    final language = controller.lspLanguageId;
    if (language == null) return;
    final runtime =
        _transientLspRuntimeByLanguage[language] ??
        _TransientLspRuntime(
          languageId: language,
          serverExecutable: controller.lspServerExecutable,
          workspacePath: controller.lspWorkspacePath,
        );
    runtime.activeCount++;
    runtime.serverExecutable ??= controller.lspServerExecutable;
    runtime.workspacePath ??= controller.lspWorkspacePath;
    _transientLspRuntimeByLanguage[language] = runtime;
    if (mounted) {
      state = state.copyWith();
    }
  }

  void _markTransientLspEnd(CodeLineEditingController controller) {
    final language = controller.lspLanguageId;
    if (language == null) return;
    final runtime = _transientLspRuntimeByLanguage[language];
    if (runtime == null) return;
    runtime.activeCount = (runtime.activeCount - 1).clamp(0, 1 << 20);
    if (runtime.activeCount <= 0) {
      _transientLspRuntimeByLanguage.remove(language);
    } else {
      _transientLspRuntimeByLanguage[language] = runtime;
    }
    if (mounted) {
      state = state.copyWith();
    }
  }

  void _scheduleWorkspaceProblemWatcherRefresh() {
    _workspaceProblemWatcherRefreshTimer?.cancel();
    _workspaceProblemWatcherRefreshTimer = Timer(
      const Duration(milliseconds: 350),
      _refreshWorkspaceProblemWatchers,
    );
  }

  void _refreshWorkspaceProblemWatchers() {
    final problemFiles = <String>{};
    for (final entry in _workspaceDiagnosticsByPath.entries) {
      if (entry.value.isNotEmpty) {
        problemFiles.add(entry.key);
      }
    }

    for (final path in _workspaceProblemWatchers.keys.toList()) {
      if (problemFiles.any((p) => _isSamePath(p, path))) continue;
      _workspaceProblemDebounceTimers[path]?.cancel();
      _workspaceProblemDebounceTimers.remove(path);
      _workspaceProblemWatchers[path]?.cancel();
      _workspaceProblemWatchers.remove(path);
    }

    for (final path in problemFiles) {
      if (_workspaceProblemWatchers.keys.any((p) => _isSamePath(p, path))) {
        continue;
      }
      final file = File(path);
      if (!file.existsSync()) continue;
      try {
        _workspaceProblemWatchers[path] = file.parent.watch().listen((event) {
          if (!_isSamePath(event.path, path)) return;
          _workspaceProblemDebounceTimers[path]?.cancel();
          _workspaceProblemDebounceTimers[path] = Timer(
            const Duration(milliseconds: 450),
            () => _refreshWorkspaceDiagnosticFile(path),
          );
        });
      } catch (_) {}
    }
  }

  Future<void> _refreshWorkspaceDiagnosticFile(String filePath) async {
    final root = _workspaceDiagnosticsRoot;
    if (root == null || root.isEmpty) return;
    if (!_isPathUnder(root, filePath)) return;
    _setWorkspaceDiagnosticsProgress(isActive: true, processed: 0, total: 1);
    try {
      if (!File(filePath).existsSync()) {
        _workspaceDiagnosticsByPath.remove(filePath);
        _workspaceProblemDebounceTimers[filePath]?.cancel();
        _workspaceProblemDebounceTimers.remove(filePath);
        _workspaceProblemWatchers[filePath]?.cancel();
        _workspaceProblemWatchers.remove(filePath);
        _setWorkspaceDiagnosticsProgress(
          isActive: false,
          processed: 1,
          total: 1,
        );
        return;
      }

      final diagnostics = await _scanSingleFileDiagnostics(
        filePath: filePath,
        workspacePath: root,
      );
      _workspaceDiagnosticsByPath[filePath] = diagnostics;
      _syncInlineDiagnosticDecorations(filePath, diagnostics: diagnostics);
      _scheduleWorkspaceProblemWatcherRefresh();
      _setWorkspaceDiagnosticsProgress(isActive: false, processed: 1, total: 1);
      if (mounted) {
        state = state.copyWith();
      }
    } catch (_) {
      _setWorkspaceDiagnosticsProgress(isActive: false, processed: 1, total: 1);
    }
  }

  Future<List<CodeLspDiagnostic>> _scanSingleFileDiagnostics({
    required String filePath,
    required String workspacePath,
    bool warmupScan = false,
  }) async {
    final languageId = _languageIdForPathQuick(filePath);
    if (languageId == null) return const [];
    final content = await _readTextSafely(filePath);
    final simpleFallback = _treeSitterDiagnostics(
      filePath: filePath,
      languageId: languageId,
      text: content,
    );
    final useLsp = await _shouldUseLanguageServerDiagnostics();
    if (!useLsp) {
      return simpleFallback;
    }
    final disabled = await _disabledLspLanguages();
    if (disabled.contains(languageId)) return const [];
    final controller = await _createControllerForFile(
      text: content,
      filePath: filePath,
      workspacePath: workspacePath,
      bindOpenedFile: true,
    );
    try {
      if (!controller.hasLsp) {
        AppLogService.instance.warn(
          'lsp',
          'scanNoLsp path=$filePath lang=$languageId fallback=${simpleFallback.length}',
        );
        return simpleFallback;
      }
      _markTransientLspStart(controller);
      final lspDiagnostics = await _awaitDiagnosticsForCurrentFile(
        controller: controller,
        languageId: languageId,
        warmupScan: warmupScan,
      );
      if (lspDiagnostics.isEmpty && simpleFallback.isNotEmpty) {
        AppLogService.instance.warn(
          'lsp',
          'scanEmptyFallback path=$filePath lang=$languageId fallback=${simpleFallback.length}',
        );
        return simpleFallback;
      }
      return lspDiagnostics;
    } finally {
      _markTransientLspEnd(controller);
      controller.dispose();
    }
  }

  void _scheduleEditedFileDiagnostics({
    required String filePath,
    required String currentText,
  }) {
    final root = _workspaceDiagnosticsRoot;
    if (root == null || root.isEmpty) return;
    if (!_isPathUnder(root, filePath)) return;
    if (_languageIdForPathQuick(filePath) == null) return;
    _editedFileDiagnosticsDebounceTimers[filePath]?.cancel();
    _editedFileDiagnosticsDebounceTimers[filePath] = Timer(
      const Duration(milliseconds: 260),
      () => _refreshEditedFileDiagnostics(filePath, currentText),
    );
  }

  Future<void> _refreshEditedFileDiagnostics(
    String filePath,
    String currentText,
  ) async {
    final root = _workspaceDiagnosticsRoot;
    if (root == null || root.isEmpty) return;
    if (!_isPathUnder(root, filePath)) return;
    _setWorkspaceDiagnosticsProgress(isActive: true, processed: 0, total: 1);
    try {
      final languageId = _languageIdForPathQuick(filePath) ?? '';
      final useLsp = await _shouldUseLanguageServerDiagnostics();
      if (!useLsp) {
        final simpleDiagnostics = _treeSitterDiagnostics(
          filePath: filePath,
          languageId: languageId,
          text: currentText,
        );
        _workspaceDiagnosticsByPath[filePath] = simpleDiagnostics;
        _syncInlineDiagnosticDecorations(
          filePath,
          diagnostics: simpleDiagnostics,
        );
        _scheduleWorkspaceProblemWatcherRefresh();
        if (mounted) {
          state = state.copyWith();
        }
      } else {
        final controller = await _createControllerForFile(
          text: currentText,
          filePath: filePath,
          workspacePath: root,
          bindOpenedFile: true,
        );
        try {
          if (!controller.hasLsp) {
            _workspaceDiagnosticsByPath[filePath] = const [];
          } else {
            _markTransientLspStart(controller);
            controller.text = currentText;
            _workspaceDiagnosticsByPath[filePath] =
                await _awaitDiagnosticsForCurrentFile(
                  controller: controller,
                  languageId: languageId,
                  warmupScan: false,
                );
          }
        } finally {
          _markTransientLspEnd(controller);
          controller.dispose();
        }
        _scheduleWorkspaceProblemWatcherRefresh();
        _syncInlineDiagnosticDecorations(
          filePath,
          diagnostics: _workspaceDiagnosticsByPath[filePath],
        );
        if (mounted) {
          state = state.copyWith();
        }
      }
    } catch (_) {
    } finally {
      _setWorkspaceDiagnosticsProgress(isActive: false, processed: 1, total: 1);
    }
  }

  Future<List<CodeLspDiagnostic>> _awaitDiagnosticsForCurrentFile({
    required CodeLineEditingController controller,
    required String languageId,
    required bool warmupScan,
  }) async {
    final isHeavy = _heavyLspLanguages.contains(languageId);
    final maxWait =
        warmupScan
            ? (isHeavy
                ? const Duration(milliseconds: 2000)
                : const Duration(milliseconds: 1500))
            : (isHeavy
                ? const Duration(milliseconds: 1400)
                : const Duration(milliseconds: 900));
    final minWait =
        isHeavy
            ? const Duration(milliseconds: 140)
            : const Duration(milliseconds: 90);
    final poll =
        isHeavy
            ? const Duration(milliseconds: 70)
            : const Duration(milliseconds: 45);

    final start = DateTime.now();
    var last = List<CodeLspDiagnostic>.from(controller.diagnostics);
    while (DateTime.now().difference(start) < maxWait) {
      await Future<void>.delayed(poll);
      final current = List<CodeLspDiagnostic>.from(controller.diagnostics);
      final waited = DateTime.now().difference(start) >= minWait;
      if (waited && _diagnosticsEqual(last, current)) {
        return current;
      }
      last = current;
    }
    return List<CodeLspDiagnostic>.from(controller.diagnostics);
  }

  bool _diagnosticsEqual(List<CodeLspDiagnostic> a, List<CodeLspDiagnostic> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.severity != y.severity ||
          x.message != y.message ||
          x.startLine != y.startLine ||
          x.startCharacter != y.startCharacter ||
          x.endLine != y.endLine ||
          x.endCharacter != y.endCharacter) {
        return false;
      }
    }
    return true;
  }

  void _attachDiagnosticsListener(String tabId, String? filePath) {
    final controller = _controllers[tabId];
    if (controller == null) return;
    _detachDiagnosticsListener(tabId);
    if (_currentDiagnosticsEngineSync() != DiagnosticsEngine.languageServer) {
      return;
    }
    void syncWorkspaceDiagnosticsFromTab() {
      final path = filePath;
      final root = _workspaceDiagnosticsRoot;
      if (path == null || root == null || root.isEmpty) return;
      if (!_isPathUnder(root, path)) return;
      final diags = List<CodeLspDiagnostic>.from(controller.diagnostics);
      // Don't overwrite workspace cache with empty diagnostics from
      // non-active tabs. This prevents file explorer indicators from
      // vanishing when LSP clears diagnostics for a non-focused file.
      if (diags.isEmpty && tabId != state.tabGroup.activeTabId) return;
      _workspaceDiagnosticsByPath[path] = diags;
      _scheduleWorkspaceProblemWatcherRefresh();
    }

    // Always sync workspace diagnostics from tab when LSP reports them,
    // with a short delay to avoid jitter from LSP warm-up on initial open.
    void listener() {
      final count = _controllers[tabId]?.diagnostics.length ?? 0;
      if (!_editedTabs.contains(tabId)) {
        // For non-edited tabs, delay the sync to let LSP stabilize.
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          if (_controllers[tabId] == null) return;
          syncWorkspaceDiagnosticsFromTab();
          AppLogService.instance.info(
            'lsp',
            'diagnostics(delayed) tab=$tabId path=${filePath ?? ''} count=$count',
          );
          if (mounted) {
            state = state.copyWith();
          }
        });
        return;
      }
      syncWorkspaceDiagnosticsFromTab();
      AppLogService.instance.info(
        'lsp',
        'diagnostics tab=$tabId path=${filePath ?? ''} count=$count',
      );
      if (mounted) {
        state = state.copyWith();
      }
    }

    _diagnosticListeners[tabId] = listener;
    controller.diagnosticsNotifier.addListener(listener);
  }

  List<CodeLspDiagnostic> _treeSitterDiagnostics({
    required String filePath,
    required String languageId,
    required String text,
  }) {
    final ts = TreeSitterService.instance;
    if (!ts.isAvailable) return const [];
    final diagnostics = ts.parse(languageId, text, maxDiagnostics: 16);
    if (diagnostics.isEmpty) return const [];
    final lines = text.split('\n');
    final issues = <CodeLspDiagnostic>[];
    for (final d in diagnostics) {
      // Ensure the end position is at least one character after start
      // so the underline is visible in the editor.
      var endLine = d.endRow;
      var endCol = d.endCol;
      if (endLine == d.startRow && endCol <= d.startCol) {
        endCol = d.startCol + 1;
      }
      // Extract source context near the error for a more descriptive message.
      String message = d.message;
      if (d.startRow >= 0 && d.startRow < lines.length) {
        final line = lines[d.startRow];
        final col = d.startCol.clamp(0, line.length);
        final contextStart = (col - 12).clamp(0, line.length);
        final contextEnd = (col + 12).clamp(0, line.length);
        final snippet = line.substring(contextStart, contextEnd).trim();
        if (snippet.isNotEmpty) {
          message = "${d.message} near '$snippet'";
        }
      }
      // Map tree-sitter kind to LSP severity:
      // kind 0 (ERROR) → severity 1 (Error)
      // kind 1 (MISSING) → severity 2 (Warning)
      final severity = d.kind == 1 ? 2 : 1;
      issues.add(
        CodeLspDiagnostic(
          severity: severity,
          message: message,
          startLine: d.startRow,
          startCharacter: d.startCol,
          endLine: endLine,
          endCharacter: endCol,
        ),
      );
    }
    AppLogService.instance.info(
      'diag',
      'treeSitter path=$filePath lang=$languageId issues=${issues.length}',
    );
    return issues;
  }

  DiagnosticsEngine _currentDiagnosticsEngineSync() {
    final ref = _ref;
    if (ref != null) {
      return ref.read(editorSettingsProvider).diagnosticsEngine;
    }
    return DiagnosticsEngine.treeSitter;
  }

  Future<bool> _shouldUseLanguageServerDiagnostics() async {
    final ref = _ref;
    if (ref != null) {
      return ref.read(editorSettingsProvider).diagnosticsEngine ==
          DiagnosticsEngine.languageServer;
    }
    final cfg = await ConfigService.load();
    final raw = cfg['diagnosticsEngine'] as String?;
    final DiagnosticsEngine parsed;
    if (raw == null) {
      parsed = DiagnosticsEngine.treeSitter;
    } else if (raw == 'simpleSyntax') {
      parsed = DiagnosticsEngine.treeSitter;
    } else {
      parsed = DiagnosticsEngine.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => DiagnosticsEngine.treeSitter,
      );
    }
    return parsed == DiagnosticsEngine.languageServer;
  }

  String _fallbackServerLabelForLanguage(String languageId) {
    switch (languageId) {
      case 'dart':
        return 'dart';
      case 'javascript':
      case 'typescript':
        return 'typescript-language-server';
      case 'python':
        return 'pyright-langserver/pylsp';
      case 'c':
      case 'cpp':
        return 'ccls/clangd';
      case 'json':
        return 'vscode-json-language-server';
      case 'yaml':
        return 'yaml-language-server';
      case 'markdown':
        return 'marksman';
      case 'rust':
        return 'rust-analyzer';
      case 'go':
        return 'gopls';
      case 'java':
        return 'jdtls';
      case 'kotlin':
        return 'kotlin-language-server';
      case 'php':
        return 'intelephense';
      default:
        return languageId;
    }
  }

  void _detachDiagnosticsListener(String tabId) {
    final listener = _diagnosticListeners.remove(tabId);
    final controller = _controllers[tabId];
    if (listener != null && controller != null) {
      controller.diagnosticsNotifier.removeListener(listener);
    }
  }

  void _refreshDiagnosticsForOpenedFile(String tabId, String filePath) {
    _syncInlineDiagnosticDecorations(filePath);
  }

  /// Re-snapshots the saved content for a tab.  Called by EditorContent
  /// after the CodeEditor widget has fully initialised, so any internal
  /// normalisation the widget performs is captured in the baseline.
  void snapshotSavedContent(String tabId) {
    final controller = _controllers[tabId];
    if (controller != null) {
      // Preserve dirty state from cross-window transfer. Otherwise, a modified
      // tab can lose its unsaved marker after initial editor mount.
      if (_cachedModified[tabId] == true) return;
      _savedContent[tabId] = controller.text;
      _cachedModified[tabId] = false;
    }
  }

  /// Checks if the tab's current content differs from its saved content.
  bool isModified(String tabId) {
    final controller = _controllers[tabId];
    if (controller == null) return false;
    return controller.text != (_savedContent[tabId] ?? '');
  }

  /// Called by the editor content widget when the controller changes.
  /// Only triggers a state rebuild when modification status actually changes.
  void notifyContentChanged(String tabId) {
    if ((_readOnlyTabs[tabId] ?? false) == true) return;
    _editedTabs.add(tabId);
    final prev = _cachedModified[tabId] ?? false;
    final curr = isModified(tabId);
    if (prev != curr) {
      _cachedModified[tabId] = curr;
      state = state.copyWith();
    }

    // Auto-save after delay: reset timer on each change.
    if (autoSaveMode == AutoSaveMode.afterDelay) {
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(Duration(milliseconds: autoSaveDelayMs), () {
        final tab = state.tabGroup.tabs.where((t) => t.id == tabId).firstOrNull;
        if (tab != null && !tab.isUntitled && isModified(tabId)) {
          saveTab(tabId);
        }
      });
    }
    final tab = state.tabGroup.tabs.where((t) => t.id == tabId).firstOrNull;
    final controller = _controllers[tabId];
    if (tab?.filePath != null && controller != null) {
      final filePath = tab!.filePath!;
      _syncInlineDiagnosticDecorations(filePath);
      _scheduleEditedFileDiagnostics(
        filePath: filePath,
        currentText: controller.text,
      );
    }
    _scheduleHotExitSnapshot();
  }

  void _syncInlineDiagnosticDecorations(
    String filePath, {
    List<CodeLspDiagnostic>? diagnostics,
  }) {
    final useLsp =
        _currentDiagnosticsEngineSync() == DiagnosticsEngine.languageServer;
    final activeTabId = state.tabGroup.activeTabId;
    for (final tab in state.tabGroup.tabs) {
      if (tab.filePath == null) continue;
      final controller = _controllers[tab.id];
      if (controller == null) continue;
      final isFocusedTarget = tab.id == activeTabId && tab.filePath == filePath;
      if (useLsp) {
        controller.clearSyntheticDiagnosticsDecorations();
      } else {
        if (isFocusedTarget) {
          controller.applySyntheticDiagnosticsDecorations(
            diagnostics ?? _workspaceDiagnosticsByPath[filePath] ?? const [],
          );
        } else {
          controller.clearSyntheticDiagnosticsDecorations();
        }
      }
    }
  }

  void _refreshFocusedInlineDiagnosticDecorations() {
    final activeId = state.tabGroup.activeTabId;
    if (activeId == null) return;
    final tab = state.tabGroup.tabs.where((t) => t.id == activeId).firstOrNull;
    final path = tab?.filePath;
    if (path == null) {
      for (final controller in _controllers.values) {
        controller.clearSyntheticDiagnosticsDecorations();
      }
      return;
    }
    _syncInlineDiagnosticDecorations(path);
  }

  /// Returns true if any open tab has unsaved changes.
  bool hasUnsavedChanges() {
    return state.tabGroup.tabs.any((t) => isModified(t.id));
  }

  /// Returns all tabs that have unsaved changes.
  List<EditorTabModel> getModifiedTabs() {
    return state.tabGroup.tabs.where((t) => isModified(t.id)).toList();
  }

  /// Creates a new untitled tab with an empty editor.
  void createNewTab() {
    _untitledCounter++;
    final id = _nextId();
    _controllers[id] = CodeLineEditingController.fromText(
      '',
      CodeLineOptions(indentSize: indentSize),
    );
    _savedContent[id] = '';
    _readOnlyTabs[id] = false;
    _diffLinesByTab.remove(id);

    final tab = EditorTabModel(id: id, fileName: 'Untitled-$_untitledCounter');

    final tabs = [...state.tabGroup.tabs, tab];
    state = state.copyWith(
      tabGroup: state.tabGroup.copyWith(tabs: tabs, activeTabId: id),
    );
    AppLogService.instance.info(
      'editor',
      'createTab id=$id name=${tab.fileName}',
    );
    _scheduleHotExitSnapshot();
  }

  bool isTabReadOnly(String tabId) => _readOnlyTabs[tabId] ?? false;

  Set<int> getDiffLineIndexes(String tabId) =>
      _diffLinesByTab[tabId] ?? const {};

  Future<({String currentTabId, String snapshotTabId})?>
  openTimelineComparison({
    required String filePath,
    required String fileName,
    required String beforeContent,
    required String labelSuffix,
  }) async {
    await openTab(fileName, filePath);
    final currentTabId = state.tabGroup.activeTabId;
    if (currentTabId == null) return null;
    final currentController = _controllers[currentTabId];
    if (currentController == null) return null;

    final snapshotId = _nextId();
    final snapshotName = '$fileName ($labelSuffix)';
    _controllers[snapshotId] = CodeLineEditingController.fromText(
      beforeContent,
      CodeLineOptions(indentSize: indentSize),
    );
    _savedContent[snapshotId] = beforeContent;
    _cachedModified[snapshotId] = false;
    _readOnlyTabs[snapshotId] = true;

    final snapshotTab = EditorTabModel(
      id: snapshotId,
      fileName: snapshotName,
      filePath: null,
    );
    final tabs = [...state.tabGroup.tabs, snapshotTab];
    state = state.copyWith(
      tabGroup: state.tabGroup.copyWith(tabs: tabs, activeTabId: snapshotId),
    );

    final diff = _computeChangedLineIndexes(
      beforeContent,
      currentController.text,
    );
    final snapshotController = _controllers[snapshotId];
    snapshotController?.clearGitDiffDecorations();
    snapshotController?.setGitDiffDecorations(
      modifiedRanges: _toLineRanges(diff.left),
    );
    currentController.clearGitDiffDecorations();
    currentController.setGitDiffDecorations(
      modifiedRanges: _toLineRanges(diff.right),
    );
    _diffLinesByTab[snapshotId] = diff.left;
    _diffLinesByTab[currentTabId] = diff.right;
    _snapshotSourcePaths[snapshotId] = filePath;
    state = state.copyWith();
    return (currentTabId: currentTabId, snapshotTabId: snapshotId);
  }

  bool isSnapshotTab(String tabId) => _snapshotSourcePaths.containsKey(tabId);

  void restoreTimelineVersion(String snapshotTabId) {
    final snapshotController = _controllers[snapshotTabId];
    if (snapshotController == null) return;
    final snapshotText = snapshotController.text;
    final originalFilePath = _snapshotSourcePaths[snapshotTabId];
    if (originalFilePath == null) return;

    // Find the original file tab.
    final originalTab = state.tabGroup.tabs
        .where((t) => t.filePath == originalFilePath)
        .firstOrNull;
    if (originalTab == null) return;
    final originalController = _controllers[originalTab.id];
    if (originalController == null) return;

    // Restore the content.
    originalController.text = snapshotText;
    originalController.clearGitDiffDecorations();

    // Close the snapshot tab.
    forceCloseTab(snapshotTabId);

    // Activate the original tab.
    activateTab(originalTab.id);
  }

  Map<String, dynamic>? buildTabTransfer(String tabId) {
    final tab = state.tabGroup.tabs.where((t) => t.id == tabId).firstOrNull;
    if (tab == null || tab.isSettings) return null;

    final controller = _controllers[tabId];
    final content = controller?.text;
    final baseline = _savedContent[tabId];

    return {
      'fileName': tab.fileName,
      'filePath': tab.filePath,
      'isBinary': tab.isBinary,
      'content': content,
      'savedContent': baseline,
      'isModified': tab.isBinary ? false : isModified(tabId),
      'isReadOnly': _readOnlyTabs[tabId] ?? false,
    };
  }

  Future<void> openTransferredTab(
    Map<String, dynamic> payload, {
    bool activate = true,
  }) async {
    final fileName = payload['fileName'] as String? ?? 'Untitled';
    final filePath = payload['filePath'] as String?;
    final isBinary = payload['isBinary'] as bool? ?? false;
    final content = payload['content'] as String?;
    final savedContent = payload['savedContent'] as String?;
    final hasModifiedFlag = payload.containsKey('isModified');
    final modifiedFromPayload = payload['isModified'] as bool? ?? false;
    final isPinned = payload['isPinned'] as bool? ?? false;
    final isReadOnly = payload['isReadOnly'] as bool? ?? false;

    final existing =
        filePath == null
            ? null
            : state.tabGroup.tabs
                .where((t) => t.filePath == filePath)
                .firstOrNull;
    if (existing != null &&
        content == null &&
        !hasModifiedFlag &&
        existing.isBinary == isBinary) {
      if (activate) {
        state = state.copyWith(
          tabGroup: state.tabGroup.copyWith(activeTabId: existing.id),
        );
      }
      AppLogService.instance.info(
        'editor',
        'activateTransferredExistingTab id=${existing.id} path=${existing.filePath ?? ''}',
      );
      return;
    }

    final tabId = existing?.id ?? _nextId();
    if (existing == null) {
      final tab = EditorTabModel(
        id: tabId,
        fileName: fileName,
        filePath: filePath,
        isBinary: isBinary,
        isPinned: isPinned,
      );
      final tabs = [...state.tabGroup.tabs, tab];
      state = state.copyWith(
        tabGroup: state.tabGroup.copyWith(
          tabs: tabs,
          activeTabId: activate ? tabId : state.tabGroup.activeTabId,
        ),
      );
      AppLogService.instance.info(
        'editor',
        'openTransferredTab id=$tabId path=${filePath ?? ''} readOnly=$isReadOnly',
      );
    } else {
      final tabs =
          state.tabGroup.tabs.map((t) {
            if (t.id != tabId) return t;
            return t.copyWith(
              fileName: fileName,
              filePath: filePath,
              isBinary: isBinary,
              isPinned: isPinned,
            );
          }).toList();
      state = state.copyWith(
        tabGroup: state.tabGroup.copyWith(
          tabs: tabs,
          activeTabId: activate ? tabId : state.tabGroup.activeTabId,
        ),
      );
      AppLogService.instance.info(
        'editor',
        'replaceTransferredTab id=$tabId path=${filePath ?? ''} readOnly=$isReadOnly',
      );
    }

    if (isBinary) {
      _detachDiagnosticsListener(tabId);
      _controllers[tabId]?.dispose();
      _controllers.remove(tabId);
      _findControllers[tabId]?.dispose();
      _findControllers.remove(tabId);
      _savedContent.remove(tabId);
      _cachedModified[tabId] = false;
      _readOnlyTabs.remove(tabId);
      _diffLinesByTab.remove(tabId);
      _stopWatchingFile(tabId);
      return;
    }

    final text = content ?? '';
    _detachDiagnosticsListener(tabId);
    _controllers[tabId]?.dispose();
    if (filePath != null) {
      _controllers[tabId] = await _createControllerForFile(
        text: text,
        filePath: filePath,
        workspacePath: _workspacePathForFile(filePath),
        bindOpenedFile: false,
      );
      _attachDiagnosticsListener(tabId, filePath);
      _refreshDiagnosticsForOpenedFile(tabId, filePath);
    } else {
      _controllers[tabId] = CodeLineEditingController.fromText(
        text,
        CodeLineOptions(indentSize: indentSize),
      );
    }
    _savedContent[tabId] = savedContent ?? text;
    _cachedModified[tabId] =
        hasModifiedFlag ? modifiedFromPayload : text != (savedContent ?? text);
    _readOnlyTabs[tabId] = isReadOnly;
    _diffLinesByTab.remove(tabId);

    if (filePath != null) {
      _startWatchingFile(tabId, filePath);
    }
    _scheduleHotExitSnapshot();
  }

  /// Opens settings as an editor tab and activates it.
  /// If settings tab already exists, switches section and reuses that tab.
  void openSettingsTab({required String title, required String section}) {
    final existingIndex = state.tabGroup.tabs.indexWhere((t) => t.isSettings);
    if (existingIndex != -1) {
      final tabs = [...state.tabGroup.tabs];
      final existing = tabs[existingIndex];
      tabs[existingIndex] = existing.copyWith(
        fileName: title,
        settingsSection: section,
      );
      state = state.copyWith(
        tabGroup: state.tabGroup.copyWith(tabs: tabs, activeTabId: existing.id),
      );
      _scheduleHotExitSnapshot();
      return;
    }

    final id = _nextId();
    final tab = EditorTabModel(
      id: id,
      fileName: title,
      settingsSection: section,
    );
    final tabs = [...state.tabGroup.tabs, tab];
    state = state.copyWith(
      tabGroup: state.tabGroup.copyWith(tabs: tabs, activeTabId: id),
    );
    _scheduleHotExitSnapshot();
  }

  Future<void> openTab(String fileName, String filePath) async {
    final existing = state.tabGroup.tabs.where((t) => t.filePath == filePath);
    if (existing.isNotEmpty) {
      final tab = existing.first;
      state = state.copyWith(
        tabGroup: state.tabGroup.copyWith(activeTabId: tab.id),
      );
      _refreshFocusedInlineDiagnosticDecorations();
      AppLogService.instance.info(
        'editor',
        'focusExistingTab id=${tab.id} path=$filePath',
      );
      return;
    }

    final id = _nextId();

    try {
      final file = File(filePath);
      if (await file.exists()) {
        if (_isKnownBinaryExtension(filePath)) {
          final tab = EditorTabModel(
            id: id,
            fileName: fileName,
            filePath: filePath,
            isBinary: true,
          );
          final tabs = [...state.tabGroup.tabs, tab];
          state = state.copyWith(
            tabGroup: state.tabGroup.copyWith(tabs: tabs, activeTabId: id),
          );
          return;
        }

        final bytes = await file.readAsBytes();
        if (!mounted) return;

        if (_isBinaryFile(bytes)) {
          final tab = EditorTabModel(
            id: id,
            fileName: fileName,
            filePath: filePath,
            isBinary: true,
          );
          final tabs = [...state.tabGroup.tabs, tab];
          state = state.copyWith(
            tabGroup: state.tabGroup.copyWith(tabs: tabs, activeTabId: id),
          );
          return;
        }

        final content = _decodeForOpen(bytes);
        _controllers[id] = await _createControllerForFile(
          text: content,
          filePath: filePath,
          workspacePath: _workspacePathForFile(filePath),
        );
        _attachDiagnosticsListener(id, filePath);
        _refreshDiagnosticsForOpenedFile(id, filePath);
        _savedContent[id] = _controllers[id]!.text;
        _readOnlyTabs[id] = false;
        _diffLinesByTab.remove(id);
      } else {
        _controllers[id] = await _createControllerForFile(
          text: '',
          filePath: filePath,
          workspacePath: _workspacePathForFile(filePath),
        );
        _attachDiagnosticsListener(id, filePath);
        _refreshDiagnosticsForOpenedFile(id, filePath);
        _savedContent[id] = '';
        _readOnlyTabs[id] = false;
        _diffLinesByTab.remove(id);
      }
    } catch (_) {
      if (!mounted) return;
      _controllers[id] = await _createControllerForFile(
        text: '',
        filePath: filePath,
        workspacePath: _workspacePathForFile(filePath),
      );
      _attachDiagnosticsListener(id, filePath);
      _refreshDiagnosticsForOpenedFile(id, filePath);
      _savedContent[id] = '';
      _readOnlyTabs[id] = false;
      _diffLinesByTab.remove(id);
    }

    if (!mounted) return;

    final tab = EditorTabModel(id: id, fileName: fileName, filePath: filePath);

    final tabs = [...state.tabGroup.tabs, tab];
    state = state.copyWith(
      tabGroup: state.tabGroup.copyWith(tabs: tabs, activeTabId: id),
    );
    _refreshFocusedInlineDiagnosticDecorations();
    AppLogService.instance.info('editor', 'openTab id=$id path=$filePath');
    _startWatchingFile(tab.id, filePath);
    _scheduleHotExitSnapshot();
  }

  /// Force-opens a binary tab as text, replacing the existing binary tab.
  Future<void> forceOpenTab(String tabId) async {
    final tab = state.tabGroup.tabs.where((t) => t.id == tabId).firstOrNull;
    if (tab == null || tab.filePath == null) return;

    String content = '';
    try {
      final file = File(tab.filePath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        content = _decodeForOpen(bytes);
      }
    } catch (_) {}

    if (!mounted) return;

    _detachDiagnosticsListener(tabId);
    _controllers[tabId]?.dispose();
    _controllers[tabId] = await _createControllerForFile(
      text: content,
      filePath: tab.filePath!,
      workspacePath: _workspacePathForFile(tab.filePath!),
    );
    _attachDiagnosticsListener(tabId, tab.filePath);
    _refreshDiagnosticsForOpenedFile(tabId, tab.filePath!);
    _savedContent[tabId] = _controllers[tabId]!.text;

    final tabs =
        state.tabGroup.tabs.map((t) {
          if (t.id == tabId) return t.copyWith(isBinary: false);
          return t;
        }).toList();

    state = state.copyWith(tabGroup: state.tabGroup.copyWith(tabs: tabs));
    _startWatchingFile(tabId, tab.filePath!);
  }

  bool _isBinaryFile(List<int> bytes) {
    final checkLength = bytes.length < 8192 ? bytes.length : 8192;
    for (var i = 0; i < checkLength; i++) {
      if (bytes[i] == 0) return true;
    }
    return false;
  }

  bool _isKnownBinaryExtension(String filePath) {
    final dot = filePath.lastIndexOf('.');
    if (dot < 0 || dot == filePath.length - 1) return false;
    final ext = filePath.substring(dot + 1).toLowerCase();
    const knownBinaryExts = {
      '7z',
      'a',
      'bin',
      'bmp',
      'class',
      'cur',
      'dat',
      'db',
      'dll',
      'dylib',
      'ear',
      'elc',
      'exe',
      'gif',
      'ico',
      'img',
      'iso',
      'jar',
      'jpeg',
      'jpg',
      'lib',
      'mdb',
      'mp3',
      'mp4',
      'nupkg',
      'o',
      'obj',
      'otf',
      'pdf',
      'png',
      'pyc',
      'so',
      'tar',
      'ttf',
      'war',
      'wav',
      'webp',
      'woff',
      'woff2',
      'zip',
    };
    return knownBinaryExts.contains(ext);
  }

  ({Set<int> left, Set<int> right}) _computeChangedLineIndexes(
    String leftText,
    String rightText,
  ) {
    final left = leftText.split('\n');
    final right = rightText.split('\n');
    final leftChanged = <int>{};
    final rightChanged = <int>{};
    int i = 0;
    int j = 0;
    while (i < left.length && j < right.length) {
      if (left[i] == right[j]) {
        i++;
        j++;
        continue;
      }
      final nextLeftMatches = i + 1 < left.length && left[i + 1] == right[j];
      final nextRightMatches = j + 1 < right.length && left[i] == right[j + 1];
      if (nextLeftMatches && !nextRightMatches) {
        leftChanged.add(i);
        i++;
      } else if (!nextLeftMatches && nextRightMatches) {
        rightChanged.add(j);
        j++;
      } else {
        leftChanged.add(i);
        rightChanged.add(j);
        i++;
        j++;
      }
    }
    while (i < left.length) {
      leftChanged.add(i);
      i++;
    }
    while (j < right.length) {
      rightChanged.add(j);
      j++;
    }
    return (left: leftChanged, right: rightChanged);
  }

  List<(int, int)> _toLineRanges(Set<int> lineIndexes) {
    if (lineIndexes.isEmpty) return const [];
    final sorted = lineIndexes.toList()..sort();
    final ranges = <(int, int)>[];
    int start = sorted.first;
    int previous = sorted.first;
    for (int i = 1; i < sorted.length; i++) {
      final line = sorted[i];
      if (line == previous + 1) {
        previous = line;
        continue;
      }
      ranges.add((start, previous));
      start = line;
      previous = line;
    }
    ranges.add((start, previous));
    return ranges;
  }

  void _publishTimeline(TimelineEvent event) {
    _ref?.read(timelineProvider.notifier).add(event);
  }

  void closeTab(String tabId) {
    // Prevent closing pinned tabs through regular close.
    final tab = state.tabGroup.tabs.where((t) => t.id == tabId).firstOrNull;
    if (tab != null && tab.isPinned) return;

    _controllers[tabId]?.dispose();
    _controllers.remove(tabId);
    _findControllers[tabId]?.dispose();
    _findControllers.remove(tabId);
    _stopWatchingFile(tabId);
    if (tab?.filePath != null) {
      _forgetKnownModified(tab!.filePath!);
    }
    _savedContent.remove(tabId);
    _cachedModified.remove(tabId);
    _readOnlyTabs.remove(tabId);
    _snapshotSourcePaths.remove(tabId);
    _diffLinesByTab.remove(tabId);
    _editedTabs.remove(tabId);

    final oldIndex = state.tabGroup.tabs.indexWhere((t) => t.id == tabId);
    final tabs = state.tabGroup.tabs.where((t) => t.id != tabId).toList();
    String? activeId = state.tabGroup.activeTabId;
    if (activeId == tabId) {
      if (tabs.isEmpty) {
        activeId = null;
      } else {
        activeId = tabs[oldIndex.clamp(0, tabs.length - 1)].id;
      }
    }
    state = state.copyWith(
      tabGroup: state.tabGroup.copyWith(tabs: tabs, activeTabId: activeId),
    );
    AppLogService.instance.info('editor', 'closeTab id=$tabId');
    _scheduleHotExitSnapshot();
    // Release non-primary LSP if no more tabs of this language remain
    if (tab?.filePath != null) {
      _releaseNonPrimaryLspIfUnused(tab!.filePath);
    }
  }

  /// Force-close a tab ignoring pin status (used by unpin + close workflows).
  void forceCloseTab(String tabId) {
    final tab = state.tabGroup.tabs.where((t) => t.id == tabId).firstOrNull;
    _controllers[tabId]?.dispose();
    _controllers.remove(tabId);
    _findControllers[tabId]?.dispose();
    _findControllers.remove(tabId);
    _stopWatchingFile(tabId);
    if (tab?.filePath != null) {
      _forgetKnownModified(tab!.filePath!);
    }
    _savedContent.remove(tabId);
    _cachedModified.remove(tabId);
    _readOnlyTabs.remove(tabId);
    _snapshotSourcePaths.remove(tabId);
    _diffLinesByTab.remove(tabId);
    _editedTabs.remove(tabId);

    final oldIndex = state.tabGroup.tabs.indexWhere((t) => t.id == tabId);
    final tabs = state.tabGroup.tabs.where((t) => t.id != tabId).toList();
    String? activeId = state.tabGroup.activeTabId;
    if (activeId == tabId) {
      if (tabs.isEmpty) {
        activeId = null;
      } else {
        activeId = tabs[oldIndex.clamp(0, tabs.length - 1)].id;
      }
    }
    state = state.copyWith(
      tabGroup: state.tabGroup.copyWith(tabs: tabs, activeTabId: activeId),
    );
    AppLogService.instance.info('editor', 'forceCloseTab id=$tabId');
    _scheduleHotExitSnapshot();
    // Release non-primary LSP if no more tabs of this language remain
    if (tab?.filePath != null) {
      _releaseNonPrimaryLspIfUnused(tab!.filePath);
    }
  }

  void activateTab(String tabId) {
    state = state.copyWith(
      tabGroup: state.tabGroup.copyWith(activeTabId: tabId),
    );
    _refreshFocusedInlineDiagnosticDecorations();
    _scheduleHotExitSnapshot();
  }

  void activateNextTab() {
    final tabs = state.tabGroup.tabs;
    if (tabs.length <= 1) return;
    final currentIdx = tabs.indexWhere(
      (t) => t.id == state.tabGroup.activeTabId,
    );
    final nextIdx = (currentIdx + 1) % tabs.length;
    activateTab(tabs[nextIdx].id);
  }

  void activatePreviousTab() {
    final tabs = state.tabGroup.tabs;
    if (tabs.length <= 1) return;
    final currentIdx = tabs.indexWhere(
      (t) => t.id == state.tabGroup.activeTabId,
    );
    final prevIdx = (currentIdx - 1 + tabs.length) % tabs.length;
    activateTab(tabs[prevIdx].id);
  }

  /// Reorders a tab from [oldIndex] to [newIndex].
  /// Pinned tabs stay at the front and cannot be reordered past unpinned tabs.
  void reorderTab(int oldIndex, int newIndex) {
    final tabs = [...state.tabGroup.tabs];
    if (oldIndex < 0 || oldIndex >= tabs.length) return;

    // ReorderableListView adjusts newIndex when dragging down.
    if (newIndex > oldIndex) newIndex--;
    if (newIndex < 0 || newIndex >= tabs.length) return;
    if (oldIndex == newIndex) return;

    final pinnedCount = tabs.where((t) => t.isPinned).length;
    final tab = tabs[oldIndex];

    // Prevent moving pinned tabs into unpinned zone or vice-versa.
    if (tab.isPinned && newIndex >= pinnedCount) return;
    if (!tab.isPinned && newIndex < pinnedCount) return;

    tabs.removeAt(oldIndex);
    tabs.insert(newIndex, tab);
    state = state.copyWith(tabGroup: state.tabGroup.copyWith(tabs: tabs));
    _scheduleHotExitSnapshot();
  }

  /// Reorders tabs based on a complete id sequence.
  /// Any missing ids keep their relative order and are appended.
  void reorderTabsByIdOrder(List<String> orderedIds) {
    if (orderedIds.isEmpty) return;
    final byId = <String, EditorTabModel>{
      for (final t in state.tabGroup.tabs) t.id: t,
    };
    final used = <String>{};
    final reordered = <EditorTabModel>[];
    for (final id in orderedIds) {
      final tab = byId[id];
      if (tab == null || used.contains(id)) continue;
      reordered.add(tab);
      used.add(id);
    }
    for (final tab in state.tabGroup.tabs) {
      if (!used.contains(tab.id)) {
        reordered.add(tab);
      }
    }
    state = state.copyWith(tabGroup: state.tabGroup.copyWith(tabs: reordered));
    _scheduleHotExitSnapshot();
  }

  /// Toggles pin status for a tab.
  void togglePinTab(String tabId) {
    final tabs = [...state.tabGroup.tabs];
    final index = tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final tab = tabs[index];
    final newPinned = !tab.isPinned;
    tabs[index] = tab.copyWith(isPinned: newPinned);

    if (newPinned) {
      // Move to end of pinned group.
      final pinnedTab = tabs.removeAt(index);
      final pinnedCount = tabs.where((t) => t.isPinned).length;
      tabs.insert(pinnedCount, pinnedTab);
    } else {
      // Move to start of unpinned group.
      final unpinnedTab = tabs.removeAt(index);
      final pinnedCount = tabs.where((t) => t.isPinned).length;
      tabs.insert(pinnedCount, unpinnedTab);
    }

    state = state.copyWith(tabGroup: state.tabGroup.copyWith(tabs: tabs));
    _scheduleHotExitSnapshot();
  }

  Future<bool> saveTab(String tabId) async {
    final tab = state.tabGroup.tabs.where((t) => t.id == tabId).firstOrNull;
    final controller = _controllers[tabId];
    if (tab == null || controller == null) return false;
    if ((_readOnlyTabs[tabId] ?? false) == true) return false;

    if (tab.isUntitled) {
      await saveTabAs(tabId);
      if (!mounted) return false;
      return !isModified(tabId);
    }

    await _applyAutoFormatOnSave(tabId, targetNameOrPath: tab.filePath);

    if (trimTrailingWhitespace) {
      _trimTrailingWhitespace(controller);
    }

    final beforeContent = _savedContent[tabId] ?? controller.text;
    try {
      await File(tab.filePath!).writeAsString(controller.text);
      if (!mounted) return false;
      await _updateKnownModified(tab.filePath!);
      _savedContent[tabId] = controller.text;
      _cachedModified[tabId] = false;
      state = state.copyWith();
      AppLogService.instance.info(
        'editor',
        'saveTab id=$tabId path=${tab.filePath}',
      );
      _publishTimeline(
        TimelineEvent(
          id: 'tl_${DateTime.now().microsecondsSinceEpoch}_$tabId',
          type: TimelineEventType.saved,
          fileName: tab.fileName,
          filePath: tab.filePath!,
          timestamp: DateTime.now(),
          beforeContent: beforeContent,
        ),
      );
      _scheduleHotExitSnapshot();
      return true;
    } catch (e) {
      AppLogService.instance.error(
        'editor',
        'saveTabFailed id=$tabId error=$e',
      );
      return false;
    }
  }

  Future<void> saveTabAs(String tabId) async {
    final tab = state.tabGroup.tabs.where((t) => t.id == tabId).firstOrNull;
    final controller = _controllers[tabId];
    if (tab == null || controller == null) return;

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save As',
      fileName: tab.fileName,
    );
    if (result == null) return;

    try {
      final oldFilePath = tab.filePath;
      await _applyAutoFormatOnSave(tabId, targetNameOrPath: result);
      await File(result).writeAsBytes(_encodeByDefault(controller.text));
      if (!mounted) return;

      final newFileName = result.split(Platform.pathSeparator).last;
      final tabs =
          state.tabGroup.tabs.map((t) {
            if (t.id == tabId) {
              return t.copyWith(fileName: newFileName, filePath: result);
            }
            return t;
          }).toList();

      _savedContent[tabId] = controller.text;
      _cachedModified[tabId] = false;
      state = state.copyWith(tabGroup: state.tabGroup.copyWith(tabs: tabs));
      AppLogService.instance.info('editor', 'saveTabAs id=$tabId path=$result');
      if (oldFilePath != null && oldFilePath != result) {
        _forgetKnownModified(oldFilePath);
      }
      _startWatchingFile(tabId, result);
      _publishTimeline(
        TimelineEvent(
          id: 'tl_${DateTime.now().microsecondsSinceEpoch}_$tabId',
          type: TimelineEventType.saved,
          fileName: newFileName,
          filePath: result,
          timestamp: DateTime.now(),
        ),
      );
      _scheduleHotExitSnapshot();
    } catch (e) {
      AppLogService.instance.error(
        'editor',
        'saveTabAsFailed id=$tabId target=$result error=$e',
      );
    }
  }

  Future<bool> saveActiveTab() async {
    final activeId = state.tabGroup.activeTabId;
    if (activeId != null) {
      return await saveTab(activeId);
    }
    return false;
  }

  Future<void> saveActiveTabAs() async {
    final activeId = state.tabGroup.activeTabId;
    if (activeId != null) {
      await saveTabAs(activeId);
    }
  }

  Future<CodeFormatResult> formatActiveTab() async {
    final activeId = state.tabGroup.activeTabId;
    if (activeId == null) {
      return const CodeFormatResult(
        supported: false,
        changed: false,
        message: 'No active tab',
      );
    }
    final tab = state.tabGroup.tabs.where((t) => t.id == activeId).firstOrNull;
    final controller = _controllers[activeId];
    if (tab == null || controller == null || tab.isBinary || tab.isSettings) {
      return const CodeFormatResult(
        supported: false,
        changed: false,
        message: 'Tab cannot be formatted',
      );
    }

    final targetName = tab.filePath ?? tab.fileName;
    final result = await _codeFormatService.format(
      fileNameOrPath: targetName,
      source: controller.text,
    );
    if (!result.supported || !result.changed || result.formattedText == null) {
      AppLogService.instance.info(
        'editor',
        'formatActiveTab supported=${result.supported} changed=${result.changed}',
      );
      return result;
    }

    controller.text = result.formattedText!;
    notifyContentChanged(activeId);
    AppLogService.instance.info('editor', 'formatActiveTab changed=true');
    return result;
  }

  /// Saves all modified tabs that have file paths (not untitled).
  Future<void> saveAllModifiedTabs() async {
    for (final tab in state.tabGroup.tabs) {
      if (!tab.isUntitled && isModified(tab.id)) {
        await saveTab(tab.id);
      }
    }
  }

  void closeOtherTabs(String tabId) {
    for (final t in state.tabGroup.tabs) {
      if (t.id != tabId && !t.isPinned) {
        _detachDiagnosticsListener(t.id);
        _controllers[t.id]?.dispose();
        _controllers.remove(t.id);
        _findControllers[t.id]?.dispose();
        _findControllers.remove(t.id);
        _stopWatchingFile(t.id);
        if (t.filePath != null) {
          _forgetKnownModified(t.filePath!);
        }
        _savedContent.remove(t.id);
        _cachedModified.remove(t.id);
        _readOnlyTabs.remove(t.id);
        _diffLinesByTab.remove(t.id);
      }
    }
    final tabs =
        state.tabGroup.tabs.where((t) => t.id == tabId || t.isPinned).toList();
    state = state.copyWith(
      tabGroup: state.tabGroup.copyWith(tabs: tabs, activeTabId: tabId),
    );
    _scheduleHotExitSnapshot();
  }

  void closeAllTabs() {
    final pinned = state.tabGroup.tabs.where((t) => t.isPinned).toList();
    for (final t in state.tabGroup.tabs) {
      if (!t.isPinned) {
        _detachDiagnosticsListener(t.id);
        _controllers[t.id]?.dispose();
        _controllers.remove(t.id);
        _findControllers[t.id]?.dispose();
        _findControllers.remove(t.id);
        _stopWatchingFile(t.id);
        if (t.filePath != null) {
          _forgetKnownModified(t.filePath!);
        }
        _savedContent.remove(t.id);
        _cachedModified.remove(t.id);
        _readOnlyTabs.remove(t.id);
        _diffLinesByTab.remove(t.id);
      }
    }
    String? activeId;
    if (pinned.isNotEmpty) {
      activeId = pinned.last.id;
    }
    state = state.copyWith(
      tabGroup: state.tabGroup.copyWith(tabs: pinned, activeTabId: activeId),
    );
    _scheduleHotExitSnapshot();
  }

  void closeSavedTabs() {
    final toClose =
        state.tabGroup.tabs
            .where((t) => !isModified(t.id) && !t.isPinned)
            .toList();
    for (final t in toClose) {
      _detachDiagnosticsListener(t.id);
      _controllers[t.id]?.dispose();
      _controllers.remove(t.id);
      _findControllers[t.id]?.dispose();
      _findControllers.remove(t.id);
      _stopWatchingFile(t.id);
      if (t.filePath != null) {
        _forgetKnownModified(t.filePath!);
      }
      _savedContent.remove(t.id);
      _cachedModified.remove(t.id);
      _readOnlyTabs.remove(t.id);
      _diffLinesByTab.remove(t.id);
    }
    final remaining =
        state.tabGroup.tabs
            .where((t) => isModified(t.id) || t.isPinned)
            .toList();
    String? activeId = state.tabGroup.activeTabId;
    if (remaining.isEmpty) {
      activeId = null;
    } else if (!remaining.any((t) => t.id == activeId)) {
      activeId = remaining.last.id;
    }
    state = state.copyWith(
      tabGroup: state.tabGroup.copyWith(tabs: remaining, activeTabId: activeId),
    );
    _scheduleHotExitSnapshot();
  }

  /// Detects the line ending style from raw file bytes.
  static String detectLineEnding(String rawContent) {
    if (rawContent.contains('\r\n')) return 'CRLF';
    return 'LF';
  }

  /// Trims trailing whitespace from every line in the controller.
  void _trimTrailingWhitespace(CodeLineEditingController controller) {
    final lines = controller.codeLines;
    bool changed = false;
    for (int i = 0; i < lines.length; i++) {
      final text = lines[i].text;
      final trimmed = text.replaceFirst(RegExp(r'\s+$'), '');
      if (trimmed != text) {
        changed = true;
        break;
      }
    }
    if (!changed) return;
    // Rebuild the text with trimmed lines
    final buffer = StringBuffer();
    for (int i = 0; i < lines.length; i++) {
      if (i > 0) buffer.write('\n');
      buffer.write(lines[i].text.replaceFirst(RegExp(r'\s+$'), ''));
    }
    controller.text = buffer.toString();
  }

  /// Reloads the active tab's file with a different encoding.
  Future<void> reloadWithEncoding(
    String tabId,
    Encoding codec, {
    bool isBom = false,
  }) async {
    final tab = state.tabGroup.tabs.where((t) => t.id == tabId).firstOrNull;
    if (tab == null || tab.filePath == null) return;
    final controller = _controllers[tabId];
    if (controller == null) return;

    try {
      var bytes = await File(tab.filePath!).readAsBytes();
      // Strip UTF-8 BOM if present
      if (isBom &&
          bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF) {
        bytes = bytes.sublist(3);
      }
      final content = codec.decode(bytes);
      if (!mounted) return;
      controller.text = content;
      _savedContent[tabId] = controller.text;
      _cachedModified[tabId] = false;
      state = state.copyWith();
    } catch (_) {}
  }

  /// Saves the active tab's file with a specific encoding.
  Future<void> saveWithEncoding(
    String tabId,
    Encoding codec, {
    bool isBom = false,
  }) async {
    final tab = state.tabGroup.tabs.where((t) => t.id == tabId).firstOrNull;
    final controller = _controllers[tabId];
    if (tab == null || controller == null || tab.filePath == null) return;

    try {
      await _applyAutoFormatOnSave(tabId, targetNameOrPath: tab.filePath);
      final encoded = codec.encode(controller.text);
      List<int> bytes;
      if (isBom) {
        bytes = [0xEF, 0xBB, 0xBF, ...encoded];
      } else {
        bytes = encoded;
      }
      await File(tab.filePath!).writeAsBytes(bytes);
      if (!mounted) return;
      await _updateKnownModified(tab.filePath!);
      _savedContent[tabId] = controller.text;
      _cachedModified[tabId] = false;
      state = state.copyWith();
      _publishTimeline(
        TimelineEvent(
          id: 'tl_${DateTime.now().microsecondsSinceEpoch}_$tabId',
          type: TimelineEventType.saved,
          fileName: tab.fileName,
          filePath: tab.filePath!,
          timestamp: DateTime.now(),
        ),
      );
    } catch (_) {}
  }

  void _startWatchingFile(String tabId, String filePath) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    _stopWatchingFile(tabId);
    final file = File(filePath);
    if (!file.existsSync()) return;

    _updateKnownModified(filePath);
    try {
      _fileWatchers[tabId] = file.parent.watch().listen((event) {
        if (!mounted) return;
        if (!_controllers.containsKey(tabId)) return;
        if (!_isSamePath(event.path, filePath)) return;
        _fileWatchDebounceTimers[tabId]?.cancel();
        _fileWatchDebounceTimers[tabId] = Timer(
          const Duration(milliseconds: 250),
          () => _onExternalFileChanged(tabId),
        );
      });
    } catch (_) {}
  }

  void _stopWatchingFile(String tabId) {
    _fileWatchDebounceTimers[tabId]?.cancel();
    _fileWatchDebounceTimers.remove(tabId);
    _fileWatchers[tabId]?.cancel();
    _fileWatchers.remove(tabId);
  }

  Future<void> _onExternalFileChanged(String tabId) async {
    if (!mounted) return;
    final tab = state.tabGroup.tabs.where((t) => t.id == tabId).firstOrNull;
    if (tab == null || tab.filePath == null) return;
    final controller = _controllers[tabId];
    if (controller == null) return;

    final file = File(tab.filePath!);
    if (!await file.exists()) return;

    final modified = await file.lastModified();
    final known = _lastKnownModified[tab.filePath!];
    if (known != null && !modified.isAfter(known)) return;

    if (isModified(tabId)) {
      _lastKnownModified[tab.filePath!] = modified;
      _externalSyncController.add(
        ExternalFileSyncEvent(
          tabId: tabId,
          fileName: tab.fileName,
          type: ExternalFileSyncType.conflict,
        ),
      );
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      final nextText = _decodeForOpen(bytes);
      if (controller.text == nextText) {
        _lastKnownModified[tab.filePath!] = modified;
        return;
      }
      controller.text = nextText;
      _savedContent[tabId] = nextText;
      _cachedModified[tabId] = false;
      _lastKnownModified[tab.filePath!] = modified;
      state = state.copyWith();
      _externalSyncController.add(
        ExternalFileSyncEvent(
          tabId: tabId,
          fileName: tab.fileName,
          type: ExternalFileSyncType.reloaded,
        ),
      );
    } catch (_) {}
  }

  Future<void> _updateKnownModified(String filePath) async {
    try {
      _lastKnownModified[filePath] = await File(filePath).lastModified();
    } catch (_) {}
  }

  void _forgetKnownModified(String filePath) {
    _lastKnownModified.remove(filePath);
  }

  bool _isSamePath(String a, String b) {
    if (Platform.isWindows) {
      return a.toLowerCase() == b.toLowerCase();
    }
    return a == b;
  }

  String _decodeForOpen(List<int> bytes) {
    if (_isUtf8Bom(bytes)) {
      return const Utf8Codec(
        allowMalformed: true,
      ).decode(bytes.sublist(3), allowMalformed: true);
    }

    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {}

    if (_looksLikeGbk(bytes)) {
      try {
        return charset.gbk.decode(bytes);
      } catch (_) {}
    }

    try {
      return _decodeWithOption(bytes, defaultFileEncoding);
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  String _decodeWithOption(List<int> bytes, FileEncodingOption option) {
    switch (option) {
      case FileEncodingOption.utf8:
        return const Utf8Codec(allowMalformed: true).decode(bytes);
      case FileEncodingOption.utf8bom:
        if (_isUtf8Bom(bytes)) {
          return const Utf8Codec(
            allowMalformed: true,
          ).decode(bytes.sublist(3), allowMalformed: true);
        }
        return const Utf8Codec(allowMalformed: true).decode(bytes);
      case FileEncodingOption.gbk:
      case FileEncodingOption.gb18030:
        return charset.gbk.decode(bytes);
    }
  }

  List<int> _encodeByDefault(String text) {
    switch (defaultFileEncoding) {
      case FileEncodingOption.utf8:
        return utf8.encode(text);
      case FileEncodingOption.utf8bom:
        return [0xEF, 0xBB, 0xBF, ...utf8.encode(text)];
      case FileEncodingOption.gbk:
      case FileEncodingOption.gb18030:
        return charset.gbk.encode(text);
    }
  }

  bool _isUtf8Bom(List<int> bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF;
  }

  Future<void> _applyAutoFormatOnSave(
    String tabId, {
    String? targetNameOrPath,
  }) async {
    if (!autoFormatOnSave) return;
    final tab = state.tabGroup.tabs.where((t) => t.id == tabId).firstOrNull;
    final controller = _controllers[tabId];
    if (tab == null || controller == null || tab.isBinary || tab.isSettings) {
      return;
    }

    final target = targetNameOrPath ?? tab.filePath ?? tab.fileName;
    try {
      final result = await _codeFormatService.format(
        fileNameOrPath: target,
        source: controller.text,
      );
      if (result.supported && result.changed && result.formattedText != null) {
        controller.text = result.formattedText!;
      }
    } catch (_) {}
  }

  bool _looksLikeGbk(List<int> bytes) {
    int i = 0;
    int dbCount = 0;
    while (i < bytes.length) {
      final b = bytes[i];
      if (b <= 0x7F) {
        i++;
      } else if (b >= 0x81 && b <= 0xFE && i + 1 < bytes.length) {
        final b2 = bytes[i + 1];
        if ((b2 >= 0x40 && b2 <= 0x7E) || (b2 >= 0x80 && b2 <= 0xFE)) {
          dbCount++;
          i += 2;
        } else {
          return false;
        }
      } else {
        return false;
      }
    }
    return dbCount > 0;
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _hotExitSaveTimer?.cancel();
    _workspaceDiagnosticsTimer?.cancel();
    _workspaceProblemWatcherRefreshTimer?.cancel();
    for (final timer in _editedFileDiagnosticsDebounceTimers.values) {
      timer.cancel();
    }
    _editedFileDiagnosticsDebounceTimers.clear();
    for (final timer in _fileWatchDebounceTimers.values) {
      timer.cancel();
    }
    _fileWatchDebounceTimers.clear();
    for (final timer in _workspaceProblemDebounceTimers.values) {
      timer.cancel();
    }
    _workspaceProblemDebounceTimers.clear();
    for (final watcher in _fileWatchers.values) {
      watcher.cancel();
    }
    _fileWatchers.clear();
    for (final watcher in _workspaceProblemWatchers.values) {
      watcher.cancel();
    }
    _workspaceProblemWatchers.clear();
    _externalSyncController.close();
    for (final entry in _diagnosticListeners.entries) {
      final controller = _controllers[entry.key];
      if (controller != null) {
        controller.diagnosticsNotifier.removeListener(entry.value);
      }
    }
    _diagnosticListeners.clear();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final c in _lspWarmupControllers.values) {
      c.dispose();
    }
    _disposePrimaryLspServers();
    for (final entry in _workspaceDiagnosticListeners.entries) {
      final controller = _workspaceDiagnosticControllers[entry.key];
      if (controller != null) {
        controller.diagnosticsNotifier.removeListener(entry.value);
      }
    }
    _workspaceDiagnosticListeners.clear();
    for (final c in _workspaceDiagnosticControllers.values) {
      c.dispose();
    }
    _workspaceDiagnosticsByPath.clear();
    _transientLspRuntimeByLanguage.clear();
    _workspacePlannedLspLanguages.clear();
    _diagnosticJumpIndexByScope.clear();
    _controllers.clear();
    for (final c in _findControllers.values) {
      c.dispose();
    }
    _findControllers.clear();
    _readOnlyTabs.clear();
    _snapshotSourcePaths.clear();
    _diffLinesByTab.clear();
    _editedTabs.clear();
    super.dispose();
  }
}

final editorAreaProvider =
    StateNotifierProvider<EditorAreaNotifier, EditorAreaState>(
      (ref) => EditorAreaNotifier(ref: ref),
    );
