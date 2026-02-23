import 'dart:ffi';
import 'tree_sitter_ffi.dart';
import 'app_log_service.dart';

/// A single syntax diagnostic produced by tree-sitter.
class TreeSitterDiagnostic {
  const TreeSitterDiagnostic({
    required this.startRow,
    required this.startCol,
    required this.endRow,
    required this.endCol,
    required this.kind,
  });

  final int startRow;
  final int startCol;
  final int endRow;
  final int endCol;

  /// 0 = ERROR, 1 = MISSING
  final int kind;

  String get message =>
      kind == 1 ? 'Missing syntax element' : 'Syntax error';
}

/// Singleton service wrapping the tree-sitter native library.
///
/// Call [initialize] once at startup. Check [isAvailable] before using.
class TreeSitterService {
  TreeSitterService._();

  static final TreeSitterService instance = TreeSitterService._();

  TreeSitterBindings? _bindings;

  /// Language-id → native parser handle cache.
  final Map<String, Pointer<Void>> _parsers = {};

  /// Whether the native library loaded successfully.
  bool get isAvailable => _bindings != null;

  /// The set of language IDs supported by the native library.
  List<String> get supportedLanguages =>
      _bindings?.supportedLanguages() ?? const [];

  /// Attempt to load the native library.
  /// Safe to call multiple times; subsequent calls are no-ops.
  void initialize() {
    if (_bindings != null) return;
    try {
      _bindings = TreeSitterBindings.load();
      if (_bindings != null) {
        AppLogService.instance.info(
          'tree-sitter',
          'Native library loaded, languages: ${supportedLanguages.length}',
        );
      } else {
        AppLogService.instance.warn(
          'tree-sitter',
          'Native library not available (bewy_tree_sitter.dll not found)',
        );
      }
    } catch (e) {
      AppLogService.instance.warn(
        'tree-sitter',
        'Failed to initialize: $e',
      );
    }
  }

  /// Parse [source] as [languageId] and return syntax diagnostics.
  ///
  /// Returns an empty list if the library is not available or the language
  /// is not supported.
  List<TreeSitterDiagnostic> parse(
    String languageId,
    String source, {
    int maxDiagnostics = 16,
  }) {
    final bindings = _bindings;
    if (bindings == null) return const [];

    try {
      // Get or create parser for this language
      var parser = _parsers[languageId];
      if (parser == null || parser == nullptr) {
        parser = bindings.parserNew(languageId);
        if (parser == nullptr) return const [];
        _parsers[languageId] = parser;
      }

      final result = bindings.parse(parser, source, maxDiagnostics);
      final items = result.items;
      final count = result.count;
      try {
        if (count == 0 || items == nullptr) return const [];
        final diagnostics = <TreeSitterDiagnostic>[];
        for (int i = 0; i < count; i++) {
          final item = items[i];
          diagnostics.add(TreeSitterDiagnostic(
            startRow: item.startRow,
            startCol: item.startCol,
            endRow: item.endRow,
            endCol: item.endCol,
            kind: item.kind,
          ));
        }
        return diagnostics;
      } finally {
        bindings.freeResult(items);
      }
    } catch (e) {
      AppLogService.instance.warn(
        'tree-sitter',
        'Parse failed for $languageId: $e',
      );
      return const [];
    }
  }

  /// Release the cached parser for a specific language.
  void releaseLanguage(String languageId) {
    final parser = _parsers.remove(languageId);
    if (parser != null && parser != nullptr) {
      _bindings?.parserFree(parser);
    }
  }

  /// Release all cached parsers and reset state.
  void dispose() {
    final bindings = _bindings;
    if (bindings != null) {
      for (final parser in _parsers.values) {
        if (parser != nullptr) {
          bindings.parserFree(parser);
        }
      }
    }
    _parsers.clear();
    AppLogService.instance.info('tree-sitter', 'All parsers released');
  }
}
