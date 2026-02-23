import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/providers/app_boot_provider.dart';
import 'core/services/app_log_service.dart';
import 'core/services/tree_sitter_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogService.instance.initialize();
  TreeSitterService.instance.initialize();

  final bootData = await _resolveBootData();
  AppLogService.instance.info(
    'bootstrap',
    'app start window=${bootData.windowId} child=${bootData.isChildWindow}',
  );

  await windowManager.ensureInitialized();

  final windowOptions = WindowOptions(
    size:
        bootData.isChildWindow ? const Size(1120, 640) : const Size(1280, 720),
    minimumSize:
        bootData.isChildWindow ? const Size(700, 420) : const Size(800, 500),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    if (!bootData.isChildWindow) {
      await windowManager.focus();
    }
  });

  runApp(
    ProviderScope(
      overrides: [appBootProvider.overrideWithValue(bootData)],
      child: const BewyApp(),
    ),
  );
}

Future<AppBootData> _resolveBootData() async {
  try {
    final controller = await WindowController.fromCurrentEngine();
    final rawArgs = controller.arguments;
    Map<String, dynamic> args = const {};
    if (rawArgs.isNotEmpty) {
      final decoded = jsonDecode(rawArgs);
      if (decoded is Map) {
        args = Map<String, dynamic>.from(decoded);
      }
    }

    final isChildWindow = args['windowType'] == 'child';
    Map<String, dynamic>? initialTab;
    final rawInitialTab = args['initialTab'];
    if (rawInitialTab is Map) {
      initialTab = Map<String, dynamic>.from(rawInitialTab);
    }

    return AppBootData(
      windowId: controller.windowId,
      isChildWindow: isChildWindow,
      mainWindowId: args['mainWindowId'] as String?,
      initialTabPayload: initialTab,
    );
  } catch (_) {
    return const AppBootData(windowId: 'main', isChildWindow: false);
  }
}
