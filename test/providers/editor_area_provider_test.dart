import 'dart:async';
import 'dart:io';
import 'package:charset/charset.dart' as charset;
import 'package:bewy/features/editor_area/presentation/editor_settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bewy/features/editor_area/presentation/editor_area_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EditorAreaNotifier notifier;

  setUp(() {
    notifier = EditorAreaNotifier();
  });

  tearDown(() {
    notifier.dispose();
  });

  // ── Initial state ───────────────────────────────────────────────────
  group('Initial state', () {
    test('has no tabs and no active tab', () {
      expect(notifier.state.tabGroup.tabs, isEmpty);
      expect(notifier.state.tabGroup.activeTabId, isNull);
    });

    test('hasUnsavedChanges is false', () {
      expect(notifier.hasUnsavedChanges(), isFalse);
    });

    test('getModifiedTabs returns empty', () {
      expect(notifier.getModifiedTabs(), isEmpty);
    });
  });

  // ── createNewTab ────────────────────────────────────────────────────
  group('createNewTab', () {
    test('creates one untitled tab', () {
      notifier.createNewTab();
      expect(notifier.state.tabGroup.tabs.length, 1);
      final tab = notifier.state.tabGroup.tabs.first;
      expect(tab.fileName, 'Untitled-1');
      expect(tab.isUntitled, isTrue);
      expect(notifier.state.tabGroup.activeTabId, tab.id);
    });

    test('increments untitled counter', () {
      notifier.createNewTab();
      notifier.createNewTab();
      expect(notifier.state.tabGroup.tabs.length, 2);
      expect(notifier.state.tabGroup.tabs[0].fileName, 'Untitled-1');
      expect(notifier.state.tabGroup.tabs[1].fileName, 'Untitled-2');
    });

    test('new tab becomes active', () {
      notifier.createNewTab();
      final firstId = notifier.state.tabGroup.activeTabId;
      notifier.createNewTab();
      final secondId = notifier.state.tabGroup.activeTabId;
      expect(secondId, isNot(firstId));
    });

    test('controller is created for new tab', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.tabs.first.id;
      expect(notifier.getController(id), isNotNull);
    });

    test('new tab content is empty', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.tabs.first.id;
      expect(notifier.getController(id)!.text, isEmpty);
    });

    test('new tab is NOT modified', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.tabs.first.id;
      expect(notifier.isModified(id), isFalse);
    });
  });

  group('openSettingsTab', () {
    test('creates a settings tab and activates it', () {
      notifier.openSettingsTab(title: 'Settings', section: 'general');

      expect(notifier.state.tabGroup.tabs.length, 1);
      final tab = notifier.state.tabGroup.tabs.single;
      expect(tab.isSettings, isTrue);
      expect(tab.settingsSection, 'general');
      expect(notifier.state.tabGroup.activeTabId, tab.id);
    });

    test('reuses existing settings tab and switches section', () {
      notifier.openSettingsTab(title: 'Settings', section: 'general');
      final originalId = notifier.state.tabGroup.tabs.single.id;

      notifier.openSettingsTab(title: 'Settings', section: 'shortcuts');

      expect(notifier.state.tabGroup.tabs.length, 1);
      final tab = notifier.state.tabGroup.tabs.single;
      expect(tab.id, originalId);
      expect(tab.settingsSection, 'shortcuts');
      expect(notifier.state.tabGroup.activeTabId, originalId);
    });
  });

  // ── openTab ─────────────────────────────────────────────────────────
  group('openTab', () {
    late Directory tmpDir;
    late File testFile;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('bewy_test_');
      testFile = File('${tmpDir.path}${Platform.pathSeparator}hello.dart');
      await testFile.writeAsString('void main() {}');
    });

    tearDown(() async {
      await tmpDir.delete(recursive: true);
    });

    test('opens a file and creates a tab', () async {
      await notifier.openTab('hello.dart', testFile.path);
      expect(notifier.state.tabGroup.tabs.length, 1);
      final tab = notifier.state.tabGroup.tabs.first;
      expect(tab.fileName, 'hello.dart');
      expect(tab.filePath, testFile.path);
      expect(tab.isUntitled, isFalse);
    });

    test('opened file content matches disk', () async {
      await notifier.openTab('hello.dart', testFile.path);
      final id = notifier.state.tabGroup.tabs.first.id;
      final controller = notifier.getController(id);
      expect(controller, isNotNull);
      expect(controller!.text, contains('void main()'));
    });

    test('opened file is NOT modified initially', () async {
      await notifier.openTab('hello.dart', testFile.path);
      final id = notifier.state.tabGroup.tabs.first.id;
      expect(notifier.isModified(id), isFalse);
    });

    test('opening same file twice reuses existing tab', () async {
      await notifier.openTab('hello.dart', testFile.path);
      await notifier.openTab('hello.dart', testFile.path);
      expect(notifier.state.tabGroup.tabs.length, 1);
    });

    test('opening same file activates existing tab', () async {
      await notifier.openTab('hello.dart', testFile.path);
      notifier.createNewTab(); // switches active
      expect(
        notifier.state.tabGroup.activeTabId,
        isNot(notifier.state.tabGroup.tabs.first.id),
      );
      await notifier.openTab('hello.dart', testFile.path);
      expect(
        notifier.state.tabGroup.activeTabId,
        notifier.state.tabGroup.tabs.first.id,
      );
    });

    test('opening an empty file creates an editable text tab', () async {
      final emptyFile = File(
        '${tmpDir.path}${Platform.pathSeparator}empty.txt',
      );
      await emptyFile.writeAsString('');

      await notifier.openTab('empty.txt', emptyFile.path);

      final tab = notifier.state.tabGroup.tabs.single;
      expect(tab.fileName, 'empty.txt');
      expect(tab.isBinary, isFalse);
      expect(notifier.getController(tab.id), isNotNull);
      expect(notifier.getController(tab.id)!.text, isEmpty);
    });

    test(
      'opening a .zip placeholder file is treated as binary by extension',
      () async {
        final zipFile = File(
          '${tmpDir.path}${Platform.pathSeparator}archive.zip',
        );
        await zipFile.writeAsString('(placeholder zip content)');

        await notifier.openTab('archive.zip', zipFile.path);

        final tab = notifier.state.tabGroup.tabs.single;
        expect(tab.fileName, 'archive.zip');
        expect(tab.isBinary, isTrue);
        expect(notifier.getController(tab.id), isNull);
      },
    );

    test(
      'opening an .exe placeholder file is treated as binary by extension',
      () async {
        final exeFile = File('${tmpDir.path}${Platform.pathSeparator}app.exe');
        await exeFile.writeAsString('(placeholder exe content)');

        await notifier.openTab('app.exe', exeFile.path);

        final tab = notifier.state.tabGroup.tabs.single;
        expect(tab.fileName, 'app.exe');
        expect(tab.isBinary, isTrue);
        expect(notifier.getController(tab.id), isNull);
      },
    );

    test('falls back to default encoding when UTF-8 detection fails', () async {
      final gbkFile = File(
        '${tmpDir.path}${Platform.pathSeparator}gbk_sample.txt',
      );
      final bytes = charset.gbk.encode('中文内容');
      await gbkFile.writeAsBytes(bytes);

      notifier.defaultFileEncoding = FileEncodingOption.gbk;
      await notifier.openTab('gbk_sample.txt', gbkFile.path);

      final tab = notifier.state.tabGroup.tabs.single;
      final text = notifier.getController(tab.id)!.text;
      expect(text, contains('中文'));
    });
  });

  // ── Modification detection ──────────────────────────────────────────
  group('Modification detection', () {
    test('editing content marks tab as modified', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.tabs.first.id;
      final controller = notifier.getController(id)!;

      controller.text = 'hello';
      expect(notifier.isModified(id), isTrue);
    });

    test('reverting content back to saved removes modified', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.tabs.first.id;
      final controller = notifier.getController(id)!;

      controller.text = 'hello';
      expect(notifier.isModified(id), isTrue);

      controller.text = '';
      expect(notifier.isModified(id), isFalse);
    });

    test('snapshotSavedContent updates baseline', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.tabs.first.id;
      final controller = notifier.getController(id)!;

      controller.text = 'new content';
      expect(notifier.isModified(id), isTrue);

      notifier.snapshotSavedContent(id);
      expect(notifier.isModified(id), isFalse);
    });

    test('notifyContentChanged triggers state rebuild on status change', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.tabs.first.id;
      final controller = notifier.getController(id)!;

      final statesBefore = notifier.state;
      controller.text = 'changed';
      notifier.notifyContentChanged(id);
      // State should have been rebuilt (new object).
      expect(identical(notifier.state, statesBefore), isFalse);
    });

    test('notifyContentChanged does not rebuild if status same', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.tabs.first.id;

      // Already not modified, calling notifyContentChanged should not rebuild.
      final stateBefore = notifier.state;
      notifier.notifyContentChanged(id);
      expect(identical(notifier.state, stateBefore), isTrue);
    });

    test('hasUnsavedChanges reflects modified tabs', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.tabs.first.id;
      expect(notifier.hasUnsavedChanges(), isFalse);

      notifier.getController(id)!.text = 'modified';
      expect(notifier.hasUnsavedChanges(), isTrue);
    });

    test('getModifiedTabs returns only modified tabs', () {
      notifier.createNewTab();
      notifier.createNewTab();
      final id1 = notifier.state.tabGroup.tabs[0].id;
      final id2 = notifier.state.tabGroup.tabs[1].id;

      notifier.getController(id1)!.text = 'modified';
      final modified = notifier.getModifiedTabs();
      expect(modified.length, 1);
      expect(modified.first.id, id1);
      expect(notifier.isModified(id2), isFalse);
    });
  });

  // ── closeTab ────────────────────────────────────────────────────────
  group('closeTab', () {
    test('removes tab from list', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.tabs.first.id;
      notifier.closeTab(id);
      expect(notifier.state.tabGroup.tabs, isEmpty);
    });

    test('disposes controller', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.tabs.first.id;
      notifier.closeTab(id);
      expect(notifier.getController(id), isNull);
    });

    test('closing active tab activates last remaining', () {
      notifier.createNewTab();
      notifier.createNewTab();
      final id1 = notifier.state.tabGroup.tabs[0].id;
      final id2 = notifier.state.tabGroup.tabs[1].id;
      notifier.activateTab(id2);

      notifier.closeTab(id2);
      expect(notifier.state.tabGroup.activeTabId, id1);
    });

    test('closing last tab sets activeTabId to null', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.tabs.first.id;
      notifier.closeTab(id);
      expect(notifier.state.tabGroup.activeTabId, isNull);
    });

    test('closing non-active tab preserves activeTabId', () {
      notifier.createNewTab();
      notifier.createNewTab();
      final id1 = notifier.state.tabGroup.tabs[0].id;
      final id2 = notifier.state.tabGroup.tabs[1].id;
      notifier.activateTab(id2);

      notifier.closeTab(id1);
      expect(notifier.state.tabGroup.activeTabId, id2);
      expect(notifier.state.tabGroup.tabs.length, 1);
    });

    test('closeTab skips pinned tabs', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.tabs.first.id;
      notifier.togglePinTab(id);

      notifier.closeTab(id);
      // Tab should still be there because it's pinned.
      expect(notifier.state.tabGroup.tabs.length, 1);
    });

    test('forceCloseTab removes pinned tabs', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.tabs.first.id;
      notifier.togglePinTab(id);

      notifier.forceCloseTab(id);
      expect(notifier.state.tabGroup.tabs, isEmpty);
    });
  });

  // ── Tab navigation ──────────────────────────────────────────────────
  group('Tab navigation', () {
    test('activateTab switches active tab', () {
      notifier.createNewTab();
      notifier.createNewTab();
      final id1 = notifier.state.tabGroup.tabs[0].id;
      notifier.activateTab(id1);
      expect(notifier.state.tabGroup.activeTabId, id1);
    });

    test('activateNextTab wraps around', () {
      notifier.createNewTab();
      notifier.createNewTab();
      notifier.createNewTab();
      final ids = notifier.state.tabGroup.tabs.map((t) => t.id).toList();
      notifier.activateTab(ids[2]); // last

      notifier.activateNextTab();
      expect(notifier.state.tabGroup.activeTabId, ids[0]); // wraps to first
    });

    test('activatePreviousTab wraps around', () {
      notifier.createNewTab();
      notifier.createNewTab();
      notifier.createNewTab();
      final ids = notifier.state.tabGroup.tabs.map((t) => t.id).toList();
      notifier.activateTab(ids[0]); // first

      notifier.activatePreviousTab();
      expect(notifier.state.tabGroup.activeTabId, ids[2]); // wraps to last
    });

    test('activateNextTab does nothing with single tab', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.activeTabId;
      notifier.activateNextTab();
      expect(notifier.state.tabGroup.activeTabId, id);
    });
  });

  // ── Bulk close operations ───────────────────────────────────────────
  group('Bulk close operations', () {
    test('closeOtherTabs keeps only specified tab', () {
      notifier.createNewTab();
      notifier.createNewTab();
      notifier.createNewTab();
      final id2 = notifier.state.tabGroup.tabs[1].id;

      notifier.closeOtherTabs(id2);
      expect(notifier.state.tabGroup.tabs.length, 1);
      expect(notifier.state.tabGroup.tabs.first.id, id2);
      expect(notifier.state.tabGroup.activeTabId, id2);
    });

    test('closeOtherTabs keeps pinned tabs', () {
      notifier.createNewTab(); // tab 1
      notifier.createNewTab(); // tab 2
      notifier.createNewTab(); // tab 3
      final id1 = notifier.state.tabGroup.tabs[0].id;
      final id2 = notifier.state.tabGroup.tabs[1].id;
      final id3 = notifier.state.tabGroup.tabs[2].id;

      // Pin tab 1.
      notifier.togglePinTab(id1);
      // Close others from tab 3 — should keep tab 3 and pinned tab 1.
      notifier.closeOtherTabs(id3);
      final remaining = notifier.state.tabGroup.tabs.map((t) => t.id).toSet();
      expect(remaining, contains(id1));
      expect(remaining, contains(id3));
      expect(remaining, isNot(contains(id2)));
    });

    test('closeAllTabs empties everything', () {
      notifier.createNewTab();
      notifier.createNewTab();
      notifier.closeAllTabs();
      expect(notifier.state.tabGroup.tabs, isEmpty);
      expect(notifier.state.tabGroup.activeTabId, isNull);
    });

    test('closeAllTabs keeps pinned tabs', () {
      notifier.createNewTab();
      notifier.createNewTab();
      final id1 = notifier.state.tabGroup.tabs[0].id;
      notifier.togglePinTab(id1);

      notifier.closeAllTabs();
      expect(notifier.state.tabGroup.tabs.length, 1);
      expect(notifier.state.tabGroup.tabs.first.id, id1);
    });

    test('closeSavedTabs keeps only modified tabs', () {
      notifier.createNewTab();
      notifier.createNewTab();
      notifier.createNewTab();
      final id2 = notifier.state.tabGroup.tabs[1].id;

      notifier.getController(id2)!.text = 'modified';
      notifier.closeSavedTabs();

      expect(notifier.state.tabGroup.tabs.length, 1);
      expect(notifier.state.tabGroup.tabs.first.id, id2);
    });

    test('closeSavedTabs keeps pinned tabs even if unmodified', () {
      notifier.createNewTab();
      notifier.createNewTab();
      final id1 = notifier.state.tabGroup.tabs[0].id;
      notifier.togglePinTab(id1);

      notifier.closeSavedTabs();
      // Pinned tab 1 stays even though it's not modified.
      expect(notifier.state.tabGroup.tabs.any((t) => t.id == id1), isTrue);
    });

    test('closeSavedTabs with all modified keeps everything', () {
      notifier.createNewTab();
      notifier.createNewTab();
      for (final tab in notifier.state.tabGroup.tabs) {
        notifier.getController(tab.id)!.text = 'modified_${tab.id}';
      }
      notifier.closeSavedTabs();
      expect(notifier.state.tabGroup.tabs.length, 2);
    });
  });

  // ── reorderTab ──────────────────────────────────────────────────────
  group('reorderTab', () {
    test('reorders tabs correctly', () {
      notifier.createNewTab(); // 0
      notifier.createNewTab(); // 1
      notifier.createNewTab(); // 2
      final ids = notifier.state.tabGroup.tabs.map((t) => t.id).toList();

      // Move tab 0 to position 2 (ReorderableListView convention: newIndex=2 means after index 1).
      notifier.reorderTab(0, 2);
      expect(notifier.state.tabGroup.tabs[0].id, ids[1]);
      expect(notifier.state.tabGroup.tabs[1].id, ids[0]);
      expect(notifier.state.tabGroup.tabs[2].id, ids[2]);
    });

    test('reorderTab does nothing for same index', () {
      notifier.createNewTab();
      notifier.createNewTab();
      final before = notifier.state.tabGroup.tabs.map((t) => t.id).toList();

      notifier.reorderTab(0, 0);
      final after = notifier.state.tabGroup.tabs.map((t) => t.id).toList();
      expect(after, before);
    });

    test('reorderTab respects pinned boundary', () {
      notifier.createNewTab(); // 0
      notifier.createNewTab(); // 1
      notifier.createNewTab(); // 2
      final id0 = notifier.state.tabGroup.tabs[0].id;
      notifier.togglePinTab(id0); // pin tab 0

      // Try to move unpinned tab 1 (index 1) to pinned zone (index 0).
      final before = notifier.state.tabGroup.tabs.map((t) => t.id).toList();
      notifier.reorderTab(1, 0);
      final after = notifier.state.tabGroup.tabs.map((t) => t.id).toList();
      expect(after, before); // Should not change.
    });
  });

  // ── togglePinTab ────────────────────────────────────────────────────
  group('togglePinTab', () {
    test('pins a tab and moves it to front', () {
      notifier.createNewTab(); // tab A
      notifier.createNewTab(); // tab B
      final idB = notifier.state.tabGroup.tabs[1].id;

      notifier.togglePinTab(idB);

      final pinnedTab = notifier.state.tabGroup.tabs.firstWhere(
        (t) => t.id == idB,
      );
      expect(pinnedTab.isPinned, isTrue);
      // Pinned tab should be at front.
      expect(notifier.state.tabGroup.tabs.first.id, idB);
    });

    test('unpins a tab and moves to start of unpinned group', () {
      notifier.createNewTab(); // A
      notifier.createNewTab(); // B
      notifier.createNewTab(); // C
      final idA = notifier.state.tabGroup.tabs[0].id;
      final idB = notifier.state.tabGroup.tabs[1].id;

      // Pin both A and B.
      notifier.togglePinTab(idA);
      notifier.togglePinTab(idB);

      // Unpin A.
      notifier.togglePinTab(idA);
      final tab = notifier.state.tabGroup.tabs.firstWhere((t) => t.id == idA);
      expect(tab.isPinned, isFalse);
      // B should still be at front (pinned).
      expect(notifier.state.tabGroup.tabs.first.id, idB);
    });

    test('toggle pin twice returns to unpinned', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.tabs.first.id;

      notifier.togglePinTab(id);
      expect(notifier.state.tabGroup.tabs.first.isPinned, isTrue);

      notifier.togglePinTab(id);
      expect(notifier.state.tabGroup.tabs.first.isPinned, isFalse);
    });
  });

  // ── Save ────────────────────────────────────────────────────────────
  group('saveTab', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('bewy_test_');
    });

    tearDown(() async {
      await tmpDir.delete(recursive: true);
    });

    test('saves content to disk and clears modified flag', () async {
      final filePath = '${tmpDir.path}${Platform.pathSeparator}test.dart';
      await File(filePath).writeAsString('original');

      await notifier.openTab('test.dart', filePath);
      final id = notifier.state.tabGroup.tabs.first.id;

      notifier.getController(id)!.text = 'updated content';
      expect(notifier.isModified(id), isTrue);

      await notifier.saveTab(id);
      expect(notifier.isModified(id), isFalse);

      final onDisk = await File(filePath).readAsString();
      expect(onDisk, 'updated content');
    });

    test('save updates savedContent baseline', () async {
      final filePath = '${tmpDir.path}${Platform.pathSeparator}test.dart';
      await File(filePath).writeAsString('original');

      await notifier.openTab('test.dart', filePath);
      final id = notifier.state.tabGroup.tabs.first.id;

      notifier.getController(id)!.text = 'v2';
      await notifier.saveTab(id);
      expect(notifier.isModified(id), isFalse);

      // Further edit from the saved "v2" baseline.
      notifier.getController(id)!.text = 'v3';
      expect(notifier.isModified(id), isTrue);

      // Revert to saved.
      notifier.getController(id)!.text = 'v2';
      expect(notifier.isModified(id), isFalse);
    });
  });

  group('Tab transfer', () {
    test('buildTabTransfer returns payload for editable tab', () {
      notifier.createNewTab();
      final id = notifier.state.tabGroup.tabs.first.id;
      notifier.getController(id)!.text = 'moved content';

      final payload = notifier.buildTabTransfer(id);
      expect(payload, isNotNull);
      expect(payload!['fileName'], 'Untitled-1');
      expect(payload['content'], 'moved content');
      expect(payload['isModified'], isTrue);
    });

    test('openTransferredTab restores content and modified state', () async {
      await notifier.openTransferredTab({
        'fileName': 'moved.dart',
        'filePath': null,
        'isBinary': false,
        'content': 'abc',
        'savedContent': '',
        'isModified': true,
      });

      expect(notifier.state.tabGroup.tabs.length, 1);
      final tab = notifier.state.tabGroup.tabs.first;
      expect(tab.fileName, 'moved.dart');
      expect(notifier.getController(tab.id)!.text, 'abc');
      expect(notifier.isModified(tab.id), isTrue);
    });

    test(
      'snapshotSavedContent does not clear transferred modified state',
      () async {
        await notifier.openTransferredTab({
          'fileName': 'moved.dart',
          'filePath': null,
          'isBinary': false,
          'content': 'abc_changed',
          'savedContent': 'abc_base',
          'isModified': true,
        });

        final tabId = notifier.state.tabGroup.tabs.first.id;
        expect(notifier.isModified(tabId), isTrue);

        notifier.snapshotSavedContent(tabId);
        expect(notifier.isModified(tabId), isTrue);
      },
    );
  });

  // ── Cross-feature interactions ──────────────────────────────────────
  group('Cross-feature interactions', () {
    test('create tab -> edit -> close others keeps modified tab', () {
      notifier.createNewTab(); // Untitled-1
      notifier.createNewTab(); // Untitled-2
      notifier.createNewTab(); // Untitled-3
      final id2 = notifier.state.tabGroup.tabs[1].id;
      notifier.getController(id2)!.text = 'important';

      final id1 = notifier.state.tabGroup.tabs[0].id;
      notifier.closeOtherTabs(id1);

      // id2 was closed (closeOthers keeps id1 only).
      expect(notifier.state.tabGroup.tabs.length, 1);
      expect(notifier.state.tabGroup.tabs.first.id, id1);
    });

    test('open file -> edit -> closeSavedTabs keeps modified file', () async {
      final tmpDir = await Directory.systemTemp.createTemp('bewy_test_');
      try {
        final f1 = File('${tmpDir.path}${Platform.pathSeparator}a.dart');
        final f2 = File('${tmpDir.path}${Platform.pathSeparator}b.dart');
        await f1.writeAsString('a');
        await f2.writeAsString('b');

        await notifier.openTab('a.dart', f1.path);
        await notifier.openTab('b.dart', f2.path);

        final idA = notifier.state.tabGroup.tabs[0].id;
        notifier.getController(idA)!.text = 'modified a';

        notifier.closeSavedTabs();
        expect(notifier.state.tabGroup.tabs.length, 1);
        expect(notifier.state.tabGroup.tabs.first.fileName, 'a.dart');
      } finally {
        await tmpDir.delete(recursive: true);
      }
    });

    test('switch tabs updates activeTabId correctly across operations', () {
      notifier.createNewTab(); // 1
      notifier.createNewTab(); // 2
      notifier.createNewTab(); // 3
      final ids = notifier.state.tabGroup.tabs.map((t) => t.id).toList();

      // Active is 3 (last created).
      expect(notifier.state.tabGroup.activeTabId, ids[2]);

      // Switch to 1.
      notifier.activateTab(ids[0]);
      expect(notifier.state.tabGroup.activeTabId, ids[0]);

      // Close 1 -> should activate next (2).
      notifier.closeTab(ids[0]);
      expect(notifier.state.tabGroup.activeTabId, ids[1]);

      // Next tab from 2 goes to 3.
      notifier.activateNextTab();
      expect(notifier.state.tabGroup.activeTabId, ids[2]);
    });

    test('modification state survives tab switching', () {
      notifier.createNewTab();
      notifier.createNewTab();
      final id1 = notifier.state.tabGroup.tabs[0].id;
      final id2 = notifier.state.tabGroup.tabs[1].id;

      notifier.getController(id1)!.text = 'modified';
      notifier.activateTab(id2);
      notifier.activateTab(id1);

      expect(notifier.isModified(id1), isTrue);
      expect(notifier.isModified(id2), isFalse);
    });
  });

  group('Hot Exit', () {
    test('restores unsaved content after simulated abnormal exit', () async {
      final tmpDir = await Directory.systemTemp.createTemp('bewy_hot_exit_');
      final snapshotPath =
          '${tmpDir.path}${Platform.pathSeparator}hot_exit_snapshot.json';
      final snapshotFile = File(snapshotPath);

      final writer = EditorAreaNotifier(
        hotExitEnabled: true,
        hotExitSnapshotPath: snapshotPath,
        allowHotExitInTests: true,
      );
      var writerDisposed = false;

      try {
        writer.createNewTab();
        final sourceTabId = writer.state.tabGroup.tabs.single.id;
        writer.getController(sourceTabId)!.text = 'unsaved crash content';
        writer.notifyContentChanged(sourceTabId);

        await Future<void>.delayed(const Duration(milliseconds: 350));
        expect(await snapshotFile.exists(), isTrue);

        // Simulate abnormal exit: dispose without explicit snapshot cleanup.
        writer.dispose();
        writerDisposed = true;

        final restorer = EditorAreaNotifier(
          hotExitEnabled: true,
          hotExitSnapshotPath: snapshotPath,
          allowHotExitInTests: true,
        );
        try {
          await restorer.restoreHotExitSnapshot();

          expect(restorer.state.tabGroup.tabs.length, 1);
          final restoredTab = restorer.state.tabGroup.tabs.single;
          expect(restorer.getController(restoredTab.id), isNotNull);
          expect(
            restorer.getController(restoredTab.id)!.text,
            'unsaved crash content',
          );
          expect(restorer.isModified(restoredTab.id), isTrue);
          expect(await snapshotFile.exists(), isFalse);
        } finally {
          restorer.dispose();
        }
      } finally {
        if (!writerDisposed) {
          writer.dispose();
        }
        if (await tmpDir.exists()) {
          await tmpDir.delete(recursive: true);
        }
      }
    });
  });
}
