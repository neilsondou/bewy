import 'package:flutter_test/flutter_test.dart';
import 'package:bewy/features/editor_area/presentation/editor_area_provider.dart';
import 'package:bewy/features/editor_area/presentation/editor_settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Auto-save delay integration ────────────────────────────────────
  group('EditorAreaNotifier auto-save delay', () {
    late EditorAreaNotifier notifier;

    setUp(() {
      notifier = EditorAreaNotifier();
    });

    tearDown(() {
      notifier.dispose();
    });

    test('default autoSaveDelayMs is 1000', () {
      expect(notifier.autoSaveDelayMs, 1000);
    });

    test('autoSaveDelayMs can be updated', () {
      notifier.autoSaveDelayMs = 500;
      expect(notifier.autoSaveDelayMs, 500);
    });

    test('autoSaveDelayMs can be set to 2000', () {
      notifier.autoSaveDelayMs = 2000;
      expect(notifier.autoSaveDelayMs, 2000);
    });

    test('autoSaveDelayMs can be set to 5000', () {
      notifier.autoSaveDelayMs = 5000;
      expect(notifier.autoSaveDelayMs, 5000);
    });

    test('autoSaveMode can be set to afterDelay', () {
      notifier.autoSaveMode = AutoSaveMode.afterDelay;
      expect(notifier.autoSaveMode, AutoSaveMode.afterDelay);
    });

    test('autoSaveMode can be set to onFocusLost', () {
      notifier.autoSaveMode = AutoSaveMode.onFocusLost;
      expect(notifier.autoSaveMode, AutoSaveMode.onFocusLost);
    });

    test('both autoSaveMode and delay can be configured together', () {
      notifier.autoSaveMode = AutoSaveMode.afterDelay;
      notifier.autoSaveDelayMs = 2000;
      expect(notifier.autoSaveMode, AutoSaveMode.afterDelay);
      expect(notifier.autoSaveDelayMs, 2000);
    });
  });
}
