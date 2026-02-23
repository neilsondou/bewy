import 'package:bewy/core/providers/file_icon_theme_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileIconThemeNotifier', () {
    test('defaults use classic icon theme and monochrome color theme', () {
      final notifier = FileIconThemeNotifier();
      addTearDown(notifier.dispose);

      expect(notifier.state.themeMode, FileIconThemeMode.classic);
      expect(notifier.state.colorTheme, FileIconColorTheme.monochrome);
    });

    test('setThemeMode updates state', () async {
      final notifier = FileIconThemeNotifier();
      addTearDown(notifier.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await notifier.setThemeMode(FileIconThemeMode.material);

      expect(notifier.state.themeMode, FileIconThemeMode.material);
    });

    test('setColorTheme updates state', () async {
      final notifier = FileIconThemeNotifier();
      addTearDown(notifier.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await notifier.setColorTheme(FileIconColorTheme.monochrome);

      expect(notifier.state.colorTheme, FileIconColorTheme.monochrome);
    });

    test('supports newly added icon themes', () async {
      final notifier = FileIconThemeNotifier();
      addTearDown(notifier.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await notifier.setThemeMode(FileIconThemeMode.fontAwesome);
      expect(notifier.state.themeMode, FileIconThemeMode.fontAwesome);

      await notifier.setThemeMode(FileIconThemeMode.phosphor);
      expect(notifier.state.themeMode, FileIconThemeMode.phosphor);
    });
  });
}
