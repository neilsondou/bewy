import 'dart:ffi';
import 'dart:convert';
import 'package:ffi/ffi.dart';

// ── Native struct types ─────────────────────────────────────────────────

/// Matches `BewyTsDiagnostic` in bewy_tree_sitter.h.
final class BewyTsDiagnostic extends Struct {
  @Uint32()
  external int startRow;
  @Uint32()
  external int startCol;
  @Uint32()
  external int endRow;
  @Uint32()
  external int endCol;
  @Uint32()
  external int kind; // 0 = ERROR, 1 = MISSING
}

// ── Native function typedefs ────────────────────────────────────────────

typedef _ParserNewC = Pointer<Void> Function(Pointer<Utf8> languageId);
typedef _ParserNewDart = Pointer<Void> Function(Pointer<Utf8> languageId);

// bewy_ts_parse now returns uint32_t count and writes items to out_items.
typedef _ParseC = Uint32 Function(
    Pointer<Void> parser,
    Pointer<Utf8> source,
    Uint32 sourceLen,
    Uint32 max,
    Pointer<Pointer<BewyTsDiagnostic>> outItems);
typedef _ParseDart = int Function(
    Pointer<Void> parser,
    Pointer<Utf8> source,
    int sourceLen,
    int max,
    Pointer<Pointer<BewyTsDiagnostic>> outItems);

typedef _FreeResultC = Void Function(Pointer<BewyTsDiagnostic> items);
typedef _FreeResultDart = void Function(Pointer<BewyTsDiagnostic> items);

typedef _ParserFreeC = Void Function(Pointer<Void> parser);
typedef _ParserFreeDart = void Function(Pointer<Void> parser);

typedef _SupportedLanguagesC = Pointer<Utf8> Function();
typedef _SupportedLanguagesDart = Pointer<Utf8> Function();

// ── Bindings class ──────────────────────────────────────────────────────

class TreeSitterBindings {
  TreeSitterBindings._(this._lib);

  final DynamicLibrary _lib;

  static TreeSitterBindings? _instance;

  /// Try to load the native library. Returns null if loading fails.
  static TreeSitterBindings? load() {
    if (_instance != null) return _instance;
    try {
      final lib = DynamicLibrary.open('bewy_tree_sitter.dll');
      _instance = TreeSitterBindings._(lib);
      return _instance;
    } catch (_) {
      return null;
    }
  }

  late final _parserNew =
      _lib.lookupFunction<_ParserNewC, _ParserNewDart>('bewy_ts_parser_new');

  late final _parse =
      _lib.lookupFunction<_ParseC, _ParseDart>('bewy_ts_parse');

  late final _freeResultPtr =
      _lib.lookupFunction<_FreeResultC, _FreeResultDart>('bewy_ts_free_result');

  late final _parserFree =
      _lib.lookupFunction<_ParserFreeC, _ParserFreeDart>('bewy_ts_parser_free');

  late final _supportedLanguages =
      _lib.lookupFunction<_SupportedLanguagesC, _SupportedLanguagesDart>(
          'bewy_ts_supported_languages');

  Pointer<Void> parserNew(String languageId) {
    final nativeId = languageId.toNativeUtf8(allocator: malloc);
    try {
      return _parserNew(nativeId);
    } finally {
      malloc.free(nativeId);
    }
  }

  /// Parse source and return (items pointer, count). Caller must call
  /// freeResult with the items pointer when done.
  ({Pointer<BewyTsDiagnostic> items, int count}) parse(
      Pointer<Void> parser, String source, int maxDiagnostics) {
    final utf8Bytes = utf8.encode(source);
    final nativeSource = malloc<Uint8>(utf8Bytes.length + 1);
    final outItems = malloc<Pointer<BewyTsDiagnostic>>();
    try {
      for (int i = 0; i < utf8Bytes.length; i++) {
        nativeSource[i] = utf8Bytes[i];
      }
      nativeSource[utf8Bytes.length] = 0; // null terminator
      outItems.value = nullptr;
      final count = _parse(
          parser, nativeSource.cast<Utf8>(), utf8Bytes.length, maxDiagnostics,
          outItems);
      return (items: outItems.value, count: count);
    } finally {
      malloc.free(nativeSource);
      malloc.free(outItems);
    }
  }

  void freeResult(Pointer<BewyTsDiagnostic> items) {
    if (items != nullptr) {
      _freeResultPtr(items);
    }
  }

  void parserFree(Pointer<Void> parser) {
    _parserFree(parser);
  }

  List<String> supportedLanguages() {
    final ptr = _supportedLanguages();
    if (ptr == nullptr) return const [];
    final str = ptr.toDartString();
    return str.split(';').where((s) => s.isNotEmpty).toList();
  }
}
