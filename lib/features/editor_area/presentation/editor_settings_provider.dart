import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../core/services/config_service.dart';
import '../../../core/theme/app_colors.dart';

enum AutoSaveMode { off, afterDelay, onFocusLost }

enum FileEncodingOption { utf8, utf8bom, gbk, gb18030 }

enum DiagnosticsEngine { treeSitter, languageServer }

/// Global editor settings shared across all editor tabs.
class EditorSettingsState {
  const EditorSettingsState({
    this.wordWrap = false,
    this.fontSize = 14.0,
    this.autoSaveMode = AutoSaveMode.off,
    this.autoSaveDelayMs = 1000,
    this.autoFormatOnSave = false,
    this.indentSize = 2,
    this.useSpaces = true,
    this.trimTrailingWhitespace = false,
    this.showMinimap = true,
    this.smoothScrolling = true,
    this.openLastFolderOnStartup = true,
    this.defaultFileEncoding = FileEncodingOption.utf8,
    this.autoPairSymbols = true,
    this.codeFoldingMaxLines = 2000,
    this.showIndentGuides = true,
    this.editorFontFamily = 'JetBrainsMono',
    this.editorLetterSpacing = 0.0,
    this.uiFontFamily = 'SegoeUI',
    this.appThemeMode = AppThemeMode.dark,
    this.enableLsp = true,
    this.enableSemanticHighlighting = true,
    this.enableLspDiagnostics = true,
    this.diagnosticsEngine = DiagnosticsEngine.treeSitter,
    this.disableCodeForgeShortcuts = true,
    this.lspLanguageEnabled = _defaultLspLanguageEnabled,
  });

  final bool wordWrap;
  final double fontSize;
  final AutoSaveMode autoSaveMode;
  final int autoSaveDelayMs;
  final bool autoFormatOnSave;
  final int indentSize;
  final bool useSpaces;
  final bool trimTrailingWhitespace;
  final bool showMinimap;
  final bool smoothScrolling;
  final bool openLastFolderOnStartup;
  final FileEncodingOption defaultFileEncoding;
  final bool autoPairSymbols;
  final int codeFoldingMaxLines;
  final bool showIndentGuides;
  final String editorFontFamily;
  final double editorLetterSpacing;
  final String uiFontFamily;
  final AppThemeMode appThemeMode;
  final bool enableLsp;
  final bool enableSemanticHighlighting;
  final bool enableLspDiagnostics;
  final DiagnosticsEngine diagnosticsEngine;
  final bool disableCodeForgeShortcuts;
  final Map<String, bool> lspLanguageEnabled;

  EditorSettingsState copyWith({
    bool? wordWrap,
    double? fontSize,
    AutoSaveMode? autoSaveMode,
    int? autoSaveDelayMs,
    bool? autoFormatOnSave,
    int? indentSize,
    bool? useSpaces,
    bool? trimTrailingWhitespace,
    bool? showMinimap,
    bool? smoothScrolling,
    bool? openLastFolderOnStartup,
    FileEncodingOption? defaultFileEncoding,
    bool? autoPairSymbols,
    int? codeFoldingMaxLines,
    bool? showIndentGuides,
    String? editorFontFamily,
    double? editorLetterSpacing,
    String? uiFontFamily,
    AppThemeMode? appThemeMode,
    bool? enableLsp,
    bool? enableSemanticHighlighting,
    bool? enableLspDiagnostics,
    DiagnosticsEngine? diagnosticsEngine,
    bool? disableCodeForgeShortcuts,
    Map<String, bool>? lspLanguageEnabled,
  }) {
    return EditorSettingsState(
      wordWrap: wordWrap ?? this.wordWrap,
      fontSize: fontSize ?? this.fontSize,
      autoSaveMode: autoSaveMode ?? this.autoSaveMode,
      autoSaveDelayMs: autoSaveDelayMs ?? this.autoSaveDelayMs,
      autoFormatOnSave: autoFormatOnSave ?? this.autoFormatOnSave,
      indentSize: indentSize ?? this.indentSize,
      useSpaces: useSpaces ?? this.useSpaces,
      trimTrailingWhitespace:
          trimTrailingWhitespace ?? this.trimTrailingWhitespace,
      showMinimap: showMinimap ?? this.showMinimap,
      smoothScrolling: smoothScrolling ?? this.smoothScrolling,
      openLastFolderOnStartup:
          openLastFolderOnStartup ?? this.openLastFolderOnStartup,
      defaultFileEncoding: defaultFileEncoding ?? this.defaultFileEncoding,
      autoPairSymbols: autoPairSymbols ?? this.autoPairSymbols,
      codeFoldingMaxLines: codeFoldingMaxLines ?? this.codeFoldingMaxLines,
      showIndentGuides: showIndentGuides ?? this.showIndentGuides,
      editorFontFamily: editorFontFamily ?? this.editorFontFamily,
      editorLetterSpacing: editorLetterSpacing ?? this.editorLetterSpacing,
      uiFontFamily: uiFontFamily ?? this.uiFontFamily,
      appThemeMode: appThemeMode ?? this.appThemeMode,
      enableLsp: enableLsp ?? this.enableLsp,
      enableSemanticHighlighting:
          enableSemanticHighlighting ?? this.enableSemanticHighlighting,
      enableLspDiagnostics: enableLspDiagnostics ?? this.enableLspDiagnostics,
      diagnosticsEngine: diagnosticsEngine ?? this.diagnosticsEngine,
      disableCodeForgeShortcuts:
          disableCodeForgeShortcuts ?? this.disableCodeForgeShortcuts,
      lspLanguageEnabled:
          lspLanguageEnabled ?? Map<String, bool>.from(this.lspLanguageEnabled),
    );
  }
}

class EditorSettingsNotifier extends StateNotifier<EditorSettingsState> {
  EditorSettingsNotifier() : super(const EditorSettingsState()) {
    _loadSettings();
    _configSub = ConfigService.watchChanges().listen((_) {
      final until = _ignoreExternalUntil;
      if (until != null && DateTime.now().isBefore(until)) return;
      _loadSettings();
    });
  }
  StreamSubscription<void>? _configSub;
  DateTime? _ignoreExternalUntil;

  Future<void> _loadSettings() async {
    try {
      final data = await ConfigService.load();
      if (!mounted) return;
      AutoSaveMode? parsedMode;
      int? parsedDelay;
      bool? parsedAutoFormatOnSave;

      final mode = data['autoSaveMode'] as String?;
      if (mode != null) {
        parsedMode = AutoSaveMode.values.firstWhere(
          (e) => e.name == mode,
          orElse: () => AutoSaveMode.off,
        );
      }

      final delay = data['autoSaveDelayMs'] as int?;
      if (delay != null) {
        parsedDelay = delay;
      }
      final autoFormat = data['autoFormatOnSave'] as bool?;
      if (autoFormat != null) {
        parsedAutoFormatOnSave = autoFormat;
      }

      final indentSize = data['indentSize'] as int?;
      final useSpaces = data['useSpaces'] as bool?;
      final trimTrailing = data['trimTrailingWhitespace'] as bool?;
      final openLastFolderOnStartup = data['openLastFolderOnStartup'] as bool?;
      final autoPairSymbols = data['autoPairSymbols'] as bool?;
      final showIndentGuides = data['showIndentGuides'] as bool?;
      final editorFontFamily = data['editorFontFamily'] as String?;
      final uiFontFamily = data['uiFontFamily'] as String?;
      final rawThemeMode = data['appThemeMode'] as String?;
      final parsedThemeMode =
          rawThemeMode == null
              ? null
              : AppThemeMode.values.firstWhere(
                (e) => e.name == rawThemeMode,
                orElse: () => AppThemeMode.dark,
              );

      final rawEncoding = data['defaultFileEncoding'] as String?;
      final parsedEncoding =
          rawEncoding == null
              ? null
              : FileEncodingOption.values.firstWhere(
                (e) => e.name == rawEncoding,
                orElse: () => FileEncodingOption.utf8,
              );

      final rawFoldingMaxLines = data['codeFoldingMaxLines'] as int?;
      final parsedFoldingMaxLines =
          rawFoldingMaxLines == null
              ? null
              : _clampCodeFoldingMaxLines(rawFoldingMaxLines);

      final rawFontSize = data['editorFontSize'];
      final parsedFontSize =
          rawFontSize is num
              ? _clampEditorFontSize(rawFontSize.toDouble())
              : null;

      final rawLetterSpacing = data['editorLetterSpacing'];
      final parsedLetterSpacing =
          rawLetterSpacing is num
              ? _clampEditorLetterSpacing(rawLetterSpacing.toDouble())
              : null;

      final parsedEnableLsp = data['enableLsp'] as bool?;
      final parsedEnableSemantic = data['enableSemanticHighlighting'] as bool?;
      final parsedEnableDiagnostics = data['enableLspDiagnostics'] as bool?;
      final rawDiagnosticsEngine = data['diagnosticsEngine'] as String?;
      final DiagnosticsEngine? parsedDiagnosticsEngine;
      if (rawDiagnosticsEngine == null) {
        parsedDiagnosticsEngine = null;
      } else if (rawDiagnosticsEngine == 'simpleSyntax') {
        // Migrate legacy value to treeSitter.
        parsedDiagnosticsEngine = DiagnosticsEngine.treeSitter;
      } else {
        parsedDiagnosticsEngine = DiagnosticsEngine.values.firstWhere(
          (e) => e.name == rawDiagnosticsEngine,
          orElse: () => DiagnosticsEngine.treeSitter,
        );
      }
      final parsedDisableCodeForgeShortcuts =
          data['disableCodeForgeShortcuts'] as bool?;
      final rawLanguageEnabled = data['lspLanguageEnabled'];
      final parsedLanguageEnabled = _parseLspLanguageEnabled(
        rawLanguageEnabled,
      );

      state = state.copyWith(
        autoSaveMode: parsedMode,
        autoSaveDelayMs: parsedDelay,
        autoFormatOnSave: parsedAutoFormatOnSave,
        indentSize: indentSize,
        useSpaces: useSpaces,
        trimTrailingWhitespace: trimTrailing,
        openLastFolderOnStartup: openLastFolderOnStartup,
        defaultFileEncoding: parsedEncoding,
        autoPairSymbols: autoPairSymbols,
        codeFoldingMaxLines: parsedFoldingMaxLines,
        showIndentGuides: showIndentGuides,
        editorFontFamily: editorFontFamily,
        fontSize: parsedFontSize,
        editorLetterSpacing: parsedLetterSpacing,
        uiFontFamily: uiFontFamily,
        appThemeMode: parsedThemeMode,
        enableLsp: parsedEnableLsp,
        enableSemanticHighlighting: parsedEnableSemantic,
        enableLspDiagnostics: parsedEnableDiagnostics,
        diagnosticsEngine: parsedDiagnosticsEngine,
        disableCodeForgeShortcuts: parsedDisableCodeForgeShortcuts,
        lspLanguageEnabled: parsedLanguageEnabled,
      );
    } catch (_) {}
  }

  void toggleWordWrap() {
    state = state.copyWith(wordWrap: !state.wordWrap);
  }

  void zoomIn() {
    state = state.copyWith(fontSize: _clampEditorFontSize(state.fontSize + 1));
    _persistDisplaySettings();
  }

  void zoomOut() {
    state = state.copyWith(fontSize: _clampEditorFontSize(state.fontSize - 1));
    _persistDisplaySettings();
  }

  void resetZoom() {
    state = state.copyWith(fontSize: 14.0);
    _persistDisplaySettings();
  }

  void setAutoSaveMode(AutoSaveMode mode) {
    state = state.copyWith(autoSaveMode: mode);
    _persistAutoSave();
  }

  void setAutoSaveDelay(int ms) {
    state = state.copyWith(autoSaveDelayMs: ms);
    _persistAutoSave();
  }

  void setAutoFormatOnSave(bool enabled) {
    state = state.copyWith(autoFormatOnSave: enabled);
    _persistAutoSave();
  }

  void setIndentSize(int size) {
    state = state.copyWith(indentSize: size);
    _persistIndent();
  }

  void setUseSpaces(bool value) {
    state = state.copyWith(useSpaces: value);
    _persistIndent();
  }

  void setTrimTrailingWhitespace(bool value) {
    state = state.copyWith(trimTrailingWhitespace: value);
    _persistTrimTrailing();
  }

  void toggleMinimap() {
    state = state.copyWith(showMinimap: !state.showMinimap);
  }

  void toggleSmoothScrolling() {
    state = state.copyWith(smoothScrolling: !state.smoothScrolling);
  }

  void setOpenLastFolderOnStartup(bool enabled) {
    state = state.copyWith(openLastFolderOnStartup: enabled);
    _persistFileBehaviorSettings();
  }

  void setDefaultFileEncoding(FileEncodingOption encoding) {
    state = state.copyWith(defaultFileEncoding: encoding);
    _persistFileBehaviorSettings();
  }

  void setAutoPairSymbols(bool enabled) {
    state = state.copyWith(autoPairSymbols: enabled);
    _persistEditingBehaviorSettings();
  }

  void setCodeFoldingMaxLines(int lines) {
    state = state.copyWith(
      codeFoldingMaxLines: _clampCodeFoldingMaxLines(lines),
    );
    _persistEditingBehaviorSettings();
  }

  void setShowIndentGuides(bool enabled) {
    state = state.copyWith(showIndentGuides: enabled);
    _persistDisplaySettings();
  }

  void setEditorFontFamily(String family) {
    state = state.copyWith(editorFontFamily: family);
    _persistDisplaySettings();
  }

  void setEditorFontSize(double size) {
    state = state.copyWith(fontSize: _clampEditorFontSize(size));
    _persistDisplaySettings();
  }

  void setEditorLetterSpacing(double value) {
    state = state.copyWith(
      editorLetterSpacing: _clampEditorLetterSpacing(value),
    );
    _persistDisplaySettings();
  }

  void setUiFontFamily(String family) {
    state = state.copyWith(uiFontFamily: family);
    _persistUiSettings();
  }

  void setAppThemeMode(AppThemeMode mode) {
    state = state.copyWith(appThemeMode: mode);
    _persistUiSettings();
  }

  void setEnableLsp(bool enabled) {
    state = state.copyWith(enableLsp: enabled);
    _persistLspSettings();
  }

  void setEnableSemanticHighlighting(bool enabled) {
    state = state.copyWith(enableSemanticHighlighting: enabled);
    _persistLspSettings();
  }

  void setEnableLspDiagnostics(bool enabled) {
    state = state.copyWith(enableLspDiagnostics: enabled);
    _persistLspSettings();
  }

  void setDiagnosticsEngine(DiagnosticsEngine engine) {
    state = state.copyWith(diagnosticsEngine: engine);
    _persistLspSettings();
  }

  void setDisableCodeForgeShortcuts(bool enabled) {
    state = state.copyWith(disableCodeForgeShortcuts: enabled);
    _persistLspSettings();
  }

  void setLspLanguageEnabled(String languageId, bool enabled) {
    final next = Map<String, bool>.from(state.lspLanguageEnabled);
    next[languageId] = enabled;
    state = state.copyWith(lspLanguageEnabled: next);
    _persistLspSettings();
  }

  Future<void> _persistAutoSave() async {
    final mode = state.autoSaveMode.name;
    final delay = state.autoSaveDelayMs;
    final data = await ConfigService.load();
    if (!mounted) return;
    data['autoSaveMode'] = mode;
    data['autoSaveDelayMs'] = delay;
    data['autoFormatOnSave'] = state.autoFormatOnSave;
    _markLocalWrite();
    await ConfigService.save(data);
  }

  Future<void> _persistIndent() async {
    final data = await ConfigService.load();
    if (!mounted) return;
    data['indentSize'] = state.indentSize;
    data['useSpaces'] = state.useSpaces;
    _markLocalWrite();
    await ConfigService.save(data);
  }

  Future<void> _persistTrimTrailing() async {
    final data = await ConfigService.load();
    if (!mounted) return;
    data['trimTrailingWhitespace'] = state.trimTrailingWhitespace;
    _markLocalWrite();
    await ConfigService.save(data);
  }

  Future<void> _persistFileBehaviorSettings() async {
    final data = await ConfigService.load();
    if (!mounted) return;
    data['openLastFolderOnStartup'] = state.openLastFolderOnStartup;
    data['defaultFileEncoding'] = state.defaultFileEncoding.name;
    _markLocalWrite();
    await ConfigService.save(data);
  }

  Future<void> _persistEditingBehaviorSettings() async {
    final data = await ConfigService.load();
    if (!mounted) return;
    data['autoPairSymbols'] = state.autoPairSymbols;
    data['codeFoldingMaxLines'] = state.codeFoldingMaxLines;
    _markLocalWrite();
    await ConfigService.save(data);
  }

  Future<void> _persistDisplaySettings() async {
    final data = await ConfigService.load();
    if (!mounted) return;
    data['showIndentGuides'] = state.showIndentGuides;
    data['editorFontFamily'] = state.editorFontFamily;
    data['editorFontSize'] = state.fontSize;
    data['editorLetterSpacing'] = state.editorLetterSpacing;
    _markLocalWrite();
    await ConfigService.save(data);
  }

  Future<void> _persistUiSettings() async {
    final data = await ConfigService.load();
    if (!mounted) return;
    data['uiFontFamily'] = state.uiFontFamily;
    data['appThemeMode'] = state.appThemeMode.name;
    _markLocalWrite();
    await ConfigService.save(data);
  }

  Future<void> _persistLspSettings() async {
    final data = await ConfigService.load();
    if (!mounted) return;
    data['enableLsp'] = state.enableLsp;
    data['enableSemanticHighlighting'] = state.enableSemanticHighlighting;
    data['enableLspDiagnostics'] = state.enableLspDiagnostics;
    data['diagnosticsEngine'] = state.diagnosticsEngine.name;
    data['disableCodeForgeShortcuts'] = state.disableCodeForgeShortcuts;
    data['lspLanguageEnabled'] = state.lspLanguageEnabled;
    _markLocalWrite();
    await ConfigService.save(data);
  }

  void _markLocalWrite() {
    _ignoreExternalUntil = DateTime.now().add(
      const Duration(milliseconds: 300),
    );
  }

  static int _clampCodeFoldingMaxLines(int value) => value.clamp(50, 20000);
  static double _clampEditorFontSize(double value) => value.clamp(8.0, 40.0);
  static double _clampEditorLetterSpacing(double value) =>
      value.clamp(-1.0, 6.0);

  static Map<String, bool> _parseLspLanguageEnabled(Object? raw) {
    final next = Map<String, bool>.from(_defaultLspLanguageEnabled);
    if (raw is! Map) return next;
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (next.containsKey(key) && value is bool) {
        next[key] = value;
      }
    }
    return next;
  }

  @override
  void dispose() {
    _configSub?.cancel();
    super.dispose();
  }
}

final editorSettingsProvider =
    StateNotifierProvider<EditorSettingsNotifier, EditorSettingsState>(
      (ref) => EditorSettingsNotifier(),
    );

const Map<String, bool> _defaultLspLanguageEnabled = {
  'dart': true,
  'javascript': true,
  'typescript': true,
  'python': true,
  'ruby': true,
  'rust': true,
  'go': true,
  'java': true,
  'kotlin': true,
  'swift': true,
  'c': true,
  'cpp': true,
  'csharp': true,
  'json': true,
  'yaml': true,
  'xml': true,
  'css': true,
  'scss': true,
  'markdown': true,
  'sql': true,
  'bash': true,
  'powershell': true,
  'ini': true,
  'php': true,
  'lua': true,
  'r': true,
  'dockerfile': true,
  'makefile': true,
};
