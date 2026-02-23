import 'package:flutter_test/flutter_test.dart';
import 'package:bewy/core/editor/re_editor_compat.dart';
import 'package:bewy/features/editor_area/widgets/bracket_match_painter.dart';
import 'package:bewy/features/editor_area/presentation/editor_settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 鈹€鈹€ Bracket Match Algorithm 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  group('BracketMatchPainter.findBracketMatch', () {
    CodeLines makeCodeLines(List<String> lines) {
      return CodeLines.of(lines.map((l) => CodeLine(l)).toList());
    }

    test('finds matching parentheses on same line', () {
      final lines = makeCodeLines(['foo(bar)']);
      // Cursor after '(' at col 4
      final result = BracketMatchPainter.findBracketMatch(lines, 0, 4);
      expect(result, isNotNull);
      expect(result, equals((0, 3, 0, 7)));
    });

    test('finds matching curly braces across lines', () {
      final lines = makeCodeLines(['void main() {', '  print("hello");', '}']);
      // 'void main() {' has { at index 12, cursor after it = col 13
      final result = BracketMatchPainter.findBracketMatch(lines, 0, 13);
      expect(result, isNotNull);
      expect(result!.$1, 0); // first bracket on line 0
      expect(result.$2, 12); // '{' is at col 12
      expect(result.$3, 2); // matching '}' on line 2
      expect(result.$4, 0); // '}' at col 0
    });

    test('finds matching square brackets', () {
      final lines = makeCodeLines(['arr[0]']);
      // Cursor after '[' at col 4
      final result = BracketMatchPainter.findBracketMatch(lines, 0, 4);
      expect(result, isNotNull);
      expect(result, equals((0, 3, 0, 5)));
    });

    test('handles nested brackets', () {
      final lines = makeCodeLines(['((a + b))']);
      // Cursor after outer '(' at col 1
      final result = BracketMatchPainter.findBracketMatch(lines, 0, 1);
      expect(result, isNotNull);
      expect(result, equals((0, 0, 0, 8)));
    });

    test('handles nested brackets - inner', () {
      final lines = makeCodeLines(['((a + b))']);
      // Cursor after inner '(' at col 2
      final result = BracketMatchPainter.findBracketMatch(lines, 0, 2);
      expect(result, isNotNull);
      expect(result, equals((0, 1, 0, 7)));
    });

    test('returns null for unmatched bracket', () {
      final lines = makeCodeLines(['(a + b']);
      final result = BracketMatchPainter.findBracketMatch(lines, 0, 1);
      expect(result, isNull);
    });

    test('returns null when cursor is not near a bracket', () {
      final lines = makeCodeLines(['hello world']);
      final result = BracketMatchPainter.findBracketMatch(lines, 0, 3);
      expect(result, isNull);
    });

    test('skips brackets inside single-quoted strings', () {
      // print('(');
      // p(0) r(1) i(2) n(3) t(4) ((5) '(6) ((7) '(8) )(9) ;(10)
      final lines = makeCodeLines(["print('(');"]);
      // cursor at col 6 means char before is ( at index 5
      final result = BracketMatchPainter.findBracketMatch(lines, 0, 6);
      expect(result, isNotNull);
      expect(result!.$1, 0);
      expect(result.$2, 5);
      expect(result.$3, 0);
      expect(result.$4, 9);
    });

    test('skips brackets inside double-quoted strings', () {
      // print("(");
      // p(0) r(1) i(2) n(3) t(4) ((5) "(6) ((7) "(8) )(9) ;(10)
      final lines = makeCodeLines(['print("(");']);
      final result = BracketMatchPainter.findBracketMatch(lines, 0, 6);
      expect(result, isNotNull);
      expect(result!.$1, 0);
      expect(result.$2, 5);
      expect(result.$3, 0);
      expect(result.$4, 9);
    });

    test('backward search from closing bracket', () {
      final lines = makeCodeLines(['if (true) {', '  return;', '}']);
      // Cursor at '}' on line 2, col 0 鈥?check at cursor
      final result = BracketMatchPainter.findBracketMatch(lines, 2, 0);
      expect(result, isNotNull);
      expect(result!.$1, 0); // opening '{' on line 0
      expect(result.$3, 2); // closing '}' on line 2
    });

    test('handles empty lines', () {
      final lines = makeCodeLines(['']);
      final result = BracketMatchPainter.findBracketMatch(lines, 0, 0);
      expect(result, isNull);
    });

    test('handles cursor at line boundary', () {
      final lines = makeCodeLines(['(', ')']);
      // Cursor at beginning of line 1, col 0 鈥?check at cursor
      final result = BracketMatchPainter.findBracketMatch(lines, 1, 0);
      expect(result, isNotNull);
      expect(result, equals((0, 0, 1, 0)));
    });
  });

  // 鈹€鈹€ Editor Settings 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
  group('EditorSettingsState indent/trim settings', () {
    late EditorSettingsNotifier notifier;

    setUp(() {
      notifier = EditorSettingsNotifier();
    });

    tearDown(() {
      notifier.dispose();
    });

    test('indentSize defaults to 2', () {
      expect(notifier.state.indentSize, 2);
    });

    test('useSpaces defaults to true', () {
      expect(notifier.state.useSpaces, isTrue);
    });

    test('trimTrailingWhitespace defaults to false', () {
      expect(notifier.state.trimTrailingWhitespace, isFalse);
    });

    test('setIndentSize changes indent size', () {
      notifier.setIndentSize(4);
      expect(notifier.state.indentSize, 4);
    });

    test('setUseSpaces changes use spaces', () {
      notifier.setUseSpaces(false);
      expect(notifier.state.useSpaces, isFalse);
    });

    test('setTrimTrailingWhitespace changes trim flag', () {
      notifier.setTrimTrailingWhitespace(true);
      expect(notifier.state.trimTrailingWhitespace, isTrue);
    });

    test('copyWith preserves new indent fields', () {
      const state = EditorSettingsState(
        indentSize: 4,
        useSpaces: false,
        trimTrailingWhitespace: true,
      );
      final copied = state.copyWith(fontSize: 16.0);
      expect(copied.indentSize, 4);
      expect(copied.useSpaces, isFalse);
      expect(copied.trimTrailingWhitespace, isTrue);
      expect(copied.fontSize, 16.0);
    });

    test('copyWith overrides indent fields', () {
      const state = EditorSettingsState();
      final copied = state.copyWith(
        indentSize: 8,
        useSpaces: false,
        trimTrailingWhitespace: true,
      );
      expect(copied.indentSize, 8);
      expect(copied.useSpaces, isFalse);
      expect(copied.trimTrailingWhitespace, isTrue);
    });
  });
}

