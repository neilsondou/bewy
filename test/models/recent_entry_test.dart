import 'package:flutter_test/flutter_test.dart';
import 'package:bewy/core/models/recent_entry.dart';

void main() {
  group('RecentEntry', () {
    test('toJson serializes all fields', () {
      final entry = RecentEntry(
        name: 'main.dart',
        path: '/home/user/project/main.dart',
        isFolder: false,
        lastOpened: DateTime(2025, 1, 15, 10, 30),
      );

      final json = entry.toJson();
      expect(json['name'], 'main.dart');
      expect(json['path'], '/home/user/project/main.dart');
      expect(json['isFolder'], false);
      expect(json['lastOpened'], '2025-01-15T10:30:00.000');
    });

    test('fromJson deserializes all fields', () {
      final json = {
        'name': 'project',
        'path': '/home/user/project',
        'isFolder': true,
        'lastOpened': '2025-01-15T10:30:00.000',
      };

      final entry = RecentEntry.fromJson(json);
      expect(entry.name, 'project');
      expect(entry.path, '/home/user/project');
      expect(entry.isFolder, true);
      expect(entry.lastOpened, DateTime(2025, 1, 15, 10, 30));
    });

    test('roundtrip toJson -> fromJson preserves data', () {
      final original = RecentEntry(
        name: 'test.txt',
        path: '/tmp/test.txt',
        isFolder: false,
        lastOpened: DateTime(2025, 6, 1, 12, 0, 0),
      );

      final restored = RecentEntry.fromJson(original.toJson());
      expect(restored.name, original.name);
      expect(restored.path, original.path);
      expect(restored.isFolder, original.isFolder);
      expect(restored.lastOpened, original.lastOpened);
    });

    test('fromJson handles folder entries', () {
      final json = {
        'name': 'src',
        'path': '/home/user/project/src',
        'isFolder': true,
        'lastOpened': '2025-03-20T08:00:00.000',
      };

      final entry = RecentEntry.fromJson(json);
      expect(entry.isFolder, true);
      expect(entry.name, 'src');
    });
  });
}
