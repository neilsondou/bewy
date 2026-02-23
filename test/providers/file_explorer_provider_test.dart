import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bewy/features/file_explorer/presentation/file_explorer_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FileExplorerNotifier notifier;
  late Directory tmpDir;

  setUp(() async {
    notifier = FileExplorerNotifier();
    tmpDir = await Directory.systemTemp.createTemp('bewy_explorer_test_');
  });

  tearDown(() async {
    notifier.dispose();
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  // ── Initial state ───────────────────────────────────────────────────
  group('Initial state', () {
    test('has no root nodes and no selected path', () {
      expect(notifier.state.rootNodes, isEmpty);
      expect(notifier.state.selectedPath, isNull);
      expect(notifier.state.rootPath, isNull);
    });

    test('filterQuery is empty initially', () {
      expect(notifier.state.filterQuery, isEmpty);
    });
  });

  // ── openFolder ──────────────────────────────────────────────────────
  group('openFolder', () {
    test('scans directory and populates rootNodes', () async {
      await File(
        '${tmpDir.path}${Platform.pathSeparator}hello.dart',
      ).writeAsString('void main() {}');
      await Directory('${tmpDir.path}${Platform.pathSeparator}src').create();

      await notifier.openFolder(tmpDir.path);
      expect(notifier.state.rootPath, tmpDir.path);
      expect(notifier.state.rootNodes, isNotEmpty);

      final names = notifier.state.rootNodes.map((n) => n.name).toList();
      expect(names, contains('hello.dart'));
      expect(names, contains('src'));
    });

    test('directories sort before files', () async {
      await File(
        '${tmpDir.path}${Platform.pathSeparator}z.txt',
      ).writeAsString('');
      await Directory('${tmpDir.path}${Platform.pathSeparator}a_dir').create();

      await notifier.openFolder(tmpDir.path);
      final first = notifier.state.rootNodes.first;
      expect(first.isDirectory, isTrue);
      expect(first.name, 'a_dir');
    });

    test('hidden files (dotfiles) are excluded except .gitignore', () async {
      await File(
        '${tmpDir.path}${Platform.pathSeparator}.hidden',
      ).writeAsString('');
      await File(
        '${tmpDir.path}${Platform.pathSeparator}.gitignore',
      ).writeAsString('');
      await File(
        '${tmpDir.path}${Platform.pathSeparator}visible.txt',
      ).writeAsString('');

      await notifier.openFolder(tmpDir.path);
      final names = notifier.state.rootNodes.map((n) => n.name).toSet();
      expect(names, contains('visible.txt'));
      expect(names, contains('.gitignore'));
      expect(names, isNot(contains('.hidden')));
    });
  });

  // ── selectFile ──────────────────────────────────────────────────────
  group('selectFile', () {
    test('sets selectedPath', () {
      notifier.selectFile('/some/path.dart');
      expect(notifier.state.selectedPath, '/some/path.dart');
    });
  });

  // ── refreshTree ─────────────────────────────────────────────────────
  group('refreshTree', () {
    test('picks up new files on disk', () async {
      await File(
        '${tmpDir.path}${Platform.pathSeparator}initial.txt',
      ).writeAsString('');
      await notifier.openFolder(tmpDir.path);
      expect(
        notifier.state.rootNodes.any((n) => n.name == 'initial.txt'),
        isTrue,
      );

      // Add a new file.
      await File(
        '${tmpDir.path}${Platform.pathSeparator}added.txt',
      ).writeAsString('new');
      await notifier.refreshTree();
      expect(
        notifier.state.rootNodes.any((n) => n.name == 'added.txt'),
        isTrue,
      );
    });

    test('does nothing if rootPath is null', () async {
      await notifier.refreshTree();
      expect(notifier.state.rootNodes, isEmpty);
    });
  });

  // ── createFileInDir ─────────────────────────────────────────────────
  group('createFileInDir', () {
    test('creates a file on disk and shows in tree', () async {
      await notifier.openFolder(tmpDir.path);
      await notifier.createFileInDir(tmpDir.path, 'new_file.txt');

      expect(
        await File(
          '${tmpDir.path}${Platform.pathSeparator}new_file.txt',
        ).exists(),
        isTrue,
      );
      expect(
        notifier.state.rootNodes.any((n) => n.name == 'new_file.txt'),
        isTrue,
      );
    });
  });

  // ── createSubFolder ─────────────────────────────────────────────────
  group('createSubFolder', () {
    test('creates a folder on disk and shows in tree', () async {
      await notifier.openFolder(tmpDir.path);
      await notifier.createSubFolder(tmpDir.path, 'new_folder');

      expect(
        await Directory(
          '${tmpDir.path}${Platform.pathSeparator}new_folder',
        ).exists(),
        isTrue,
      );
      expect(
        notifier.state.rootNodes.any(
          (n) => n.name == 'new_folder' && n.isDirectory,
        ),
        isTrue,
      );
    });
  });

  // ── renameNode ──────────────────────────────────────────────────────
  group('renameNode', () {
    test('renames a file on disk', () async {
      final oldPath = '${tmpDir.path}${Platform.pathSeparator}old.txt';
      await File(oldPath).writeAsString('data');
      await notifier.openFolder(tmpDir.path);

      await notifier.renameNode(oldPath, 'new.txt');

      expect(await File(oldPath).exists(), isFalse);
      expect(
        await File('${tmpDir.path}${Platform.pathSeparator}new.txt').exists(),
        isTrue,
      );
      expect(notifier.state.rootNodes.any((n) => n.name == 'new.txt'), isTrue);
    });
  });

  // ── deleteNode ──────────────────────────────────────────────────────
  group('deleteNode', () {
    test('deletes a file from disk', () async {
      final filePath = '${tmpDir.path}${Platform.pathSeparator}remove_me.txt';
      await File(filePath).writeAsString('bye');
      await notifier.openFolder(tmpDir.path);

      await notifier.deleteNode(filePath);

      expect(await File(filePath).exists(), isFalse);
      expect(
        notifier.state.rootNodes.any((n) => n.name == 'remove_me.txt'),
        isFalse,
      );
    });

    test('deletes a directory recursively', () async {
      final dirPath = '${tmpDir.path}${Platform.pathSeparator}remove_dir';
      await Directory(dirPath).create();
      await File(
        '$dirPath${Platform.pathSeparator}inner.txt',
      ).writeAsString('');

      await notifier.openFolder(tmpDir.path);
      await notifier.deleteNode(dirPath);

      expect(await Directory(dirPath).exists(), isFalse);
    });
  });

  // ── toggleExpand ────────────────────────────────────────────────────
  group('toggleExpand', () {
    test('expanding a directory sets isExpanded to true', () async {
      final subDir =
          await Directory(
            '${tmpDir.path}${Platform.pathSeparator}subdir',
          ).create();
      await File(
        '${subDir.path}${Platform.pathSeparator}child.txt',
      ).writeAsString('');

      await notifier.openFolder(tmpDir.path);
      final dirNode = notifier.state.rootNodes.firstWhere(
        (n) => n.name == 'subdir',
      );

      // Directories always start collapsed.
      expect(dirNode.isExpanded, isFalse);

      // Expand.
      notifier.toggleExpand(subDir.path);
      final expanded = notifier.state.rootNodes.firstWhere(
        (n) => n.name == 'subdir',
      );
      expect(expanded.isExpanded, isTrue);

      // Collapse.
      notifier.toggleExpand(subDir.path);
      final collapsed = notifier.state.rootNodes.firstWhere(
        (n) => n.name == 'subdir',
      );
      expect(collapsed.isExpanded, isFalse);
    });
  });

  // ── filterQuery ───────────────────────────────────────────────────
  group('filterQuery', () {
    test('setFilterQuery updates state', () {
      notifier.setFilterQuery('dart');
      expect(notifier.state.filterQuery, 'dart');
    });

    test('setFilterQuery with empty string clears filter', () {
      notifier.setFilterQuery('dart');
      notifier.setFilterQuery('');
      expect(notifier.state.filterQuery, isEmpty);
    });

    test('getFilteredNodes returns matching files', () async {
      await File(
        '${tmpDir.path}${Platform.pathSeparator}main.dart',
      ).writeAsString('');
      await File(
        '${tmpDir.path}${Platform.pathSeparator}test.txt',
      ).writeAsString('');
      await File(
        '${tmpDir.path}${Platform.pathSeparator}utils.dart',
      ).writeAsString('');

      await notifier.openFolder(tmpDir.path);
      notifier.setFilterQuery('dart');

      final filtered = notifier.getFilteredNodes();
      expect(filtered.length, 2);
      expect(filtered.every((n) => n.name.contains('dart')), isTrue);
    });

    test('getFilteredNodes is case insensitive', () async {
      await File(
        '${tmpDir.path}${Platform.pathSeparator}README.md',
      ).writeAsString('');

      await notifier.openFolder(tmpDir.path);
      notifier.setFilterQuery('readme');

      final filtered = notifier.getFilteredNodes();
      expect(filtered.length, 1);
      expect(filtered.first.name, 'README.md');
    });

    test('getFilteredNodes returns empty for no match', () async {
      await File(
        '${tmpDir.path}${Platform.pathSeparator}main.dart',
      ).writeAsString('');

      await notifier.openFolder(tmpDir.path);
      notifier.setFilterQuery('xyz');

      expect(notifier.getFilteredNodes(), isEmpty);
    });

    test('getFilteredNodes returns empty when query is empty', () async {
      await File(
        '${tmpDir.path}${Platform.pathSeparator}main.dart',
      ).writeAsString('');

      await notifier.openFolder(tmpDir.path);
      notifier.setFilterQuery('');

      expect(notifier.getFilteredNodes(), isEmpty);
    });
  });

  // ── moveNode ──────────────────────────────────────────────────────
  group('moveNode', () {
    test('moves a file to another directory', () async {
      final srcFile = File(
        '${tmpDir.path}${Platform.pathSeparator}move_me.txt',
      );
      await srcFile.writeAsString('data');
      final targetDir =
          await Directory(
            '${tmpDir.path}${Platform.pathSeparator}target',
          ).create();

      await notifier.openFolder(tmpDir.path);
      await notifier.moveNode(srcFile.path, targetDir.path);

      expect(await srcFile.exists(), isFalse);
      expect(
        await File(
          '${targetDir.path}${Platform.pathSeparator}move_me.txt',
        ).exists(),
        isTrue,
      );
    });

    test('prevents moving a node to itself', () async {
      final dir =
          await Directory(
            '${tmpDir.path}${Platform.pathSeparator}self_dir',
          ).create();

      await notifier.openFolder(tmpDir.path);
      await notifier.moveNode(dir.path, dir.path);

      // Directory should still exist at original location.
      expect(await dir.exists(), isTrue);
    });

    test('prevents moving a parent into its own child', () async {
      final parentDir =
          await Directory(
            '${tmpDir.path}${Platform.pathSeparator}parent',
          ).create();
      final childDir =
          await Directory(
            '${parentDir.path}${Platform.pathSeparator}child',
          ).create();

      await notifier.openFolder(tmpDir.path);
      await notifier.moveNode(parentDir.path, childDir.path);

      // Parent should still exist at original location.
      expect(await parentDir.exists(), isTrue);
    });
  });

  // ── Cross-feature: file ops -> tree sync ────────────────────────────
  group('Cross-feature: file operations refresh tree', () {
    test('create + rename + delete workflow', () async {
      await notifier.openFolder(tmpDir.path);

      // Create.
      await notifier.createFileInDir(tmpDir.path, 'workflow.txt');
      expect(
        notifier.state.rootNodes.any((n) => n.name == 'workflow.txt'),
        isTrue,
      );

      // Rename.
      final filePath = '${tmpDir.path}${Platform.pathSeparator}workflow.txt';
      await notifier.renameNode(filePath, 'renamed.txt');
      expect(
        notifier.state.rootNodes.any((n) => n.name == 'renamed.txt'),
        isTrue,
      );
      expect(
        notifier.state.rootNodes.any((n) => n.name == 'workflow.txt'),
        isFalse,
      );

      // Delete.
      final renamedPath = '${tmpDir.path}${Platform.pathSeparator}renamed.txt';
      await notifier.deleteNode(renamedPath);
      expect(
        notifier.state.rootNodes.any((n) => n.name == 'renamed.txt'),
        isFalse,
      );
    });
  });
}
