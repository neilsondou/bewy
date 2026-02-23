import 'package:flutter_test/flutter_test.dart';
import 'package:bewy/features/editor_area/models/editor_tab_model.dart';
import 'package:bewy/features/editor_area/models/tab_group_model.dart';

void main() {
  group('TabGroupModel', () {
    test('default state has empty tabs and null activeTabId', () {
      const group = TabGroupModel();
      expect(group.tabs, isEmpty);
      expect(group.activeTabId, isNull);
    });

    test('copyWith overrides tabs', () {
      const group = TabGroupModel();
      final tabs = [
        const EditorTabModel(id: '1', fileName: 'a.dart'),
        const EditorTabModel(id: '2', fileName: 'b.dart'),
      ];
      final updated = group.copyWith(tabs: tabs, activeTabId: '1');
      expect(updated.tabs.length, 2);
      expect(updated.activeTabId, '1');
    });

    test('copyWith preserves fields when not specified', () {
      final original = TabGroupModel(
        tabs: const [EditorTabModel(id: '1', fileName: 'a.dart')],
        activeTabId: '1',
      );
      final copy = original.copyWith();
      expect(copy.tabs.length, 1);
      expect(copy.activeTabId, '1');
    });
  });
}
