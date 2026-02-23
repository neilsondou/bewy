import 'package:flutter_test/flutter_test.dart';
import 'package:bewy/core/providers/recent_files_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecentFilesNotifier notifier;

  setUp(() {
    notifier = RecentFilesNotifier();
  });

  tearDown(() {
    notifier.dispose();
  });

  group('RecentFilesNotifier', () {
    test('initial state is empty', () {
      // State starts empty (disk load is async and may not have completed).
      // In tests without disk, it remains empty.
      expect(notifier.state, isEmpty);
    });

    test('addRecent adds entry to front of list', () {
      notifier.addRecent('test.dart', '/tmp/test.dart', false);
      expect(notifier.state.length, 1);
      expect(notifier.state.first.name, 'test.dart');
      expect(notifier.state.first.path, '/tmp/test.dart');
      expect(notifier.state.first.isFolder, false);
    });

    test('addRecent deduplicates by path', () {
      notifier.addRecent('test.dart', '/tmp/test.dart', false);
      notifier.addRecent('other.dart', '/tmp/other.dart', false);
      notifier.addRecent('test.dart', '/tmp/test.dart', false);

      expect(notifier.state.length, 2);
      // Most recently added should be first.
      expect(notifier.state.first.path, '/tmp/test.dart');
      expect(notifier.state[1].path, '/tmp/other.dart');
    });

    test('addRecent enforces max 100 entries', () {
      for (var i = 0; i < 25; i++) {
        notifier.addRecent('file$i.dart', '/tmp/file$i.dart', false);
      }
      expect(notifier.state.length, 25);

      for (var i = 25; i < 160; i++) {
        notifier.addRecent('file$i.dart', '/tmp/file$i.dart', false);
      }
      expect(notifier.state.length, 100);
      // Most recent should be first.
      expect(notifier.state.first.path, '/tmp/file159.dart');
    });

    test('addRecent handles folders', () {
      notifier.addRecent('project', '/home/user/project', true);
      expect(notifier.state.first.isFolder, true);
    });

    test('removeRecent removes entry by path', () {
      notifier.addRecent('test.dart', '/tmp/test.dart', false);
      notifier.addRecent('other.dart', '/tmp/other.dart', false);

      notifier.removeRecent('/tmp/test.dart');
      expect(notifier.state.length, 1);
      expect(notifier.state.first.path, '/tmp/other.dart');
    });

    test('removeRecent does nothing for non-existent path', () {
      notifier.addRecent('test.dart', '/tmp/test.dart', false);
      notifier.removeRecent('/tmp/nonexistent.dart');
      expect(notifier.state.length, 1);
    });

    test('addRecent moves existing entry to top with updated timestamp', () {
      notifier.addRecent('a.dart', '/tmp/a.dart', false);
      notifier.addRecent('b.dart', '/tmp/b.dart', false);
      notifier.addRecent('c.dart', '/tmp/c.dart', false);

      // a is at position 2 (oldest).
      expect(notifier.state[2].path, '/tmp/a.dart');

      // Re-add a — it should move to position 0.
      notifier.addRecent('a.dart', '/tmp/a.dart', false);
      expect(notifier.state.first.path, '/tmp/a.dart');
      expect(notifier.state.length, 3);
    });
  });
}
