import 'package:bewy/core/models/shortcut_binding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShortcutBinding', () {
    test('toJson/fromJson roundtrip keeps fields', () {
      const binding = ShortcutBinding(
        primary: true,
        alt: false,
        shift: true,
        keyId: 'KeyK',
      );
      final restored = ShortcutBinding.fromJson(binding.toJson());
      expect(restored, binding);
    });

    test('displayLabel uses Ctrl on non-mac primary', () {
      const binding = ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyS',
      );
      expect(binding.displayLabel(isMac: false), 'Ctrl+S');
    });

    test('displayLabel uses Cmd on mac primary', () {
      const binding = ShortcutBinding(
        primary: true,
        alt: false,
        shift: false,
        keyId: 'KeyS',
      );
      expect(binding.displayLabel(isMac: true), 'Cmd+S');
    });
  });
}
