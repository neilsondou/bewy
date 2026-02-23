import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../features/editor_area/presentation/editor_area_provider.dart';
import '../services/app_log_service.dart';
import 'app_boot_provider.dart';
import 'timeline_provider.dart';

class MultiWindowState {
  const MultiWindowState({
    this.initialized = false,
    this.childWindowIds = const [],
  });

  final bool initialized;
  final List<String> childWindowIds;

  MultiWindowState copyWith({bool? initialized, List<String>? childWindowIds}) {
    return MultiWindowState(
      initialized: initialized ?? this.initialized,
      childWindowIds: childWindowIds ?? this.childWindowIds,
    );
  }
}

class MultiWindowNotifier extends StateNotifier<MultiWindowState> {
  MultiWindowNotifier(this.ref) : super(const MultiWindowState());

  final Ref ref;

  WindowController? _current;
  bool _forceClosingCurrentWindow = false;

  AppBootData get _boot => ref.read(appBootProvider);
  bool get isChildWindow => _boot.isChildWindow;
  bool get isForceClosingCurrentWindow => _forceClosingCurrentWindow;

  Future<void> ensureInitialized() async {
    if (state.initialized) return;
    _current = await WindowController.fromCurrentEngine();
    await _current!.setWindowMethodHandler(_handleWindowMethod);
    state = state.copyWith(initialized: true);
  }

  Future<dynamic> _handleWindowMethod(MethodCall call) async {
    switch (call.method) {
      case 'openTabTransfer':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final payload = Map<String, dynamic>.from(args['tab'] as Map);
        await ref
            .read(editorAreaProvider.notifier)
            .openTransferredTab(payload, activate: true);
        return true;
      case 'attachTabToMain':
        if (isChildWindow) return false;
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final payload = Map<String, dynamic>.from(args['tab'] as Map);
        await ref
            .read(editorAreaProvider.notifier)
            .openTransferredTab(payload, activate: true);
        return true;
      case 'closeTransferredTab':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final tabId = args['tabId'] as String?;
        if (tabId != null) {
          ref.read(editorAreaProvider.notifier).forceCloseTab(tabId);
        }
        return true;
      case 'activateTabByPath':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final filePath = args['filePath'] as String?;
        if (filePath == null) return false;
        final tabs = ref.read(editorAreaProvider).tabGroup.tabs;
        final match =
            tabs
                .where(
                  (t) =>
                      t.filePath != null && _isSamePath(t.filePath!, filePath),
                )
                .firstOrNull;
        if (match == null) return false;
        ref.read(editorAreaProvider.notifier).activateTab(match.id);
        try {
          await windowManager.show();
          await windowManager.focus();
        } catch (_) {}
        return true;
      case 'requestCloseWindow':
        unawaited(_hideCurrentWindow());
        return true;
      case 'listModifiedTabs':
        final tabs = ref.read(editorAreaProvider.notifier).getModifiedTabs();
        return tabs.map((t) => t.fileName).toList();
      case 'saveModifiedTabsForExit':
        final notifier = ref.read(editorAreaProvider.notifier);
        final modifiedTabs = notifier.getModifiedTabs();
        for (final tab in modifiedTabs) {
          final saved = await notifier.saveTab(tab.id);
          if (!saved) {
            return false;
          }
        }
        return true;
      case 'forceCloseWindow':
        unawaited(_terminateCurrentWindow());
        return true;
      case 'terminateWindow':
        unawaited(_terminateCurrentWindow());
        return true;
      case 'timelineAppend':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final payload = Map<String, dynamic>.from(args['event'] as Map);
        ref.read(timelineProvider.notifier).addFromPayload(payload);
        return true;
      default:
        return null;
    }
  }

  Future<void> publishTimelineEvent(Map<String, dynamic> payload) async {
    await ensureInitialized();
    if (isChildWindow) {
      final mainId = _boot.mainWindowId;
      if (mainId == null) return;
      try {
        await WindowController.fromWindowId(
          mainId,
        ).invokeMethod('timelineAppend', {'event': payload});
      } catch (_) {}
      return;
    }
    ref.read(timelineProvider.notifier).addFromPayload(payload);
  }

  Future<void> createChildWindow({Map<String, dynamic>? initialTab}) async {
    await ensureInitialized();
    if (isChildWindow) return;

    final args = jsonEncode({
      'windowType': 'child',
      'mainWindowId': _boot.windowId,
      if (initialTab != null) 'initialTab': initialTab,
    });
    final child = await WindowController.create(
      WindowConfiguration(arguments: args, hiddenAtLaunch: false),
    );
    await child.show();
    AppLogService.instance.info(
      'window',
      'createChildWindow id=${child.windowId} initialTab=${initialTab != null}',
    );
    state = state.copyWith(
      childWindowIds: [...state.childWindowIds, child.windowId],
    );
  }

  Future<void> closeAllChildWindows() async {
    await ensureInitialized();
    if (isChildWindow) return;

    final windows = await WindowController.getAll();
    final selfIds = <String>{
      _boot.windowId,
      if (_current != null) _current!.windowId,
    };
    final targetIds =
        windows
            .map((e) => e.windowId)
            .where((id) => !selfIds.contains(id))
            .toList();

    for (final id in targetIds) {
      await _requestCloseWithRetry(id);
    }
    AppLogService.instance.info(
      'window',
      'closeAllChildWindows count=${targetIds.length}',
    );

    state = state.copyWith(childWindowIds: const []);
  }

  Future<void> terminateAllChildWindows() async {
    await ensureInitialized();
    if (isChildWindow) return;

    final windows = await WindowController.getAll();
    final selfIds = <String>{
      _boot.windowId,
      if (_current != null) _current!.windowId,
    };
    final targetIds =
        windows
            .map((e) => e.windowId)
            .where((id) => !selfIds.contains(id))
            .toList();

    for (final id in targetIds) {
      await _terminateWindowById(id);
    }
    AppLogService.instance.info(
      'window',
      'terminateAllChildWindows count=${targetIds.length}',
    );
    state = state.copyWith(childWindowIds: const []);
  }

  Future<void> handleDetachedTab(String tabId) async {
    await ensureInitialized();
    final payload = ref
        .read(editorAreaProvider.notifier)
        .buildTabTransfer(tabId);
    if (payload == null) return;
    AppLogService.instance.info('window', 'handleDetachedTab tabId=$tabId');

    if (isChildWindow) {
      final mainId = _boot.mainWindowId;
      if (mainId == null) return;
      try {
        await WindowController.fromWindowId(
          mainId,
        ).invokeMethod('attachTabToMain', {'tab': payload});
        ref.read(editorAreaProvider.notifier).forceCloseTab(tabId);
        if (ref.read(editorAreaProvider).tabGroup.tabs.isEmpty) {
          unawaited(_hideCurrentWindow());
        }
      } catch (_) {}
      return;
    }

    await createChildWindow(initialTab: payload);
    ref.read(editorAreaProvider.notifier).forceCloseTab(tabId);
  }

  Future<bool> focusChildWindowForFile(String filePath) async {
    await ensureInitialized();
    if (isChildWindow) return false;
    final windows = await WindowController.getAll();
    final selfIds = <String>{
      _boot.windowId,
      if (_current != null) _current!.windowId,
    };
    final targetIds =
        windows
            .map((e) => e.windowId)
            .where((id) => !selfIds.contains(id))
            .toList();

    for (final id in targetIds) {
      try {
        final controller = WindowController.fromWindowId(id);
        final result = await controller
            .invokeMethod('activateTabByPath', {'filePath': filePath})
            .timeout(const Duration(milliseconds: 450));
        if (result == true) return true;
      } catch (_) {}
    }
    return false;
  }

  Future<List<String>> collectUnsavedFileNamesFromChildren() async {
    await ensureInitialized();
    if (isChildWindow) return const [];
    final windows = await WindowController.getAll();
    final selfIds = <String>{
      _boot.windowId,
      if (_current != null) _current!.windowId,
    };
    final targetIds =
        windows
            .map((e) => e.windowId)
            .where((id) => !selfIds.contains(id))
            .toList();

    final unsaved = <String>[];
    for (final id in targetIds) {
      try {
        final controller = WindowController.fromWindowId(id);
        final result = await controller
            .invokeMethod('listModifiedTabs')
            .timeout(const Duration(milliseconds: 500));
        if (result is List) {
          for (final item in result) {
            if (item is String && item.trim().isNotEmpty) {
              unsaved.add(item);
            }
          }
        }
      } catch (_) {}
    }
    return unsaved;
  }

  Future<bool> saveUnsavedInChildren() async {
    await ensureInitialized();
    if (isChildWindow) return true;
    final windows = await WindowController.getAll();
    final selfIds = <String>{
      _boot.windowId,
      if (_current != null) _current!.windowId,
    };
    final targetIds =
        windows
            .map((e) => e.windowId)
            .where((id) => !selfIds.contains(id))
            .toList();

    for (final id in targetIds) {
      try {
        final controller = WindowController.fromWindowId(id);
        final saved = await controller
            .invokeMethod('saveModifiedTabsForExit')
            .timeout(const Duration(seconds: 30));
        if (saved != true) {
          return false;
        }
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  Future<void> _requestCloseWithRetry(String id) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final controller = WindowController.fromWindowId(id);
        await controller.hide().timeout(const Duration(milliseconds: 800));
        return;
      } catch (_) {
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
      }
    }
  }

  Future<void> hideCurrentWindow() async {
    await _hideCurrentWindow();
  }

  Future<void> _hideCurrentWindow() async {
    try {
      await windowManager.hide();
      AppLogService.instance.info('window', 'hideCurrentWindow');
    } catch (_) {}
  }

  Future<void> _terminateCurrentWindow() async {
    _forceClosingCurrentWindow = true;
    try {
      await windowManager.setPreventClose(false);
      await windowManager.close();
      unawaited(
        Future<void>.delayed(const Duration(seconds: 2), () {
          _forceClosingCurrentWindow = false;
        }),
      );
    } catch (_) {
      _forceClosingCurrentWindow = false;
    }
  }

  Future<void> _terminateWindowById(String id) async {
    final controller = WindowController.fromWindowId(id);
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await controller
            .invokeMethod('terminateWindow')
            .timeout(const Duration(milliseconds: 400));
        return;
      } catch (_) {
        try {
          await controller
              .invokeMethod('forceCloseWindow')
              .timeout(const Duration(milliseconds: 300));
          return;
        } catch (_) {
          try {
            await controller.hide().timeout(const Duration(milliseconds: 200));
          } catch (_) {}
          if (attempt == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 80));
          }
        }
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool _isSamePath(String a, String b) {
    if (Platform.isWindows) {
      return a.toLowerCase() == b.toLowerCase();
    }
    return a == b;
  }
}

final multiWindowProvider =
    StateNotifierProvider<MultiWindowNotifier, MultiWindowState>(
      (ref) => MultiWindowNotifier(ref),
    );
