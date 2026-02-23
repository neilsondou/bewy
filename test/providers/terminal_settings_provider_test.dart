import 'package:bewy/features/bottom_panel/presentation/terminal_settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalSettingsNotifier', () {
    test('defaults use cmd as default profile', () {
      final notifier = TerminalSettingsNotifier();
      addTearDown(notifier.dispose);
      expect(notifier.state.defaultProfileId, equals('cmd'));
    });

    test('setFontSize updates state', () {
      final notifier = TerminalSettingsNotifier();
      addTearDown(notifier.dispose);
      notifier.setFontSize(16.0);
      expect(notifier.state.fontSize, equals(16.0));
    });
  });
}
