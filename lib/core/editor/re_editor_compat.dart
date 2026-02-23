import 'package:code_forge/code_forge.dart';
import 'package:flutter/material.dart';
import 'package:re_highlight/re_highlight.dart';
import 'dart:io';
import '../services/app_log_service.dart';

class CodeLineOptions {
  const CodeLineOptions({this.indentSize = 2});

  final int indentSize;
}

class CodeLine {
  const CodeLine(this.text);

  final String text;
}

class CodeLines {
  const CodeLines._(this._lines);

  factory CodeLines.of(List<CodeLine> lines) => CodeLines._(lines);

  factory CodeLines.fromText(String text) {
    final parts = text.split('\n');
    return CodeLines._(parts.map(CodeLine.new).toList(growable: false));
  }

  final List<CodeLine> _lines;

  int get length => _lines.length;
  int get lineCount => _lines.length;

  CodeLine operator [](int index) => _lines[index];
}

class CodeLineSelection {
  const CodeLineSelection({
    required this.baseIndex,
    required this.baseOffset,
    required this.extentIndex,
    required this.extentOffset,
  });

  const CodeLineSelection.collapsed({required int index, required int offset})
    : baseIndex = index,
      baseOffset = offset,
      extentIndex = index,
      extentOffset = offset;

  final int baseIndex;
  final int baseOffset;
  final int extentIndex;
  final int extentOffset;

  bool get isCollapsed =>
      baseIndex == extentIndex && baseOffset == extentOffset;

  int get startIndex {
    if (baseIndex < extentIndex) return baseIndex;
    if (baseIndex > extentIndex) return extentIndex;
    return baseOffset <= extentOffset ? baseIndex : extentIndex;
  }

  int get startOffset {
    if (baseIndex < extentIndex) return baseOffset;
    if (baseIndex > extentIndex) return extentOffset;
    return baseOffset <= extentOffset ? baseOffset : extentOffset;
  }

  int get endIndex {
    if (baseIndex > extentIndex) return baseIndex;
    if (baseIndex < extentIndex) return extentIndex;
    return baseOffset >= extentOffset ? baseIndex : extentIndex;
  }

  int get endOffset {
    if (baseIndex > extentIndex) return baseOffset;
    if (baseIndex < extentIndex) return extentOffset;
    return baseOffset >= extentOffset ? baseOffset : extentOffset;
  }
}

class CodeScrollController {
  CodeScrollController({
    ScrollController? verticalScroller,
    ScrollController? horizontalScroller,
  }) : verticalScroller = verticalScroller ?? ScrollController(),
       horizontalScroller = horizontalScroller ?? ScrollController();

  final ScrollController verticalScroller;
  final ScrollController horizontalScroller;

  void dispose() {
    verticalScroller.dispose();
    horizontalScroller.dispose();
  }
}

class CodeLineEditingController extends ChangeNotifier {
  CodeLineEditingController._(
    this._delegate,
    this._undoController, [
    this._releaseLspLease,
  ]) {
    _delegate.addListener(_relayListener);
    _delegate.diagnosticsNotifier.addListener(_onDiagnosticsChanged);
    _delegate.semanticTokens.addListener(_onSemanticTokensChanged);
  }

  factory CodeLineEditingController.fromText(
    String text, [
    CodeLineOptions options = const CodeLineOptions(),
  ]) {
    final delegate = CodeForgeController();
    final undoController = UndoRedoController();
    delegate.setUndoController(undoController);
    delegate.text = text;
    return CodeLineEditingController._(delegate, undoController);
  }

  static Future<CodeLineEditingController> fromTextForFile(
    String text, {
    required String filePath,
    String? workspacePath,
    bool bindOpenedFile = true,
    bool enableLsp = true,
    bool enableSemanticHighlighting = true,
    bool enableDiagnostics = true,
    Map<String, bool>? lspLanguageEnabled,
  }) async {
    final lspLease = await _leaseLspConfigForFile(
      filePath: filePath,
      workspacePath: workspacePath,
      enableLsp: enableLsp,
      enableSemanticHighlighting: enableSemanticHighlighting,
      enableDiagnostics: enableDiagnostics,
      lspLanguageEnabled: lspLanguageEnabled,
    );
    final delegate = CodeForgeController(lspConfig: lspLease?.config);
    final undoController = UndoRedoController();
    delegate.setUndoController(undoController);
    delegate.text = text;
    if (bindOpenedFile &&
        lspLease?.config != null &&
        File(filePath).existsSync()) {
      delegate.openedFile = filePath;
      // Keep caller-provided text as source of truth for dirty/newly-loaded tabs.
      delegate.text = text;
    }
    return CodeLineEditingController._(
      delegate,
      undoController,
      lspLease?.release,
    );
  }

  final CodeForgeController _delegate;
  final UndoRedoController _undoController;
  final VoidCallback? _releaseLspLease;

  final ValueNotifier<List<CodeLspDiagnostic>> diagnosticsNotifier =
      ValueNotifier(const []);
  final ValueNotifier<int> semanticMarksVersion = ValueNotifier(0);
  bool _hasSemanticMarks = false;

  CodeForgeController get delegate => _delegate;
  UndoRedoController get undoController => _undoController;
  List<CodeLspDiagnostic> get diagnostics => diagnosticsNotifier.value;
  bool get hasSemanticMarks => _hasSemanticMarks;
  bool get hasLsp => _delegate.lspConfig != null;
  String? get lspLanguageId => _delegate.lspConfig?.languageId;
  String? get lspWorkspacePath => _delegate.lspConfig?.workspacePath;
  String? get lspServerExecutable {
    final config = _delegate.lspConfig;
    if (config is LspStdioConfig) {
      return config.executable;
    }
    return null;
  }

  void _relayListener() => notifyListeners();

  void _onDiagnosticsChanged() {
    final raw = _delegate.diagnosticsNotifier.value;
    final mapped = raw
        .map(
          (d) => CodeLspDiagnostic(
            severity: d.severity,
            message: d.message,
            startLine: (d.range['start']?['line'] as int?) ?? 0,
            startCharacter: (d.range['start']?['character'] as int?) ?? 0,
            endLine: (d.range['end']?['line'] as int?) ?? 0,
            endCharacter: (d.range['end']?['character'] as int?) ?? 0,
          ),
        )
        .toList(growable: false);
    diagnosticsNotifier.value = mapped;
  }

  void _onSemanticTokensChanged() {
    final hasTokens = _delegate.semanticTokens.value.$1 != null;
    if (_hasSemanticMarks != hasTokens) {
      _hasSemanticMarks = hasTokens;
    }
    semanticMarksVersion.value++;
  }

  String get text => _delegate.text;

  set text(String value) {
    _delegate.text = value;
  }

  int get lineCount => _delegate.lineCount;

  CodeLines get codeLines => CodeLines.fromText(_delegate.text);

  CodeLineSelection get selection {
    final sel = _delegate.selection;
    final base = _offsetToLineOffset(sel.baseOffset);
    final extent = _offsetToLineOffset(sel.extentOffset);
    return CodeLineSelection(
      baseIndex: base.$1,
      baseOffset: base.$2,
      extentIndex: extent.$1,
      extentOffset: extent.$2,
    );
  }

  set selection(CodeLineSelection value) {
    final start = _lineOffsetToAbsolute(value.baseIndex, value.baseOffset);
    final end = _lineOffsetToAbsolute(value.extentIndex, value.extentOffset);
    _delegate.selection = TextSelection(baseOffset: start, extentOffset: end);
  }

  String get selectedText {
    final sel = _delegate.selection;
    if (sel.isCollapsed) return '';
    final start = sel.start.clamp(0, _delegate.text.length);
    final end = sel.end.clamp(0, _delegate.text.length);
    return _delegate.text.substring(start, end);
  }

  void cut() => _delegate.cut();
  void copy() => _delegate.copy();
  void paste() => _delegate.paste();
  void selectAll() => _delegate.selectAll();

  void undo() {
    _undoController.undo();
    notifyListeners();
  }

  void redo() {
    _undoController.redo();
    notifyListeners();
  }

  void replaceSelection(String replacement, [CodeLineSelection? where]) {
    final sel = where ?? selection;
    final start = _lineOffsetToAbsolute(sel.startIndex, sel.startOffset);
    final end = _lineOffsetToAbsolute(sel.endIndex, sel.endOffset);
    _delegate.replaceRange(start, end, replacement);
  }

  void runRevocableOp(VoidCallback operation) {
    final handle = _undoController.beginCompoundOperation();
    operation();
    handle.end();
  }

  void moveSelectionLinesUp() => _delegate.moveLineUp();

  void moveSelectionLinesDown() => _delegate.moveLineDown();

  void makeCursorCenterIfInvisible() {
    _delegate.scrollToLine(selection.extentIndex);
  }

  void setGitDiffDecorations({
    List<(int, int)>? addedRanges,
    List<(int, int)>? removedRanges,
    List<(int, int)>? modifiedRanges,
  }) {
    _delegate.setGitDiffDecorations(
      addedRanges: addedRanges,
      removedRanges: removedRanges,
      modifiedRanges: modifiedRanges,
    );
  }

  void clearGitDiffDecorations() => _delegate.clearGitDiffDecorations();

  void applySyntheticDiagnosticsDecorations(List<CodeLspDiagnostic> issues) {
    if (hasLsp) return;
    final synthetic = issues
        .map(
          (d) => LspErrors(
            severity: d.severity,
            message: d.message,
            range: {
              'start': {'line': d.startLine, 'character': d.startCharacter},
              'end': {
                'line': d.endLine,
                'character':
                    d.endCharacter > d.startCharacter
                        ? d.endCharacter
                        : (d.startCharacter + 1),
              },
            },
          ),
        )
        .toList(growable: false);
    _delegate.diagnosticsNotifier.value = synthetic;
  }

  void clearSyntheticDiagnosticsDecorations() {
    if (hasLsp) return;
    if (_delegate.diagnosticsNotifier.value.isEmpty) return;
    _delegate.diagnosticsNotifier.value = const [];
  }

  int get availableCodeActionCount =>
      _delegate.codeActionsNotifier.value?.length ?? 0;

  Future<bool> applyFirstCodeAction() async {
    final actions = _delegate.codeActionsNotifier.value;
    if (actions == null || actions.isEmpty) return false;
    try {
      await _delegate.applyWorkspaceEdit(actions.first);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestSignatureHelp() async {
    if (!hasLsp || _delegate.openedFile == null) return false;
    try {
      await _delegate.callSignatureHelp();
      return _delegate.signatureNotifier.value != null;
    } catch (_) {
      return false;
    }
  }

  (int, int) _offsetToLineOffset(int offset) {
    final clamped = offset.clamp(0, _delegate.text.length);
    final line = _delegate.getLineAtOffset(clamped);
    final lineStart = _delegate.getLineStartOffset(line);
    return (line, clamped - lineStart);
  }

  int _lineOffsetToAbsolute(int line, int offset) {
    final safeLine = line.clamp(0, _delegate.lineCount - 1);
    final lineStart = _delegate.getLineStartOffset(safeLine);
    final lineText = _delegate.getLineText(safeLine);
    final safeOffset = offset.clamp(0, lineText.length);
    return lineStart + safeOffset;
  }

  @override
  void dispose() {
    clearSyntheticDiagnosticsDecorations();
    _releaseLspLease?.call();
    _delegate.diagnosticsNotifier.removeListener(_onDiagnosticsChanged);
    _delegate.semanticTokens.removeListener(_onSemanticTokensChanged);
    _delegate.removeListener(_relayListener);
    _delegate.dispose();
    _undoController.dispose();
    diagnosticsNotifier.dispose();
    semanticMarksVersion.dispose();
    super.dispose();
  }

  static final Map<String, _SharedLspEntry> _sharedLspPool = {};
  static final Map<String, Future<LspConfig?>> _sharedLspInFlight = {};

  static Future<_LspLease?> _leaseLspConfigForFile({
    required String filePath,
    String? workspacePath,
    required bool enableLsp,
    required bool enableSemanticHighlighting,
    required bool enableDiagnostics,
    Map<String, bool>? lspLanguageEnabled,
  }) async {
    if (!enableLsp) return null;
    final languageId = _languageIdForPath(filePath);
    if (languageId == null) return null;
    if (lspLanguageEnabled != null && lspLanguageEnabled[languageId] == false) {
      return null;
    }
    final ws = workspacePath ?? _inferWorkspacePath(filePath);
    final key = '$languageId|$ws';
    final existing = _sharedLspPool[key];
    if (existing != null) {
      existing.refCount++;
      return _LspLease(
        config: existing.config,
        release: _buildSharedRelease(key),
      );
    }
    final inFlight = _sharedLspInFlight[key];
    if (inFlight != null) {
      final awaited = await inFlight;
      if (awaited == null) return null;
      final ready = _sharedLspPool[key];
      if (ready == null) return null;
      ready.refCount++;
      return _LspLease(config: ready.config, release: _buildSharedRelease(key));
    }

    final startFuture = _createLspConfigForFile(
      filePath: filePath,
      workspacePath: ws,
      enableLsp: enableLsp,
      enableSemanticHighlighting: enableSemanticHighlighting,
      enableDiagnostics: enableDiagnostics,
      lspLanguageEnabled: lspLanguageEnabled,
    );
    _sharedLspInFlight[key] = startFuture;
    final created = await startFuture;
    _sharedLspInFlight.remove(key);
    if (created == null) return null;
    final entry = _sharedLspPool.putIfAbsent(
      key,
      () => _SharedLspEntry(config: created),
    );
    if (!identical(entry.config, created)) {
      created.dispose();
    }
    entry.refCount++;
    return _LspLease(config: entry.config, release: _buildSharedRelease(key));
  }

  static VoidCallback _buildSharedRelease(String key) {
    var released = false;
    return () {
      if (released) return;
      released = true;
      final entry = _sharedLspPool[key];
      if (entry == null) return;
      entry.refCount--;
      if (entry.refCount <= 0) {
        _sharedLspPool.remove(key);
        try {
          entry.config.dispose();
        } catch (_) {}
      }
    };
  }

  /// Dispose the shared LSP server for a specific language + workspace.
  /// Called when a non-primary LSP should be released.
  static void disposeSharedLspForLanguage(
    String languageId,
    String workspacePath,
  ) {
    final key = '$languageId|$workspacePath';
    final entry = _sharedLspPool.remove(key);
    if (entry != null) {
      try {
        entry.config.dispose();
      } catch (_) {}
    }
  }

  /// Dispose all shared LSP servers. Called on workspace switch.
  static void disposeAllSharedLsp() {
    final entries = Map<String, _SharedLspEntry>.from(_sharedLspPool);
    _sharedLspPool.clear();
    _sharedLspInFlight.clear();
    for (final entry in entries.values) {
      try {
        entry.config.dispose();
      } catch (_) {}
    }
  }

  static Future<LspConfig?> _createLspConfigForFile({
    required String filePath,
    String? workspacePath,
    required bool enableLsp,
    required bool enableSemanticHighlighting,
    required bool enableDiagnostics,
    Map<String, bool>? lspLanguageEnabled,
  }) async {
    if (!enableLsp) return null;
    final languageId = _languageIdForPath(filePath);
    if (languageId == null) return null;
    if (lspLanguageEnabled != null && lspLanguageEnabled[languageId] == false) {
      return null;
    }
    final launches = _resolveLspLaunchCandidates(languageId);
    if (launches.isEmpty) return null;
    final ws = workspacePath ?? _inferWorkspacePath(filePath);
    for (final launch in launches) {
      try {
        final config = await LspStdioConfig.start(
          executable: launch.executable,
          args: launch.args,
          workspacePath: ws,
          languageId: languageId,
          capabilities: LspClientCapabilities(
            semanticHighlighting: enableSemanticHighlighting,
            codeCompletion: true,
            hoverInfo: true,
            signatureHelp: true,
            documentHighlight: true,
            codeFolding: true,
            codeAction: true,
            rename: true,
            inlayHint: true,
            goToDefinition: true,
            documentColor: true,
          ),
          disableWarning: !enableDiagnostics,
          disableError: !enableDiagnostics,
        );
        AppLogService.instance.info(
          'lsp',
          'start language=$languageId path=$filePath server=${launch.executable}',
        );
        return config;
      } catch (_) {
        AppLogService.instance.warn(
          'lsp',
          'startFailed language=$languageId path=$filePath server=${launch.executable}',
        );
      }
    }
    return null;
  }

  static String? _languageIdForPath(String filePath) {
    final lowerPath = filePath.toLowerCase();
    final name = lowerPath.split(Platform.pathSeparator).last;
    if (name == 'dockerfile') return 'dockerfile';
    if (name == 'makefile') return 'makefile';
    final dot = name.lastIndexOf('.');
    final ext = dot == -1 ? '' : name.substring(dot + 1);
    switch (ext) {
      case 'dart':
        return 'dart';
      case 'js':
      case 'jsx':
        return 'javascript';
      case 'ts':
      case 'tsx':
        return 'typescript';
      case 'py':
        return 'python';
      case 'rb':
        return 'ruby';
      case 'rs':
        return 'rust';
      case 'go':
        return 'go';
      case 'java':
        return 'java';
      case 'kt':
      case 'kts':
        return 'kotlin';
      case 'swift':
        return 'swift';
      case 'c':
        return 'c';
      case 'h':
      case 'hpp':
      case 'hh':
      case 'hxx':
      case 'cpp':
      case 'cc':
      case 'cxx':
        return 'cpp';
      case 'cs':
        return 'csharp';
      case 'json':
        return 'json';
      case 'yml':
      case 'yaml':
        return 'yaml';
      case 'xml':
      case 'html':
      case 'htm':
        return 'xml';
      case 'css':
        return 'css';
      case 'scss':
        return 'scss';
      case 'md':
        return 'markdown';
      case 'sql':
        return 'sql';
      case 'sh':
      case 'bash':
        return 'bash';
      case 'ps1':
        return 'powershell';
      case 'ini':
      case 'cfg':
      case 'toml':
        return 'ini';
      case 'php':
        return 'php';
      case 'lua':
        return 'lua';
      case 'r':
        return 'r';
      default:
        return null;
    }
  }

  static List<_LspLaunchSpec> _resolveLspLaunchCandidates(String languageId) {
    switch (languageId) {
      case 'dart':
        final candidates = <_LspLaunchSpec>[
          const _LspLaunchSpec(
            executable: 'dart.exe',
            args: ['language-server', '--protocol=lsp'],
          ),
          const _LspLaunchSpec(
            executable: 'dart',
            args: ['language-server', '--protocol=lsp'],
          ),
          const _LspLaunchSpec(executable: 'dart', args: ['language-server']),
        ];
        for (final path in _flutterBundledDartExecutables()) {
          candidates.add(
            _LspLaunchSpec(
              executable: path,
              args: const ['language-server', '--protocol=lsp'],
            ),
          );
        }
        return candidates;
      case 'javascript':
      case 'typescript':
        return const [
          _LspLaunchSpec(
            executable: 'typescript-language-server.cmd',
            args: ['--stdio'],
          ),
          _LspLaunchSpec(
            executable: 'typescript-language-server',
            args: ['--stdio'],
          ),
        ];
      case 'python':
        return const [
          _LspLaunchSpec(
            executable: 'pyright-langserver.cmd',
            args: ['--stdio'],
          ),
          _LspLaunchSpec(executable: 'pyright-langserver', args: ['--stdio']),
          _LspLaunchSpec(executable: 'pylsp'),
          _LspLaunchSpec(executable: 'pylsp.exe'),
          _LspLaunchSpec(executable: 'python', args: ['-m', 'pylsp']),
          _LspLaunchSpec(
            executable: 'python',
            args: ['-m', 'jedi_language_server'],
          ),
        ];
      case 'ruby':
        return const [
          _LspLaunchSpec(executable: 'solargraph', args: ['stdio']),
        ];
      case 'rust':
        return const [_LspLaunchSpec(executable: 'rust-analyzer')];
      case 'go':
        return const [_LspLaunchSpec(executable: 'gopls')];
      case 'java':
        return const [_LspLaunchSpec(executable: 'jdtls')];
      case 'kotlin':
        return const [_LspLaunchSpec(executable: 'kotlin-language-server')];
      case 'swift':
        return const [_LspLaunchSpec(executable: 'sourcekit-lsp')];
      case 'c':
      case 'cpp':
        return const [
          _LspLaunchSpec(executable: 'ccls'),
          _LspLaunchSpec(executable: 'clangd'),
        ];
      case 'csharp':
        return const [
          _LspLaunchSpec(executable: 'omnisharp', args: ['--languageserver']),
        ];
      case 'json':
        return const [
          _LspLaunchSpec(
            executable: 'vscode-json-language-server',
            args: ['--stdio'],
          ),
        ];
      case 'yaml':
        return const [
          _LspLaunchSpec(executable: 'yaml-language-server', args: ['--stdio']),
        ];
      case 'xml':
        return const [_LspLaunchSpec(executable: 'lemminx')];
      case 'css':
      case 'scss':
        return const [
          _LspLaunchSpec(
            executable: 'vscode-css-language-server',
            args: ['--stdio'],
          ),
        ];
      case 'markdown':
        return const [
          _LspLaunchSpec(executable: 'marksman', args: ['server']),
        ];
      case 'sql':
        return const [
          _LspLaunchSpec(
            executable: 'sql-language-server',
            args: ['up', '--method', 'stdio'],
          ),
        ];
      case 'bash':
        return const [
          _LspLaunchSpec(executable: 'bash-language-server', args: ['start']),
        ];
      case 'powershell':
        return const [
          _LspLaunchSpec(
            executable: 'powershell-editor-services',
            args: ['--stdio'],
          ),
        ];
      case 'php':
        return const [
          _LspLaunchSpec(executable: 'intelephense', args: ['--stdio']),
        ];
      case 'lua':
        return const [_LspLaunchSpec(executable: 'lua-language-server')];
      case 'r':
        return const [
          _LspLaunchSpec(
            executable: 'R',
            args: ['--slave', '-e', 'languageserver::run()'],
          ),
        ];
      case 'dockerfile':
        return const [
          _LspLaunchSpec(executable: 'docker-langserver', args: ['--stdio']),
        ];
      case 'makefile':
        return const [_LspLaunchSpec(executable: 'autotools-language-server')];
      default:
        return const [];
    }
  }

  static List<String> _flutterBundledDartExecutables() {
    final result = <String>{};
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null && flutterRoot.isNotEmpty) {
      result.add(
        '$flutterRoot${Platform.pathSeparator}bin${Platform.pathSeparator}cache${Platform.pathSeparator}dart-sdk${Platform.pathSeparator}bin${Platform.pathSeparator}dart.exe',
      );
      result.add(
        '$flutterRoot${Platform.pathSeparator}bin${Platform.pathSeparator}cache${Platform.pathSeparator}dart-sdk${Platform.pathSeparator}bin${Platform.pathSeparator}dart',
      );
    }
    if (Platform.isWindows) {
      final local = Platform.environment['LOCALAPPDATA'];
      if (local != null && local.isNotEmpty) {
        result.add(
          '$local${Platform.pathSeparator}Programs${Platform.pathSeparator}Flutter${Platform.pathSeparator}bin${Platform.pathSeparator}cache${Platform.pathSeparator}dart-sdk${Platform.pathSeparator}bin${Platform.pathSeparator}dart.exe',
        );
      }
    }
    return result.where((p) => File(p).existsSync()).toList(growable: false);
  }

  static String _inferWorkspacePath(String filePath) {
    var dir = File(filePath).parent;
    final fallback = dir;
    while (true) {
      if (File(
        '${dir.path}${Platform.pathSeparator}pubspec.yaml',
      ).existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return fallback.path;
  }
}

class CodeLspDiagnostic {
  const CodeLspDiagnostic({
    required this.severity,
    required this.message,
    required this.startLine,
    required this.startCharacter,
    required this.endLine,
    required this.endCharacter,
  });

  final int severity;
  final String message;
  final int startLine;
  final int startCharacter;
  final int endLine;
  final int endCharacter;
}

class CodeFindResult {
  const CodeFindResult({required this.matches, required this.index});

  final List<int> matches;
  final int index;
}

class CodeFindOption {
  const CodeFindOption({required this.caseSensitive, required this.regex});

  final bool caseSensitive;
  final bool regex;
}

class CodeFindValue {
  const CodeFindValue({
    required this.replaceMode,
    required this.result,
    required this.option,
  });

  final bool replaceMode;
  final CodeFindResult result;
  final CodeFindOption option;
}

class CodeFindController extends ValueNotifier<CodeFindValue?> {
  CodeFindController(CodeLineEditingController editing)
    : _inner = FindController(editing.delegate),
      super(null) {
    _inner.addListener(_syncState);
    _syncState();
  }

  final FindController _inner;

  TextEditingController get findInputController => _inner.findInputController;
  TextEditingController get replaceInputController =>
      _inner.replaceInputController;
  FocusNode get findInputFocusNode => _inner.findInputFocusNode;
  FocusNode get replaceInputFocusNode => _inner.replaceInputFocusNode;

  void findMode() {
    _inner.isActive = true;
    _inner.isReplaceMode = false;
    _syncState();
  }

  void replaceMode() {
    _inner.isActive = true;
    _inner.isReplaceMode = true;
    _syncState();
  }

  void toggleMode() {
    _inner.toggleReplaceMode();
    _syncState();
  }

  void toggleCaseSensitive() {
    _inner.toggleCaseSensitive();
    _syncState();
  }

  void toggleRegex() {
    _inner.toggleRegex();
    _syncState();
  }

  void nextMatch() {
    _inner.next();
    _syncState();
  }

  void previousMatch() {
    _inner.previous();
    _syncState();
  }

  void replaceMatch() {
    _inner.replace();
    _syncState();
  }

  void replaceAllMatches() {
    _inner.replaceAll();
    _syncState();
  }

  void close() {
    _inner.isActive = false;
    _syncState();
  }

  void _syncState() {
    if (!_inner.isActive) {
      value = null;
      return;
    }
    value = CodeFindValue(
      replaceMode: _inner.isReplaceMode,
      result: CodeFindResult(
        matches: List<int>.filled(_inner.matchCount, 0),
        index: _inner.currentMatchIndex,
      ),
      option: CodeFindOption(
        caseSensitive: _inner.caseSensitive,
        regex: _inner.isRegex,
      ),
    );
  }

  @override
  void dispose() {
    _inner.removeListener(_syncState);
    _inner.dispose();
    super.dispose();
  }
}

class CodeHighlightThemeMode {
  const CodeHighlightThemeMode({required this.mode});

  final Mode mode;
}

class CodeHighlightTheme {
  const CodeHighlightTheme({required this.languages, required this.theme});

  final Map<String, CodeHighlightThemeMode> languages;
  final Map<String, TextStyle> theme;
}

class CodeEditorStyle {
  const CodeEditorStyle({
    required this.fontSize,
    required this.fontFamily,
    required this.backgroundColor,
    required this.selectionColor,
    required this.highlightColor,
    required this.cursorLineColor,
    required this.textColor,
    required this.chunkIndicatorColor,
    required this.codeTheme,
  });

  final double fontSize;
  final String fontFamily;
  final Color backgroundColor;
  final Color selectionColor;
  final Color highlightColor;
  final Color cursorLineColor;
  final Color textColor;
  final Color chunkIndicatorColor;
  final CodeHighlightTheme codeTheme;
}

class CodeIndicatorValue {
  const CodeIndicatorValue({required this.paragraphs});

  final List<CodeLineRenderParagraph> paragraphs;
}

class CodeIndicatorValueNotifier extends ValueNotifier<CodeIndicatorValue?> {
  CodeIndicatorValueNotifier() : super(null);
}

class CodeLineRenderParagraph {
  CodeLineRenderParagraph({
    required this.index,
    required this.top,
    required this.height,
  }) : preferredLineHeight = height,
       offset = Offset(0, top);

  final int index;
  final double top;
  final double height;
  final double preferredLineHeight;
  final Offset offset;
}

class CodeChunk {
  const CodeChunk({required this.index, required this.end});

  final int index;
  final int end;
}

abstract class CodeChunkAnalyzer {
  const CodeChunkAnalyzer();

  List<CodeChunk> run(CodeLines codeLines);
}

class DefaultCodeChunkAnalyzer implements CodeChunkAnalyzer {
  const DefaultCodeChunkAnalyzer();

  @override
  List<CodeChunk> run(CodeLines codeLines) => const [];
}

class DefaultCodeChunkIndicatorPainter {
  const DefaultCodeChunkIndicatorPainter({required this.color});

  final Color color;
}

class DefaultCodeLineNumber extends StatelessWidget {
  const DefaultCodeLineNumber({
    super.key,
    required this.controller,
    required this.notifier,
    required this.textStyle,
  });

  final CodeLineEditingController controller;
  final CodeIndicatorValueNotifier notifier;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class DefaultCodeChunkIndicator extends StatelessWidget {
  const DefaultCodeChunkIndicator({
    super.key,
    required this.width,
    required this.controller,
    required this.notifier,
    required this.painter,
  });

  final double width;
  final Object? controller;
  final CodeIndicatorValueNotifier notifier;
  final DefaultCodeChunkIndicatorPainter painter;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

enum CodeShortcutType { lineDelete }

abstract class CodeShortcutsActivatorsBuilder {
  const CodeShortcutsActivatorsBuilder();

  List<ShortcutActivator>? build(CodeShortcutType type);
}

class DefaultCodeShortcutsActivatorsBuilder
    extends CodeShortcutsActivatorsBuilder {
  const DefaultCodeShortcutsActivatorsBuilder();

  @override
  List<ShortcutActivator>? build(CodeShortcutType type) => null;
}

class CodeShortcutCommentIntent extends Intent {
  const CodeShortcutCommentIntent(this.isLineComment);

  final bool isLineComment;
}

class CodeEditor extends StatefulWidget {
  const CodeEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.autofocus,
    required this.readOnly,
    required this.showCursorWhenReadOnly,
    required this.findController,
    required this.scrollController,
    required this.style,
    required this.wordWrap,
    required this.autocompleteSymbols,
    this.disableCodeForgeShortcuts = false,
    this.filePath,
    this.chunkAnalyzer,
    this.shortcutsActivatorsBuilder,
    this.indicatorBuilder,
    this.findBuilder,
  });

  final CodeLineEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final bool readOnly;
  final bool showCursorWhenReadOnly;
  final CodeFindController? findController;
  final CodeScrollController? scrollController;
  final CodeEditorStyle style;
  final bool wordWrap;
  final bool autocompleteSymbols;
  final bool disableCodeForgeShortcuts;
  final String? filePath;
  final CodeChunkAnalyzer? chunkAnalyzer;
  final CodeShortcutsActivatorsBuilder? shortcutsActivatorsBuilder;
  final Widget Function(
    BuildContext context,
    CodeLineEditingController editingController,
    Object? chunkController,
    CodeIndicatorValueNotifier notifier,
  )?
  indicatorBuilder;
  final PreferredSizeWidget Function(
    BuildContext context,
    CodeFindController controller,
    bool readOnly,
  )?
  findBuilder;

  @override
  State<CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends State<CodeEditor> {
  final CodeIndicatorValueNotifier _indicatorNotifier =
      CodeIndicatorValueNotifier();

  @override
  Widget build(BuildContext context) {
    Mode? mode;
    if (widget.style.codeTheme.languages.isNotEmpty) {
      mode = widget.style.codeTheme.languages.values.first.mode;
    }

    final find = widget.findController;
    final theme = _resolvedEditorTheme();

    return Stack(
      children: [
        CodeForge(
          controller: widget.controller.delegate,
          undoController: widget.controller.undoController,
          filePath: widget.filePath,
          findController: find?._inner,
          focusNode: widget.focusNode,
          autoFocus: widget.autofocus,
          readOnly: widget.readOnly,
          lineWrap: widget.wordWrap,
          language: mode,
          editorTheme: theme,
          textStyle: TextStyle(
            fontFamily: widget.style.fontFamily,
            fontSize: widget.style.fontSize,
            color: widget.style.textColor,
          ),
          verticalScrollController: widget.scrollController?.verticalScroller,
          horizontalScrollController:
              widget.scrollController?.horizontalScroller,
          selectionStyle: CodeSelectionStyle(
            selectionColor: widget.style.selectionColor,
            cursorColor: widget.style.textColor,
            cursorBubbleColor: widget.style.textColor,
          ),
          suggestionStyle: _buildSuggestionStyle(),
          hoverDetailsStyle: _buildHoverStyle(),
          gutterStyle: GutterStyle(
            lineNumberStyle: TextStyle(
              fontFamily: widget.style.fontFamily,
              fontSize: widget.style.fontSize,
              color: widget.style.chunkIndicatorColor,
            ),
            activeLineNumberColor: widget.style.chunkIndicatorColor,
            inactiveLineNumberColor: widget.style.chunkIndicatorColor,
            backgroundColor: widget.style.backgroundColor,
          ),
          enableFolding: true,
          enableGuideLines: true,
          enableEditorShortcuts: !widget.disableCodeForgeShortcuts,
          finderBuilder:
              (context, _) =>
                  widget.findBuilder?.call(context, find!, widget.readOnly) ??
                  const _EmptyPreferredSize(),
        ),
        if (widget.indicatorBuilder != null)
          Positioned(
            left: 0,
            top: 0,
            child: widget.indicatorBuilder!(
              context,
              widget.controller,
              null,
              _indicatorNotifier,
            ),
          ),
      ],
    );
  }

  Map<String, TextStyle> _resolvedEditorTheme() {
    final base = Map<String, TextStyle>.from(widget.style.codeTheme.theme);
    final root = base['root'] ?? const TextStyle();
    base['root'] = root.copyWith(
      backgroundColor: widget.style.backgroundColor,
      color: widget.style.textColor,
    );
    return base;
  }

  SuggestionStyle _buildSuggestionStyle() {
    final fg = widget.style.textColor;
    final bg = widget.style.backgroundColor.withValues(alpha: 0.98);
    final border = widget.style.chunkIndicatorColor.withValues(alpha: 0.35);
    final focus = widget.style.selectionColor.withValues(alpha: 0.16);
    return SuggestionStyle(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      backgroundColor: bg,
      focusColor: focus,
      hoverColor: widget.style.selectionColor.withValues(alpha: 0.1),
      splashColor: widget.style.selectionColor.withValues(alpha: 0.14),
      textStyle: TextStyle(
        fontFamily: widget.style.fontFamily,
        fontSize: (widget.style.fontSize - 1).clamp(10.0, 18.0),
        color: fg,
      ),
      selectedBackgroundColor: focus,
      borderColor: border,
      borderWidth: 1,
      itemHeight: (widget.style.fontSize + 7).clamp(18.0, 24.0),
      iconSize: (widget.style.fontSize - 1).clamp(11.0, 15.0),
      labelTextStyle: TextStyle(
        fontFamily: widget.style.fontFamily,
        fontSize: (widget.style.fontSize - 1).clamp(10.0, 18.0),
        color: fg,
      ),
      detailTextStyle: TextStyle(
        fontFamily: widget.style.fontFamily,
        fontSize: (widget.style.fontSize - 2).clamp(9.0, 16.0),
        color: fg.withValues(alpha: 0.72),
      ),
      typeTextStyle: TextStyle(
        fontFamily: widget.style.fontFamily,
        fontSize: (widget.style.fontSize - 2).clamp(9.0, 16.0),
        color: fg.withValues(alpha: 0.8),
      ),
    );
  }

  HoverDetailsStyle _buildHoverStyle() {
    final fg = widget.style.textColor;
    return HoverDetailsStyle(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: widget.style.chunkIndicatorColor.withValues(alpha: 0.26),
        ),
      ),
      backgroundColor: widget.style.backgroundColor.withValues(alpha: 0.985),
      focusColor: widget.style.selectionColor.withValues(alpha: 0.24),
      hoverColor: widget.style.selectionColor.withValues(alpha: 0.14),
      splashColor: widget.style.selectionColor.withValues(alpha: 0.2),
      textStyle: TextStyle(
        fontFamily: widget.style.fontFamily,
        fontSize: (widget.style.fontSize - 1).clamp(10.0, 16.0),
        color: fg,
        height: 1.35,
      ),
    );
  }
}

class _LspLaunchSpec {
  const _LspLaunchSpec({required this.executable, this.args = const []});

  final String executable;
  final List<String> args;
}

class _SharedLspEntry {
  _SharedLspEntry({required this.config});

  final LspConfig config;
  int refCount = 0;
}

class _LspLease {
  const _LspLease({required this.config, required this.release});

  final LspConfig config;
  final VoidCallback release;
}

class _EmptyPreferredSize extends SizedBox implements PreferredSizeWidget {
  const _EmptyPreferredSize() : super.shrink();

  @override
  Size get preferredSize => Size.zero;
}
