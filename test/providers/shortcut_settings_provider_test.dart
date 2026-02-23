import 'package:bewy/core/models/shortcut_binding.dart';
import 'package:bewy/core/providers/shortcut_settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ShortcutSettingsNotifier notifier;

  setUp(() {
    notifier = ShortcutSettingsNotifier();
  });

  tearDown(() {
    notifier.dispose();
  });

  group('ShortcutSettingsNotifier', () {
    test('setBinding updates binding for action', () {
      final ok = notifier.setBinding(
        ShortcutAction.zoomIn,
        const ShortcutBinding(
          primary: true,
          alt: true,
          shift: false,
          keyId: 'KeyI',
        ),
      );
      expect(ok, isTrue);
      expect(notifier.bindingOf(ShortcutAction.zoomIn).keyId, 'KeyI');
      expect(notifier.bindingOf(ShortcutAction.zoomIn).alt, isTrue);
    });

    test('setBinding rejects duplicate binding used by another action', () {
      const binding = ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyL',
      );
      final first = notifier.setBinding(ShortcutAction.zoomIn, binding);
      final second = notifier.setBinding(ShortcutAction.zoomOut, binding);
      expect(first, isTrue);
      expect(second, isFalse);
    });

    test('setBinding rejects reserved system shortcut', () {
      final ok = notifier.setBinding(
        ShortcutAction.find,
        const ShortcutBinding(
          primary: true,
          alt: false,
          shift: false,
          keyId: 'KeyQ',
        ),
      );
      expect(ok, isFalse);
    });

    test('resetToDefaults restores default binding', () {
      notifier.setBinding(
        ShortcutAction.zoomIn,
        const ShortcutBinding(
          primary: true,
          alt: true,
          shift: false,
          keyId: 'KeyI',
        ),
      );
      notifier.resetToDefaults();
      final restored = notifier.bindingOf(ShortcutAction.zoomIn);
      expect(restored.keyId, 'Equal');
      expect(restored.primary, isTrue);
      expect(restored.alt, isFalse);
    });

    test('importFromJsonMap applies valid bindings', () {
      final exported = notifier.exportAsJsonMap();
      (exported['zoomIn'] as Map<String, dynamic>)['keyId'] = 'KeyI';
      final ok = notifier.importFromJsonMap(exported);
      expect(ok, isTrue);
      expect(notifier.bindingOf(ShortcutAction.zoomIn).keyId, 'KeyI');
    });
  });
}
