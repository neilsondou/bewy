import 'dart:io';

import 'package:bewy/core/services/workspace_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = WorkspaceSearchService();

  group('WorkspaceSearchService', () {
    test('search finds matches across files', () async {
      final temp = await Directory.systemTemp.createTemp('bewy_search_');
      addTearDown(() => temp.delete(recursive: true));

      final a = File('${temp.path}\\a.txt');
      final b = File('${temp.path}\\b.txt');
      await a.writeAsString('hello bewy\nanother bewy line');
      await b.writeAsString('nothing\nbewy here');

      final progress = <WorkspaceSearchProgress>[];
      final result = await service.search(
        rootPath: temp.path,
        query: 'bewy',
        onProgress: progress.add,
      );

      expect(result.scannedFiles, 2);
      expect(result.matches.length, 3);
      expect(progress.isNotEmpty, isTrue);
      expect(progress.last.processedFiles, progress.last.totalFiles);
    });

    test('replaceAll replaces query and reports counts', () async {
      final temp = await Directory.systemTemp.createTemp('bewy_replace_');
      addTearDown(() => temp.delete(recursive: true));

      final file = File('${temp.path}\\a.txt');
      await file.writeAsString('old old old');

      final result = await service.replaceAll(
        rootPath: temp.path,
        query: 'old',
        replacement: 'new',
      );

      expect(result.scannedFiles, 1);
      expect(result.changedFiles, 1);
      expect(result.replacements, 3);
      expect(await file.readAsString(), 'new new new');
    });
  });
}
