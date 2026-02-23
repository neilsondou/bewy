import 'dart:io';

import 'package:bewy/features/editor_area/presentation/editor_area_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-window interaction scenarios', () {
    late EditorAreaNotifier mainEditor;
    late EditorAreaNotifier childEditor;

    setUp(() {
      mainEditor = EditorAreaNotifier();
      childEditor = EditorAreaNotifier();
      print('[setup] created main + child editor notifiers');
    });

    tearDown(() {
      mainEditor.dispose();
      childEditor.dispose();
      print('[teardown] disposed main + child editor notifiers');
    });

    test('roundtrip transfer keeps content and modified status', () async {
      final tmpDir = await Directory.systemTemp.createTemp('bewy_multi_');
      try {
        final file = File('${tmpDir.path}${Platform.pathSeparator}a.dart');
        await file.writeAsString('void main() {}');

        print('[main] open file');
        await mainEditor.openTab('a.dart', file.path);
        final mainTabId = mainEditor.state.tabGroup.tabs.single.id;

        print('[main] edit content and build transfer payload');
        mainEditor.getController(mainTabId)!.text = 'void main(){print(1);}';
        final toChild = mainEditor.buildTabTransfer(mainTabId)!;

        print('[child] open transferred tab');
        await childEditor.openTransferredTab(toChild, activate: true);
        final childTabId = childEditor.state.tabGroup.tabs.single.id;
        mainEditor.forceCloseTab(mainTabId);

        expect(childEditor.getController(childTabId)!.text, 'void main(){print(1);}');
        expect(childEditor.isModified(childTabId), isTrue);

        print('[child] edit again and transfer back to main');
        childEditor.getController(childTabId)!.text = 'void main(){print(2);}';
        final toMain = childEditor.buildTabTransfer(childTabId)!;
        await mainEditor.openTransferredTab(toMain, activate: true);
        childEditor.forceCloseTab(childTabId);

        final returned = mainEditor.state.tabGroup.tabs.single;
        expect(mainEditor.getController(returned.id)!.text, 'void main(){print(2);}');
        expect(mainEditor.isModified(returned.id), isTrue);
        expect(mainEditor.hasUnsavedChanges(), isTrue);
      } finally {
        await tmpDir.delete(recursive: true);
      }
    });

    test('transfer to existing tab does not duplicate and overwrites content', () async {
      final tmpDir = await Directory.systemTemp.createTemp('bewy_multi_');
      try {
        final file = File('${tmpDir.path}${Platform.pathSeparator}b.dart');
        await file.writeAsString('base');

        await mainEditor.openTab('b.dart', file.path);
        final existingId = mainEditor.state.tabGroup.tabs.single.id;
        mainEditor.getController(existingId)!.text = 'local-main';
        expect(mainEditor.isModified(existingId), isTrue);

        final payload = <String, dynamic>{
          'fileName': 'b.dart',
          'filePath': file.path,
          'isBinary': false,
          'content': 'from-child',
          'savedContent': 'base',
          'isModified': true,
        };

        print('[main] apply transferred payload to existing tab');
        await mainEditor.openTransferredTab(payload, activate: true);

        final tabs = mainEditor.state.tabGroup.tabs;
        expect(tabs.length, 1);
        expect(tabs.single.id, existingId);
        expect(mainEditor.getController(existingId)!.text, 'from-child');
        expect(mainEditor.isModified(existingId), isTrue);
      } finally {
        await tmpDir.delete(recursive: true);
      }
    });

    test('transfer can convert existing binary tab to editable text tab', () async {
      final tmpDir = await Directory.systemTemp.createTemp('bewy_multi_');
      try {
        final zip = File('${tmpDir.path}${Platform.pathSeparator}archive.zip');
        await zip.writeAsString('placeholder');

        await mainEditor.openTab('archive.zip', zip.path);
        final tab = mainEditor.state.tabGroup.tabs.single;
        expect(tab.isBinary, isTrue);
        expect(mainEditor.getController(tab.id), isNull);

        print('[main] receive transferred text payload for existing binary tab');
        await mainEditor.openTransferredTab({
          'fileName': 'archive.zip',
          'filePath': zip.path,
          'isBinary': false,
          'content': 'opened as text',
          'savedContent': '',
          'isModified': true,
        });

        final updated = mainEditor.state.tabGroup.tabs.single;
        expect(updated.isBinary, isFalse);
        expect(mainEditor.getController(updated.id), isNotNull);
        expect(mainEditor.getController(updated.id)!.text, 'opened as text');
      } finally {
        await tmpDir.delete(recursive: true);
      }
    });

    test('transfer can convert existing text tab to binary tab', () async {
      final tmpDir = await Directory.systemTemp.createTemp('bewy_multi_');
      try {
        final file = File('${tmpDir.path}${Platform.pathSeparator}note.txt');
        await file.writeAsString('hello');

        await mainEditor.openTab('note.txt', file.path);
        final tab = mainEditor.state.tabGroup.tabs.single;
        expect(tab.isBinary, isFalse);
        expect(mainEditor.getController(tab.id), isNotNull);

        print('[main] receive transferred binary payload for existing text tab');
        await mainEditor.openTransferredTab({
          'fileName': 'note.txt',
          'filePath': file.path,
          'isBinary': true,
        });

        final updated = mainEditor.state.tabGroup.tabs.single;
        expect(updated.isBinary, isTrue);
        expect(mainEditor.getController(updated.id), isNull);
      } finally {
        await tmpDir.delete(recursive: true);
      }
    });
  });
}

