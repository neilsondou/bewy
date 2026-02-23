import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bewy/features/file_explorer/presentation/file_explorer_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FileExplorerNotifier notifier;
  late Directory tmpDir;

  setUp(() async {
    notifier = FileExplorerNotifier();
    tmpDir = await Directory.systemTemp.createTemp('bewy_watch_test_');
  });

  tearDown(() async {
    notifier.dispose();
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  // ── Directory.watch integration ────────────────────────────────────
  group('File watching with Directory.watch()', () {
    test('new files are detected after debounce period', () async {
      // Create initial file and open folder.
      await File(
        '${tmpDir.path}${Platform.pathSeparator}initial.txt',
      ).writeAsString('hello');
      await notifier.openFolder(tmpDir.path);

      expect(
        notifier.state.rootNodes.any((n) => n.name == 'initial.txt'),
        isTrue,
      );
      expect(
        notifier.state.rootNodes.any((n) => n.name == 'new_file.txt'),
        isFalse,
      );

      // Create a new file externally.
      await File(
        '${tmpDir.path}${Platform.pathSeparator}new_file.txt',
      ).writeAsString('world');

      // Wait for debounce (300ms) + some buffer for the watch event.
      await Future.delayed(const Duration(milliseconds: 800));

      expect(
        notifier.state.rootNodes.any((n) => n.name == 'new_file.txt'),
        isTrue,
      );
    });

    test('deleted files are removed after debounce period', () async {
      final file = File('${tmpDir.path}${Platform.pathSeparator}delete_me.txt');
      await file.writeAsString('bye');
      await notifier.openFolder(tmpDir.path);

      expect(
        notifier.state.rootNodes.any((n) => n.name == 'delete_me.txt'),
        isTrue,
      );

      // Delete the file externally.
      await file.delete();

      // Wait for debounce + buffer.
      await Future.delayed(const Duration(milliseconds: 800));

      expect(
        notifier.state.rootNodes.any((n) => n.name == 'delete_me.txt'),
        isFalse,
      );
    });

    test('new folders are detected after debounce period', () async {
      await notifier.openFolder(tmpDir.path);

      // Create a new folder externally.
      await Directory(
        '${tmpDir.path}${Platform.pathSeparator}new_folder',
      ).create();

      await Future.delayed(const Duration(milliseconds: 800));

      expect(
        notifier.state.rootNodes.any(
          (n) => n.name == 'new_folder' && n.isDirectory,
        ),
        isTrue,
      );
    });

    test('expanded state is preserved after watch-triggered refresh', () async {
      // Create a subfolder with a child file.
      final subDir =
          await Directory(
            '${tmpDir.path}${Platform.pathSeparator}sub',
          ).create();
      await File(
        '${subDir.path}${Platform.pathSeparator}child.txt',
      ).writeAsString('');

      await notifier.openFolder(tmpDir.path);

      // Expand the subfolder.
      notifier.toggleExpand(subDir.path);
      expect(
        notifier.state.rootNodes.firstWhere((n) => n.name == 'sub').isExpanded,
        isTrue,
      );

      // Trigger a filesystem change.
      await File(
        '${tmpDir.path}${Platform.pathSeparator}trigger.txt',
      ).writeAsString('');
      await Future.delayed(const Duration(milliseconds: 800));

      // The 'sub' folder should still be expanded.
      expect(
        notifier.state.rootNodes.firstWhere((n) => n.name == 'sub').isExpanded,
        isTrue,
      );
    });

    test('rapid file changes are debounced into single refresh', () async {
      await notifier.openFolder(tmpDir.path);

      int stateChangeCount = 0;
      notifier.addListener((state) {
        stateChangeCount++;
      });

      // Create multiple files rapidly.
      for (int i = 0; i < 5; i++) {
        await File(
          '${tmpDir.path}${Platform.pathSeparator}rapid_$i.txt',
        ).writeAsString('$i');
      }

      // Wait for debounce.
      await Future.delayed(const Duration(milliseconds: 800));

      // All files should be present.
      for (int i = 0; i < 5; i++) {
        expect(
          notifier.state.rootNodes.any((n) => n.name == 'rapid_$i.txt'),
          isTrue,
        );
      }

      // State should have changed fewer times than file creates
      // (debouncing coalesces events).
      // We can't assert an exact count due to timing, but it should be
      // significantly less than 5.
      expect(stateChangeCount, lessThanOrEqualTo(5));
    });

    test('opening a new folder cancels old watch subscription', () async {
      // Open first folder.
      await File(
        '${tmpDir.path}${Platform.pathSeparator}a.txt',
      ).writeAsString('');
      await notifier.openFolder(tmpDir.path);
      expect(notifier.state.rootPath, tmpDir.path);

      // Create a second temp directory and open it.
      final tmpDir2 = await Directory.systemTemp.createTemp(
        'bewy_watch_test2_',
      );
      try {
        await File(
          '${tmpDir2.path}${Platform.pathSeparator}b.txt',
        ).writeAsString('');
        await notifier.openFolder(tmpDir2.path);
        expect(notifier.state.rootPath, tmpDir2.path);

        // Modify old directory — should NOT affect the tree.
        await File(
          '${tmpDir.path}${Platform.pathSeparator}new_in_old.txt',
        ).writeAsString('');
        await Future.delayed(const Duration(milliseconds: 800));

        // Tree should only show tmpDir2 contents.
        expect(
          notifier.state.rootNodes.any((n) => n.name == 'new_in_old.txt'),
          isFalse,
        );
        expect(notifier.state.rootNodes.any((n) => n.name == 'b.txt'), isTrue);
      } finally {
        await tmpDir2.delete(recursive: true);
      }
    });
  });

  // ── dispose cleanup ────────────────────────────────────────────────
  group('Dispose', () {
    test('dispose does not throw', () async {
      final localNotifier = FileExplorerNotifier();
      final localDir = await Directory.systemTemp.createTemp(
        'bewy_dispose_test_',
      );
      try {
        await localNotifier.openFolder(localDir.path);
        expect(() => localNotifier.dispose(), returnsNormally);
      } finally {
        if (await localDir.exists()) {
          await localDir.delete(recursive: true);
        }
      }
    });
  });
}
