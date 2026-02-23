import 'package:bewy/core/providers/app_locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocaleNotifier notifier;

  setUp(() {
    notifier = AppLocaleNotifier();
  });

  tearDown(() {
    notifier.dispose();
  });

  group('AppLocaleNotifier', () {
    test('setLocale updates state', () async {
      await notifier.setLocale(const Locale('zh', 'CN'));
      expect(notifier.state, const Locale('zh', 'CN'));
    });
  });
}
