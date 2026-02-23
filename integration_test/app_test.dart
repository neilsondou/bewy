import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bewy/app.dart';
import 'package:bewy/features/editor_area/presentation/editor_area_provider.dart';
import 'package:bewy/features/file_explorer/presentation/file_explorer_provider.dart';
import 'package:bewy/features/status_bar/presentation/status_info_provider.dart';

/// Helper to get providers from the running app.
ProviderContainer? _container;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('bewy_integration_');
    // Create sample project structure.
    await File('${tmpDir.path}${Platform.pathSeparator}main.dart')
        .writeAsString('void main() {\n  print("hello");\n}\n');
    await File('${tmpDir.path}${Platform.pathSeparator}readme.md')
        .writeAsString('# Readme\n');
    final srcDir =
        await Directory('${tmpDir.path}${Platform.pathSeparator}src').create();
    await File('${srcDir.path}${Platform.pathSeparator}app.dart')
        .writeAsString('class App {}\n');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  // ── 1. Welcome page ────────────────────────────────────────────────
  testWidgets('T01: Welcome page shows when no tabs are open', (tester) async {
    _container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container!,
        child: const BewyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Welcome tab should be visible when no files are open.
    expect(find.text('Bewy'), findsWidgets); // title bar + welcome
    // No tab bar items should exist.
    final editorState = _container!.read(editorAreaProvider);
    expect(editorState.tabGroup.tabs, isEmpty);
  });

  // ── 2. New untitled file ───────────────────────────────────────────
  testWidgets('T02: Ctrl+N creates a new untitled tab', (tester) async {
    _container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container!,
        child: const BewyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Simulate Ctrl+N.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    final state = _container!.read(editorAreaProvider);
    expect(state.tabGroup.tabs.length, 1);
    expect(state.tabGroup.tabs.first.fileName, 'Untitled-1');
    expect(state.tabGroup.tabs.first.isUntitled, isTrue);
  });

  // ── 3. Open folder and file tree ───────────────────────────────────
  testWidgets('T03: Open folder populates file explorer', (tester) async {
    _container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container!,
        child: const BewyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Open folder programmatically.
    await _container!.read(fileExplorerProvider.notifier).openFolder(tmpDir.path);
    await tester.pumpAndSettle();

    final explorerState = _container!.read(fileExplorerProvider);
    expect(explorerState.rootPath, tmpDir.path);
    expect(explorerState.rootNodes, isNotEmpty);

    final names = explorerState.rootNodes.map((n) => n.name).toSet();
    expect(names, contains('main.dart'));
    expect(names, contains('readme.md'));
    expect(names, contains('src'));
  });

  // ── 4. Open file creates tab ───────────────────────────────────────
  testWidgets('T04: Opening a file creates a tab with correct content',
      (tester) async {
    _container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container!,
        child: const BewyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final filePath = '${tmpDir.path}${Platform.pathSeparator}main.dart';
    await _container!
        .read(editorAreaProvider.notifier)
        .openTab('main.dart', filePath);
    await tester.pumpAndSettle();

    final state = _container!.read(editorAreaProvider);
    expect(state.tabGroup.tabs.length, 1);
    expect(state.tabGroup.tabs.first.fileName, 'main.dart');

    final controller = _container!
        .read(editorAreaProvider.notifier)
        .getController(state.tabGroup.tabs.first.id);
    expect(controller, isNotNull);
    expect(controller!.text, contains('void main()'));
  });

  // ── 5. Modification detection ──────────────────────────────────────
  testWidgets('T05: Editing file content marks tab as modified',
      (tester) async {
    _container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container!,
        child: const BewyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final filePath = '${tmpDir.path}${Platform.pathSeparator}main.dart';
    await _container!
        .read(editorAreaProvider.notifier)
        .openTab('main.dart', filePath);
    await tester.pumpAndSettle();

    final notifier = _container!.read(editorAreaProvider.notifier);
    final id = _container!.read(editorAreaProvider).tabGroup.tabs.first.id;

    // Initially not modified.
    expect(notifier.isModified(id), isFalse);

    // Simulate edit.
    notifier.getController(id)!.text = 'modified content';
    notifier.notifyContentChanged(id);
    await tester.pumpAndSettle();

    expect(notifier.isModified(id), isTrue);
    expect(notifier.hasUnsavedChanges(), isTrue);
  });

  // ── 6. Save clears modification ────────────────────────────────────
  testWidgets('T06: Saving file clears modification state', (tester) async {
    _container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container!,
        child: const BewyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final filePath = '${tmpDir.path}${Platform.pathSeparator}main.dart';
    final notifier = _container!.read(editorAreaProvider.notifier);
    await notifier.openTab('main.dart', filePath);
    await tester.pumpAndSettle();

    final id = _container!.read(editorAreaProvider).tabGroup.tabs.first.id;
    notifier.getController(id)!.text = 'saved content';
    expect(notifier.isModified(id), isTrue);

    await notifier.saveTab(id);
    await tester.pumpAndSettle();

    expect(notifier.isModified(id), isFalse);
    expect(await File(filePath).readAsString(), 'saved content');
  });

  // ── 7. Tab switching ───────────────────────────────────────────────
  testWidgets('T07: Tab switching works correctly', (tester) async {
    _container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container!,
        child: const BewyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final notifier = _container!.read(editorAreaProvider.notifier);
    final f1 = '${tmpDir.path}${Platform.pathSeparator}main.dart';
    final f2 = '${tmpDir.path}${Platform.pathSeparator}readme.md';

    await notifier.openTab('main.dart', f1);
    await notifier.openTab('readme.md', f2);
    await tester.pumpAndSettle();

    final state = _container!.read(editorAreaProvider);
    expect(state.tabGroup.tabs.length, 2);

    // Active should be the last opened.
    final id2 = state.tabGroup.tabs[1].id;
    expect(state.tabGroup.activeTabId, id2);

    // Switch to first.
    notifier.activateTab(state.tabGroup.tabs[0].id);
    await tester.pumpAndSettle();
    expect(
      _container!.read(editorAreaProvider).tabGroup.activeTabId,
      state.tabGroup.tabs[0].id,
    );
  });

  // ── 8. Close tab ───────────────────────────────────────────────────
  testWidgets('T08: Closing an unmodified tab removes it', (tester) async {
    _container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container!,
        child: const BewyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final notifier = _container!.read(editorAreaProvider.notifier);
    notifier.createNewTab();
    notifier.createNewTab();
    await tester.pumpAndSettle();

    expect(_container!.read(editorAreaProvider).tabGroup.tabs.length, 2);

    final id1 = _container!.read(editorAreaProvider).tabGroup.tabs[0].id;
    notifier.closeTab(id1);
    await tester.pumpAndSettle();

    expect(_container!.read(editorAreaProvider).tabGroup.tabs.length, 1);
  });

  // ── 9. Status bar updates ──────────────────────────────────────────
  testWidgets('T09: Status bar shows language for opened file', (tester) async {
    _container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container!,
        child: const BewyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Initially no active editor.
    expect(_container!.read(statusInfoProvider).hasActiveEditor, isFalse);

    _container!.read(statusInfoProvider.notifier).update(
          line: 5,
          column: 10,
          language: 'Dart',
        );
    await tester.pumpAndSettle();

    final status = _container!.read(statusInfoProvider);
    expect(status.line, 5);
    expect(status.column, 10);
    expect(status.language, 'Dart');
    expect(status.hasActiveEditor, isTrue);
  });

  // ── 10. Close all tabs shows welcome ───────────────────────────────
  testWidgets('T10: Closing all tabs returns to welcome page', (tester) async {
    _container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container!,
        child: const BewyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final notifier = _container!.read(editorAreaProvider.notifier);
    notifier.createNewTab();
    notifier.createNewTab();
    await tester.pumpAndSettle();
    expect(_container!.read(editorAreaProvider).tabGroup.tabs.length, 2);

    notifier.closeAllTabs();
    await tester.pumpAndSettle();

    expect(_container!.read(editorAreaProvider).tabGroup.tabs, isEmpty);
    expect(_container!.read(editorAreaProvider).tabGroup.activeTabId, isNull);
  });

  // ── 11. File explorer: create, rename, delete ──────────────────────
  testWidgets('T11: File explorer CRUD operations', (tester) async {
    _container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container!,
        child: const BewyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final explorer = _container!.read(fileExplorerProvider.notifier);
    await explorer.openFolder(tmpDir.path);
    await tester.pumpAndSettle();

    // Create.
    await explorer.createFileInDir(tmpDir.path, 'new_test.txt');
    await tester.pumpAndSettle();
    expect(
      _container!
          .read(fileExplorerProvider)
          .rootNodes
          .any((n) => n.name == 'new_test.txt'),
      isTrue,
    );

    // Rename.
    await explorer.renameNode(
      '${tmpDir.path}${Platform.pathSeparator}new_test.txt',
      'renamed_test.txt',
    );
    await tester.pumpAndSettle();
    expect(
      _container!
          .read(fileExplorerProvider)
          .rootNodes
          .any((n) => n.name == 'renamed_test.txt'),
      isTrue,
    );

    // Delete.
    await explorer.deleteNode(
      '${tmpDir.path}${Platform.pathSeparator}renamed_test.txt',
    );
    await tester.pumpAndSettle();
    expect(
      _container!
          .read(fileExplorerProvider)
          .rootNodes
          .any((n) => n.name == 'renamed_test.txt'),
      isFalse,
    );
  });

  // ── 12. Full workflow: open -> edit -> save -> verify disk ──────────
  testWidgets('T12: Full edit-save workflow', (tester) async {
    _container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container!,
        child: const BewyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final editorNotifier = _container!.read(editorAreaProvider.notifier);
    final filePath = '${tmpDir.path}${Platform.pathSeparator}main.dart';

    // 1. Open file.
    await editorNotifier.openTab('main.dart', filePath);
    await tester.pumpAndSettle();
    final id = _container!.read(editorAreaProvider).tabGroup.tabs.first.id;

    // 2. Verify not modified.
    expect(editorNotifier.isModified(id), isFalse);

    // 3. Edit.
    editorNotifier.getController(id)!.text = 'void main() => run();';
    editorNotifier.notifyContentChanged(id);
    await tester.pumpAndSettle();
    expect(editorNotifier.isModified(id), isTrue);

    // 4. Save.
    await editorNotifier.saveTab(id);
    await tester.pumpAndSettle();
    expect(editorNotifier.isModified(id), isFalse);

    // 5. Verify on disk.
    final content = await File(filePath).readAsString();
    expect(content, 'void main() => run();');

    // 6. Further edit + revert to saved.
    editorNotifier.getController(id)!.text = 'something else';
    expect(editorNotifier.isModified(id), isTrue);
    editorNotifier.getController(id)!.text = 'void main() => run();';
    expect(editorNotifier.isModified(id), isFalse);
  });

  // ── 13. Multiple files: modification isolation ─────────────────────
  testWidgets('T13: Modification state is isolated per tab', (tester) async {
    _container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container!,
        child: const BewyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final notifier = _container!.read(editorAreaProvider.notifier);
    final f1 = '${tmpDir.path}${Platform.pathSeparator}main.dart';
    final f2 = '${tmpDir.path}${Platform.pathSeparator}readme.md';

    await notifier.openTab('main.dart', f1);
    await notifier.openTab('readme.md', f2);
    await tester.pumpAndSettle();

    final state = _container!.read(editorAreaProvider);
    final id1 = state.tabGroup.tabs[0].id;
    final id2 = state.tabGroup.tabs[1].id;

    // Edit only file 1.
    notifier.getController(id1)!.text = 'modified';
    expect(notifier.isModified(id1), isTrue);
    expect(notifier.isModified(id2), isFalse);

    // closeSavedTabs should keep only modified.
    notifier.closeSavedTabs();
    await tester.pumpAndSettle();

    final remaining = _container!.read(editorAreaProvider).tabGroup.tabs;
    expect(remaining.length, 1);
    expect(remaining.first.id, id1);
  });

  // ── 14. Duplicate open prevention ──────────────────────────────────
  testWidgets('T14: Opening same file twice reuses tab', (tester) async {
    _container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container!,
        child: const BewyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final notifier = _container!.read(editorAreaProvider.notifier);
    final filePath = '${tmpDir.path}${Platform.pathSeparator}main.dart';

    await notifier.openTab('main.dart', filePath);
    await notifier.openTab('main.dart', filePath);
    await tester.pumpAndSettle();

    expect(_container!.read(editorAreaProvider).tabGroup.tabs.length, 1);
  });

  // ── 15. Tab navigation cycle ───────────────────────────────────────
  testWidgets('T15: Tab navigation cycles correctly', (tester) async {
    _container = ProviderContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container!,
        child: const BewyApp(),
      ),
    );
    await tester.pumpAndSettle();

    final notifier = _container!.read(editorAreaProvider.notifier);
    notifier.createNewTab(); // 1
    notifier.createNewTab(); // 2
    notifier.createNewTab(); // 3
    await tester.pumpAndSettle();

    final ids =
        _container!.read(editorAreaProvider).tabGroup.tabs.map((t) => t.id).toList();

    // Active is 3.
    expect(_container!.read(editorAreaProvider).tabGroup.activeTabId, ids[2]);

    // Next -> wraps to 1.
    notifier.activateNextTab();
    expect(_container!.read(editorAreaProvider).tabGroup.activeTabId, ids[0]);

    // Previous -> wraps to 3.
    notifier.activatePreviousTab();
    expect(_container!.read(editorAreaProvider).tabGroup.activeTabId, ids[2]);

    // Previous -> 2.
    notifier.activatePreviousTab();
    expect(_container!.read(editorAreaProvider).tabGroup.activeTabId, ids[1]);
  });
}
