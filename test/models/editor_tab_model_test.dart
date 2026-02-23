import 'package:flutter_test/flutter_test.dart';
import 'package:bewy/features/editor_area/models/editor_tab_model.dart';

void main() {
  group('EditorTabModel', () {
    test('isUntitled returns true when filePath is null', () {
      const tab = EditorTabModel(id: '1', fileName: 'Untitled-1');
      expect(tab.isUntitled, isTrue);
    });

    test('isUntitled returns false when filePath is set', () {
      const tab = EditorTabModel(
        id: '1',
        fileName: 'main.dart',
        filePath: '/tmp/main.dart',
      );
      expect(tab.isUntitled, isFalse);
    });

    test('copyWith preserves original values when no args given', () {
      const original = EditorTabModel(
        id: '1',
        fileName: 'main.dart',
        filePath: '/tmp/main.dart',
      );
      final copy = original.copyWith();
      expect(copy.id, '1');
      expect(copy.fileName, 'main.dart');
      expect(copy.filePath, '/tmp/main.dart');
    });

    test('copyWith overrides specified fields', () {
      const original = EditorTabModel(
        id: '1',
        fileName: 'main.dart',
        filePath: '/tmp/main.dart',
      );
      final copy = original.copyWith(
        fileName: 'app.dart',
        filePath: '/tmp/app.dart',
      );
      expect(copy.id, '1');
      expect(copy.fileName, 'app.dart');
      expect(copy.filePath, '/tmp/app.dart');
    });

    test('copyWith clearFilePath sets filePath to null', () {
      const original = EditorTabModel(
        id: '1',
        fileName: 'main.dart',
        filePath: '/tmp/main.dart',
      );
      final copy = original.copyWith(clearFilePath: true);
      expect(copy.filePath, isNull);
      expect(copy.isUntitled, isTrue);
    });

    // ── isPinned tests ───────────────────────────────────────────────────
    test('isPinned defaults to false', () {
      const tab = EditorTabModel(id: '1', fileName: 'Untitled-1');
      expect(tab.isPinned, isFalse);
    });

    test('isPinned can be set in constructor', () {
      const tab = EditorTabModel(
        id: '1',
        fileName: 'main.dart',
        isPinned: true,
      );
      expect(tab.isPinned, isTrue);
    });

    test('copyWith can change isPinned', () {
      const original = EditorTabModel(
        id: '1',
        fileName: 'main.dart',
        isPinned: false,
      );
      final pinned = original.copyWith(isPinned: true);
      expect(pinned.isPinned, isTrue);
      expect(pinned.fileName, 'main.dart');
    });

    test('copyWith preserves isPinned when not specified', () {
      const original = EditorTabModel(
        id: '1',
        fileName: 'main.dart',
        isPinned: true,
      );
      final copy = original.copyWith(fileName: 'other.dart');
      expect(copy.isPinned, isTrue);
    });

    test('settings tab is not untitled', () {
      const tab = EditorTabModel(
        id: '1',
        fileName: 'Settings',
        settingsSection: 'general',
      );
      expect(tab.isSettings, isTrue);
      expect(tab.isUntitled, isFalse);
    });

    test('copyWith can update settings section', () {
      const tab = EditorTabModel(
        id: '1',
        fileName: 'Settings',
        settingsSection: 'general',
      );
      final copy = tab.copyWith(settingsSection: 'shortcuts');
      expect(copy.settingsSection, 'shortcuts');
    });
  });
}
