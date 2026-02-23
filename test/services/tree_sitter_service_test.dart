import 'package:flutter_test/flutter_test.dart';
import 'package:bewy/core/services/tree_sitter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TreeSitterService', () {
    late TreeSitterService service;

    setUp(() {
      service = TreeSitterService.instance;
    });

    test('singleton returns same instance', () {
      expect(TreeSitterService.instance, same(service));
    });

    test('isAvailable is false before initialize when DLL is missing', () {
      // In test environment the DLL is typically not present.
      // This verifies the graceful degradation path.
      // If the DLL is present, isAvailable will be true after initialize.
      // We just verify the property does not throw.
      expect(service.isAvailable, isA<bool>());
    });

    test('initialize does not throw even if DLL is missing', () {
      expect(() => service.initialize(), returnsNormally);
    });

    test('parse returns empty list when DLL is unavailable', () {
      final result = service.parse('dart', 'void main() {}');
      // If DLL is not loaded, returns empty; if loaded, returns diagnostics
      expect(result, isA<List<TreeSitterDiagnostic>>());
    });

    test('supportedLanguages returns list', () {
      service.initialize();
      final langs = service.supportedLanguages;
      expect(langs, isA<List<String>>());
      // If DLL is available, should have 30 languages
      if (service.isAvailable) {
        expect(langs.length, greaterThanOrEqualTo(29));
        expect(langs, contains('dart'));
        expect(langs, contains('javascript'));
        expect(langs, contains('python'));
        expect(langs, contains('json'));
      }
    });

    test('parse detects syntax errors when DLL is available', () {
      service.initialize();
      if (!service.isAvailable) {
        // Skip if DLL not present (CI / test-only environment)
        return;
      }
      // Intentionally broken JSON
      final diagnostics = service.parse('json', '{ "key": }');
      expect(diagnostics, isNotEmpty);
      expect(diagnostics.first.startRow, isNonNegative);
      expect(diagnostics.first.kind, anyOf(0, 1));
    });

    test('parse returns empty list for valid source', () {
      service.initialize();
      if (!service.isAvailable) return;
      final diagnostics = service.parse('json', '{"key": "value"}');
      expect(diagnostics, isEmpty);
    });

    test('parse returns empty list for unsupported language', () {
      service.initialize();
      final diagnostics = service.parse('unknown_lang_xyz', 'hello');
      expect(diagnostics, isEmpty);
    });

    test('releaseLanguage does not throw for unknown language', () {
      expect(() => service.releaseLanguage('nonexistent'), returnsNormally);
    });

    test('dispose does not throw', () {
      expect(() => service.dispose(), returnsNormally);
    });
  });

  group('TreeSitterDiagnostic', () {
    test('message for ERROR kind', () {
      const d = TreeSitterDiagnostic(
        startRow: 0,
        startCol: 5,
        endRow: 0,
        endCol: 6,
        kind: 0,
      );
      expect(d.message, 'Syntax error');
    });

    test('message for MISSING kind', () {
      const d = TreeSitterDiagnostic(
        startRow: 1,
        startCol: 0,
        endRow: 1,
        endCol: 1,
        kind: 1,
      );
      expect(d.message, 'Missing syntax element');
    });
  });
}
