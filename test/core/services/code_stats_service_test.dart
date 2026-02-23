import 'dart:io';

import 'package:bewy/core/services/code_stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CodeStatsService', () {
    test('analyzeWorkspace collects language and extension stats', () async {
      final dir = await Directory.systemTemp.createTemp('bewy_stats_test_');
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });

      final dartFile = File('${dir.path}${Platform.pathSeparator}a.dart');
      final tsFile = File('${dir.path}${Platform.pathSeparator}b.ts');
      final txtFile = File('${dir.path}${Platform.pathSeparator}readme.txt');
      await dartFile.writeAsString('void main() {\n  print("x");\n}\n');
      await tsFile.writeAsString('const a=1;\nconst b=2;\n');
      await txtFile.writeAsString('hello\nworld\n');

      final service = const CodeStatsService();
      final result = await service.analyzeWorkspace(rootPath: dir.path);

      expect(result.scannedFiles, 3);
      expect(result.totalLines, greaterThanOrEqualTo(7));
      expect(
        result.languageStats.any((e) => e.language == 'Dart' && e.files == 1),
        isTrue,
      );
      expect(
        result.extensionStats.any(
          (e) => e.extension == '.dart' && e.files == 1,
        ),
        isTrue,
      );
    });

    test('analyzeWorkspace supports extension filter', () async {
      final dir = await Directory.systemTemp.createTemp('bewy_stats_filter_');
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });

      await File(
        '${dir.path}${Platform.pathSeparator}a.dart',
      ).writeAsString('void main() {}\n');
      await File(
        '${dir.path}${Platform.pathSeparator}b.ts',
      ).writeAsString('const x=1;\n');

      final service = const CodeStatsService();
      final result = await service.analyzeWorkspace(
        rootPath: dir.path,
        includeExtensions: {'dart'},
      );

      expect(result.scannedFiles, 1);
      expect(result.extensionStats.length, 1);
      expect(result.extensionStats.first.extension, '.dart');
    });
  });
}
