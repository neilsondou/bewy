import 'package:flutter_test/flutter_test.dart';
import 'package:bewy/features/status_bar/presentation/status_info_provider.dart';

void main() {
  group('StatusInfoNotifier', () {
    late StatusInfoNotifier notifier;

    setUp(() {
      notifier = StatusInfoNotifier();
    });

    tearDown(() {
      notifier.dispose();
    });

    test('initial state is default', () {
      expect(notifier.state.line, 1);
      expect(notifier.state.column, 1);
      expect(notifier.state.encoding, 'UTF-8');
      expect(notifier.state.language, 'Plain Text');
      expect(notifier.state.hasActiveEditor, isFalse);
    });

    test('update sets line and column', () {
      notifier.update(line: 10, column: 5);
      expect(notifier.state.line, 10);
      expect(notifier.state.column, 5);
      expect(notifier.state.hasActiveEditor, isTrue);
    });

    test('update sets language', () {
      notifier.update(language: 'Dart');
      expect(notifier.state.language, 'Dart');
      expect(notifier.state.hasActiveEditor, isTrue);
    });

    test('update sets encoding', () {
      notifier.update(encoding: 'GBK');
      expect(notifier.state.encoding, 'GBK');
    });

    test('partial update preserves other fields', () {
      notifier.update(line: 10, column: 5, language: 'Dart');
      notifier.update(line: 20);
      expect(notifier.state.line, 20);
      expect(notifier.state.column, 5);
      expect(notifier.state.language, 'Dart');
    });

    test('clear resets to default', () {
      notifier.update(line: 50, column: 30, language: 'Python');
      notifier.clear();
      expect(notifier.state.line, 1);
      expect(notifier.state.column, 1);
      expect(notifier.state.language, 'Plain Text');
      expect(notifier.state.hasActiveEditor, isFalse);
    });
  });
}
