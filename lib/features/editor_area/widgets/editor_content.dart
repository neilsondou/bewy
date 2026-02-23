import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bewy/core/editor/re_editor_compat.dart';
import 'package:re_highlight/languages/all.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import '../../../core/theme/app_font_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/context_menu.dart';
import '../../../features/status_bar/presentation/status_info_provider.dart';
import '../models/editor_tab_model.dart';
import '../presentation/editor_area_provider.dart';
import '../presentation/editor_settings_provider.dart';
import 'bracket_match_painter.dart';
import 'find_panel.dart';
import 'indent_guide_painter.dart';
import 'minimap_widget.dart';

class EditorContent extends ConsumerStatefulWidget {
  const EditorContent({required super.key, required this.tab});

  final EditorTabModel tab;

  @override
  ConsumerState<EditorContent> createState() => _EditorContentState();
}

class _EditorContentState extends ConsumerState<EditorContent> {
  static const bool _layerDebugEnabled = false;
  static const int _kLargeFileLineThreshold = 10000;
  static const int _kMinimapDisableLineThreshold = 8000;
  static const int _kEmptyScanMaxLines = 600;
  static const int _kEncodingProbeBytes = 256 * 1024;
  static final RegExp _invisibleChars = RegExp(
    r'[\s\u200B\u200C\u200D\uFEFF]+',
  );

  CodeLineEditingController? _controller;
  CodeFindController? _findController;
  CodeScrollController? _scrollController;
  bool _findActive = false;
  int _consecutivePrimaryTapCount = 0;
  DateTime? _lastPrimaryTapAt;
  late final FocusNode _editorFocusNode;

  // For indent guides and current line overlay
  CodeIndicatorValueNotifier? _reEditorNotifier;
  final ValueNotifier<CodeIndicatorValue?> _paragraphNotifier = ValueNotifier(
    null,
  );
  // Separate notifier for the focused line so highlight reacts instantly
  final ValueNotifier<int> _focusedLineNotifier = ValueNotifier(-1);
  // Bracket match positions
  final ValueNotifier<(int, int, int, int)?> _bracketMatchNotifier =
      ValueNotifier(null);
  bool _hasVisibleText = true;
  CodeLspDiagnostic? _hoveredDiagnostic;
  Offset? _hoverPosition;

  void _onControllerChanged() {
    ref.read(editorAreaProvider.notifier).notifyContentChanged(widget.tab.id);
    _refreshVisibleText();
    _updateCursorInfo();
    _updateFocusedLine();
    _updateBracketMatch();
  }

  void _updateFocusedLine() {
    if (_controller == null) return;
    try {
      final idx = _controller!.selection.extentIndex;
      if (_focusedLineNotifier.value != idx) {
        _focusedLineNotifier.value = idx;
      }
    } catch (_) {}
  }

  void _updateBracketMatch() {
    if (_controller == null) return;
    if (_controller!.lineCount >= _kLargeFileLineThreshold) {
      _bracketMatchNotifier.value = null;
      return;
    }
    try {
      final result = BracketMatchPainter.findBracketMatch(
        _controller!.codeLines,
        _controller!.selection.extentIndex,
        _controller!.selection.extentOffset,
      );
      _bracketMatchNotifier.value = result;
    } catch (_) {
      _bracketMatchNotifier.value = null;
    }
  }

  void _updateCursorInfo() {
    if (_controller == null) return;
    try {
      final sel = _controller!.selection;
      int selectedChars = 0;
      int selectedLines = 0;
      if (!sel.isCollapsed) {
        selectedChars = _controller!.selectedText.length;
        selectedLines = (sel.endIndex - sel.startIndex + 1);
      }
      ref
          .read(statusInfoProvider.notifier)
          .update(
            line: sel.extentIndex + 1,
            column: sel.extentOffset + 1,
            selectedChars: selectedChars,
            selectedLines: selectedLines,
          );
    } catch (_) {}
  }

  void _onFindValueChanged() {
    final active = _findController?.value != null;
    if (active != _findActive) {
      setState(() => _findActive = active);
    }
  }

  void _onParagraphsChanged() {
    // Defer to post-frame to avoid "Build scheduled during frame" since
    // re_editor fires this callback during performLayout.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hadParagraph = _paragraphNotifier.value != null;
      final next = _reEditorNotifier?.value;
      _paragraphNotifier.value = next;
      final hasParagraph = next != null;
      // Rebuild the outer layout so minimap visibility can update immediately.
      if (hadParagraph != hasParagraph) {
        setState(() {});
      }
    });
  }

  void _onHorizontalScroll() {
    // Trigger repaint of indent guides when horizontal scroll changes
    final current = _paragraphNotifier.value;
    if (current != null) {
      // Force a new notification by creating a copy
      _paragraphNotifier.value = null;
      _paragraphNotifier.value = current;
    }
  }

  @override
  void initState() {
    super.initState();
    _editorFocusNode = FocusNode();
    final notifier = ref.read(editorAreaProvider.notifier);
    _controller = notifier.getController(widget.tab.id);
    _findController = notifier.getFindController(widget.tab.id);
    _scrollController = CodeScrollController();
    _findController?.addListener(_onFindValueChanged);
    _scrollController!.horizontalScroller.addListener(_onHorizontalScroll);
    // Listen immediately for selection changes (cursor line highlight)
    _controller?.addListener(_updateFocusedLine);

    final lang = _getLanguageForFile(widget.tab.fileName);
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(statusInfoProvider.notifier)
          .update(language: _getLanguageDisplayName(lang));
    });

    _detectLineEnding();
    _detectEncoding();
    _refreshVisibleText();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(editorAreaProvider.notifier).snapshotSavedContent(widget.tab.id);
      _controller?.addListener(_onControllerChanged);
      _updateCursorInfo();
    });
  }

  void _detectLineEnding() {
    if (widget.tab.filePath == null) return;
    () async {
      try {
        final file = File(widget.tab.filePath!);
        final stat = await file.stat();
        final maxBytes =
            stat.size > _kEncodingProbeBytes ? _kEncodingProbeBytes : stat.size;
        final bytes = await file
            .openRead(0, maxBytes)
            .fold<List<int>>(<int>[], (prev, chunk) => prev..addAll(chunk));
        if (!mounted) return;
        final raw = String.fromCharCodes(bytes);
        final le = raw.contains('\r\n') ? 'CRLF' : 'LF';
        ref.read(statusInfoProvider.notifier).update(lineEnding: le);
      } catch (_) {}
    }();
  }

  void _detectEncoding() {
    if (widget.tab.filePath == null) return;
    () async {
      try {
        final file = File(widget.tab.filePath!);
        final stat = await file.stat();
        final maxBytes =
            stat.size > _kEncodingProbeBytes ? _kEncodingProbeBytes : stat.size;
        final bytes = await file
            .openRead(0, maxBytes)
            .fold<List<int>>(<int>[], (prev, chunk) => prev..addAll(chunk));
        if (!mounted) return;
        final defaultEncoding =
            ref.read(editorSettingsProvider).defaultFileEncoding;
        String encoding = 'UTF-8';
        if (bytes.length >= 3 &&
            bytes[0] == 0xEF &&
            bytes[1] == 0xBB &&
            bytes[2] == 0xBF) {
          encoding = 'UTF-8 with BOM';
        } else if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
          encoding = 'UTF-16 LE';
        } else if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
          encoding = 'UTF-16 BE';
        } else {
          try {
            utf8.decode(bytes);
            encoding = 'UTF-8';
          } catch (_) {
            if (_looksLikeGbk(bytes)) {
              encoding = 'GBK';
            } else {
              switch (defaultEncoding) {
                case FileEncodingOption.utf8:
                  encoding = 'UTF-8';
                case FileEncodingOption.utf8bom:
                  encoding = 'UTF-8 with BOM';
                case FileEncodingOption.gbk:
                  encoding = 'GBK';
                case FileEncodingOption.gb18030:
                  encoding = 'GB18030';
              }
            }
          }
        }
        ref.read(statusInfoProvider.notifier).update(encoding: encoding);
      } catch (_) {}
    }();
  }

  /// Simple heuristic: check if bytes form valid GBK double-byte sequences.
  bool _looksLikeGbk(List<int> bytes) {
    int i = 0;
    int dbCount = 0;
    while (i < bytes.length) {
      final b = bytes[i];
      if (b <= 0x7F) {
        i++;
      } else if (b >= 0x81 && b <= 0xFE && i + 1 < bytes.length) {
        final b2 = bytes[i + 1];
        if ((b2 >= 0x40 && b2 <= 0x7E) || (b2 >= 0x80 && b2 <= 0xFE)) {
          dbCount++;
          i += 2;
        } else {
          return false;
        }
      } else {
        return false;
      }
    }
    return dbCount > 0;
  }

  @override
  void dispose() {
    _editorFocusNode.dispose();
    _controller?.removeListener(_onControllerChanged);
    _controller?.removeListener(_updateFocusedLine);
    _findController?.removeListener(_onFindValueChanged);
    _reEditorNotifier?.removeListener(_onParagraphsChanged);
    _scrollController?.horizontalScroller.removeListener(_onHorizontalScroll);
    _scrollController?.dispose();
    _paragraphNotifier.dispose();
    _focusedLineNotifier.dispose();
    _bracketMatchNotifier.dispose();
    super.dispose();
  }

  void _showEditorContextMenu(BuildContext context, Offset position) {
    final controller = _controller;
    if (controller == null) return;
    final hasSelection = controller.selectedText.isNotEmpty;

    showAppContextMenu(context, position, [
      ContextMenuItem(
        label: context.tr('menu.cut'),
        shortcut: 'Ctrl+X',
        onTap: hasSelection ? () => controller.cut() : null,
      ),
      ContextMenuItem(
        label: context.tr('menu.copy'),
        shortcut: 'Ctrl+C',
        onTap: hasSelection ? () => controller.copy() : null,
      ),
      ContextMenuItem(
        label: context.tr('menu.paste'),
        shortcut: 'Ctrl+V',
        onTap: () => controller.paste(),
      ),
      const ContextMenuSeparator(),
      ContextMenuItem(
        label: context.tr('menu.selectAll'),
        shortcut: 'Ctrl+A',
        onTap: () => controller.selectAll(),
      ),
      const ContextMenuSeparator(),
      ContextMenuItem(
        label: context.tr('menu.undo'),
        shortcut: 'Ctrl+Z',
        onTap: () => controller.undo(),
      ),
      ContextMenuItem(
        label: context.tr('menu.redo'),
        shortcut: 'Ctrl+Y',
        onTap: () => controller.redo(),
      ),
      const ContextMenuSeparator(),
      ContextMenuItem(
        label: context.tr('editor.toggleLineComment'),
        shortcut: 'Ctrl+/',
        onTap:
            () =>
                Actions.invoke(context, const CodeShortcutCommentIntent(true)),
      ),
      ContextMenuItem(
        label: context.tr('editor.toggleBlockComment'),
        shortcut: 'Ctrl+Shift+/',
        onTap:
            () =>
                Actions.invoke(context, const CodeShortcutCommentIntent(false)),
      ),
      const ContextMenuSeparator(),
      ContextMenuItem(
        label: context.tr('menu.find'),
        shortcut: 'Ctrl+F',
        onTap: () => _findController?.findMode(),
      ),
      ContextMenuItem(
        label: context.tr('menu.replace'),
        shortcut: 'Ctrl+H',
        onTap: () => _findController?.replaceMode(),
      ),
    ]);
  }

  void _selectCurrentLine() {
    final controller = _controller;
    if (controller == null || controller.lineCount == 0) return;
    final lineIndex = controller.selection.extentIndex.clamp(
      0,
      controller.lineCount - 1,
    );
    final lineLength = controller.codeLines[lineIndex].text.length;
    controller.selection = CodeLineSelection(
      baseIndex: lineIndex,
      baseOffset: 0,
      extentIndex: lineIndex,
      extentOffset: lineLength,
    );
  }

  bool _isVisuallyEmptyFile() {
    return !_hasVisibleText;
  }

  void _refreshVisibleText() {
    final controller = _controller;
    if (controller == null || controller.lineCount == 0) {
      _hasVisibleText = false;
      return;
    }
    final total = controller.lineCount;
    final maxScan = total > _kEmptyScanMaxLines ? _kEmptyScanMaxLines : total;

    bool hasVisible = false;
    for (int i = 0; i < maxScan; i++) {
      final compact = controller.codeLines[i].text.replaceAll(
        _invisibleChars,
        '',
      );
      if (compact.isNotEmpty) {
        hasVisible = true;
        break;
      }
    }

    if (!hasVisible && total > _kEmptyScanMaxLines) {
      // For very large files avoid scanning all lines each change.
      for (int i = total - maxScan; i < total; i++) {
        final compact = controller.codeLines[i].text.replaceAll(
          _invisibleChars,
          '',
        );
        if (compact.isNotEmpty) {
          hasVisible = true;
          break;
        }
      }
      // If still unknown after sampled scan, assume non-empty to keep UI responsive.
      if (!hasVisible) hasVisible = true;
    }

    _hasVisibleText = hasVisible;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(editorAreaProvider);
    if (_controller == null) {
      return Container(color: AppColors.editorBackground);
    }

    final settings = ref.watch(editorSettingsProvider);
    final diagnostics = _resolveDiagnosticsForHover();
    final lineCount = _controller!.lineCount;
    final isLargeFile = lineCount >= _kLargeFileLineThreshold;
    final isVisuallyEmpty = _isVisuallyEmptyFile();
    final editorFontFamily = AppFontCatalog.resolveEditorFontFamily(
      settings.editorFontFamily,
    );
    final readOnly = ref
        .read(editorAreaProvider.notifier)
        .isTabReadOnly(widget.tab.id);

    final showMinimap =
        settings.showMinimap &&
        _scrollController != null &&
        !isVisuallyEmpty &&
        lineCount > 0 &&
        lineCount < _kMinimapDisableLineThreshold;

    final style = CodeEditorStyle(
      fontSize: settings.fontSize,
      fontFamily: editorFontFamily,
      backgroundColor: AppColors.editorBackground,
      selectionColor:
          isVisuallyEmpty
              ? Colors.transparent
              : AppColors.editorSelectionBackground,
      highlightColor:
          isVisuallyEmpty
              ? Colors.transparent
              : AppColors.editorSelectionBackground,
      cursorLineColor:
          isVisuallyEmpty ? Colors.transparent : AppColors.editorCursorLine,
      textColor: AppColors.editorForeground,
      chunkIndicatorColor: AppColors.lineNumber,
      codeTheme: CodeHighlightTheme(
        languages: isLargeFile ? const {} : _buildLanguageMap(),
        theme: atomOneDarkTheme,
      ),
    );

    return Container(
      color: AppColors.editorBackground,
      child: MouseRegion(
        onExit: (_) {
          if (_hoveredDiagnostic != null || _hoverPosition != null) {
            setState(() {
              _hoveredDiagnostic = null;
              _hoverPosition = null;
            });
          }
        },
        onHover: (event) {
          final value = _paragraphNotifier.value;
          if (value == null || _controller == null) return;
          final match = _diagnosticAtOffset(
            localPosition: event.localPosition,
            paragraphs: value.paragraphs,
            diagnostics: diagnostics,
            fontSize: settings.fontSize,
            fontFamily: editorFontFamily,
            letterSpacing: settings.editorLetterSpacing,
          );
          if (match == null) {
            if (_hoveredDiagnostic == null && _hoverPosition == null) {
              return;
            }
            setState(() {
              _hoveredDiagnostic = null;
              _hoverPosition = null;
            });
            return;
          }
          if (match != _hoveredDiagnostic || _hoverPosition == null) {
            setState(() {
              _hoveredDiagnostic = match;
              _hoverPosition = event.localPosition;
            });
          }
        },
        child: Stack(
          children: [
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                if (!_editorFocusNode.hasFocus) {
                  _editorFocusNode.requestFocus();
                }
                if (_layerDebugEnabled) {
                  debugPrint(
                    '[EditorLayerDebug] '
                    'down=${event.position} '
                    'empty=$isVisuallyEmpty '
                    'focus=${_editorFocusNode.hasFocus} '
                    'find=$_findActive '
                    'paragraph=${_paragraphNotifier.value != null} '
                    'minimap=$showMinimap',
                  );
                }
                if (event.buttons == kSecondaryButton) {
                  _showEditorContextMenu(context, event.position);
                  return;
                }
                if (event.buttons != kPrimaryButton) return;
                final now = DateTime.now();
                final last = _lastPrimaryTapAt;
                _lastPrimaryTapAt = now;
                if (last != null &&
                    now.difference(last) <= const Duration(milliseconds: 350)) {
                  _consecutivePrimaryTapCount++;
                } else {
                  _consecutivePrimaryTapCount = 1;
                }
                if (_consecutivePrimaryTapCount >= 3) {
                  _consecutivePrimaryTapCount = 0;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _selectCurrentLine();
                  });
                }
              },
              child: CodeEditor(
                controller: _controller!,
                filePath: widget.tab.filePath,
                focusNode: _editorFocusNode,
                autofocus: true,
                readOnly: readOnly,
                showCursorWhenReadOnly: true,
                findController: _findController,
                scrollController: _scrollController,
                style: style,
                wordWrap: settings.wordWrap,
                autocompleteSymbols: settings.autoPairSymbols,
                disableCodeForgeShortcuts: settings.disableCodeForgeShortcuts,
                chunkAnalyzer: _MaxLinesChunkAnalyzer(
                  maxFoldableLines: settings.codeFoldingMaxLines,
                  disableFoldLineThreshold: _kLargeFileLineThreshold,
                ),
                shortcutsActivatorsBuilder:
                    const _BewyShortcutsActivatorsBuilder(),
                indicatorBuilder: (
                  context,
                  editingController,
                  chunkController,
                  notifier,
                ) {
                  // Capture the re_editor notifier for the overlay
                  if (_reEditorNotifier != notifier) {
                    _reEditorNotifier?.removeListener(_onParagraphsChanged);
                    _reEditorNotifier = notifier;
                    _reEditorNotifier!.addListener(_onParagraphsChanged);
                  }
                  return Row(
                    children: [
                      DefaultCodeLineNumber(
                        controller: editingController,
                        notifier: notifier,
                        textStyle: TextStyle(
                          fontFamily: editorFontFamily,
                          fontSize: settings.fontSize,
                          letterSpacing: settings.editorLetterSpacing,
                          color: AppColors.lineNumber,
                        ),
                      ),
                      DefaultCodeChunkIndicator(
                        width: 20,
                        controller: chunkController,
                        notifier: notifier,
                        painter: DefaultCodeChunkIndicatorPainter(
                          color: AppColors.lineNumber,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  );
                },
                findBuilder:
                    _findActive
                        ? (context, controller, readOnly) => _FloatingFindPanel(
                          rightInset:
                              showMinimap ? (MinimapWidget.width + 18.0) : 8.0,
                          widthFactor: 0.25,
                          controller: controller,
                          readOnly: readOnly,
                        )
                        : null,
              ),
            ),
            // Indent guide and current line highlight overlay
            IgnorePointer(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  _paragraphNotifier,
                  _focusedLineNotifier,
                  _bracketMatchNotifier,
                ]),
                builder: (context, _) {
                  final value = _paragraphNotifier.value;
                  if (value == null || _controller == null) {
                    return const SizedBox.shrink();
                  }
                  if (_isVisuallyEmptyFile()) {
                    return const SizedBox.shrink();
                  }
                  final indicatorWidth = IndentGuidePainter.measureIndicatorWidth(
                    _controller!.lineCount,
                    settings.fontSize,
                    editorFontFamily,
                    settings.editorLetterSpacing,
                    24.0, // line number gap + chunk indicator width + SizedBox
                  );
                  final hOffset =
                      _scrollController?.horizontalScroller.hasClients == true
                          ? _scrollController!.horizontalScroller.offset
                          : 0.0;
                  return CustomPaint(
                    size: Size.infinite,
                    painter:
                        settings.showIndentGuides
                            ? IndentGuidePainter(
                              paragraphs: value.paragraphs,
                              focusedIndex: _focusedLineNotifier.value,
                              hasVisibleText: _hasVisibleText,
                              lineTextByIndex: {
                                for (final p in value.paragraphs)
                                  p.index: _controller!.codeLines[p.index].text,
                              },
                              fontSize: settings.fontSize,
                              fontFamily: editorFontFamily,
                              letterSpacing: settings.editorLetterSpacing,
                              indicatorWidth: indicatorWidth,
                              horizontalOffset: hOffset,
                              tabSize: settings.indentSize,
                            )
                            : null,
                    foregroundPainter: _CombinedOverlayPainter(
                      diffPainter: null,
                      bracketPainter: BracketMatchPainter(
                        paragraphs: value.paragraphs,
                        bracketMatch: _bracketMatchNotifier.value,
                        fontSize: settings.fontSize,
                        indicatorWidth: indicatorWidth,
                        horizontalOffset: hOffset,
                      ),
                    ),
                  );
                },
              ),
            ),
            // Minimap overlay 閳?to the left of the scrollbar
            if (showMinimap)
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: MinimapWidget(
                  controller: _controller!,
                  scrollController: _scrollController!,
                  focusedLineNotifier: _focusedLineNotifier,
                  diagnostics: diagnostics,
                ),
              ),
            if (_scrollController != null && _controller != null)
              Positioned(
                right: 2,
                top: 0,
                bottom: 0,
                child: _DiagnosticScrollbar(
                  scrollController: _scrollController!.verticalScroller,
                  lineCount: _controller!.lineCount,
                  diagnostics: diagnostics,
                ),
              ),
            if (_hoveredDiagnostic != null && _hoverPosition != null)
              Positioned(
                left: (_hoverPosition!.dx + 10).clamp(8.0, 9000.0),
                top: (_hoverPosition!.dy + 14).clamp(8.0, 9000.0),
                child: _DiagnosticHoverPanel(diagnostic: _hoveredDiagnostic!),
              ),
            if (_layerDebugEnabled)
              _LayerDebugHud(
                isVisuallyEmpty: isVisuallyEmpty,
                hasFocus: _editorFocusNode.hasFocus,
                findActive: _findActive,
                hasParagraph: _paragraphNotifier.value != null,
                showMinimap: showMinimap,
              ),
          ],
        ),
      ),
    );
  }

  List<CodeLspDiagnostic> _resolveDiagnosticsForHover() {
    final controller = _controller;
    final path = widget.tab.filePath;
    if (controller == null || path == null) return const <CodeLspDiagnostic>[];
    final fromController = controller.diagnostics;
    if (fromController.isNotEmpty) {
      return List<CodeLspDiagnostic>.from(fromController);
    }
    return ref.read(editorAreaProvider.notifier).diagnosticsForFile(path);
  }

  CodeLspDiagnostic? _diagnosticAtOffset({
    required Offset localPosition,
    required List<CodeLineRenderParagraph> paragraphs,
    required List<CodeLspDiagnostic> diagnostics,
    required double fontSize,
    required String fontFamily,
    required double letterSpacing,
  }) {
    if (diagnostics.isEmpty || _controller == null) return null;
    final lineParagraph =
        paragraphs
            .where(
              (p) =>
                  localPosition.dy >= p.top &&
                  localPosition.dy <= (p.top + p.height + 2),
            )
            .firstOrNull;
    if (lineParagraph == null) return null;
    final indicatorWidth = IndentGuidePainter.measureIndicatorWidth(
      _controller!.lineCount,
      fontSize,
      fontFamily,
      letterSpacing,
      24.0,
    );
    final hOffset =
        _scrollController?.horizontalScroller.hasClients == true
            ? _scrollController!.horizontalScroller.offset
            : 0.0;
    final charWidth = _measureCharWidth(fontSize, fontFamily, letterSpacing);
    final col =
        ((localPosition.dx - indicatorWidth + hOffset) / charWidth).floor();
    CodeLspDiagnostic? sameLineFirst;
    for (final d in diagnostics) {
      if (d.startLine != lineParagraph.index) continue;
      sameLineFirst ??= d;
      final start = d.startCharacter;
      final end = d.endCharacter > start ? d.endCharacter : (start + 1);
      if (col >= start && col <= end) return d;
    }
    // Fallback: in some fonts/layouts, column mapping is not exact.
    // If pointer is on a line that has diagnostics, show the first issue.
    return sameLineFirst;
  }

  double _measureCharWidth(
    double fontSize,
    String fontFamily,
    double letterSpacing,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: '0',
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          letterSpacing: letterSpacing,
          height: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final width = tp.width;
    tp.dispose();
    return width;
  }

  Map<String, CodeHighlightThemeMode> _buildLanguageMap() {
    final map = <String, CodeHighlightThemeMode>{};
    final lang = _getLanguageForFile(widget.tab.fileName);
    if (lang != null && builtinAllLanguages.containsKey(lang)) {
      map[lang] = CodeHighlightThemeMode(mode: builtinAllLanguages[lang]!);
    }
    return map;
  }

  static String _getLanguageDisplayName(String? lang) {
    switch (lang) {
      case 'dart':
        return 'Dart';
      case 'javascript':
        return 'JavaScript';
      case 'typescript':
        return 'TypeScript';
      case 'python':
        return 'Python';
      case 'ruby':
        return 'Ruby';
      case 'rust':
        return 'Rust';
      case 'go':
        return 'Go';
      case 'java':
        return 'Java';
      case 'kotlin':
        return 'Kotlin';
      case 'swift':
        return 'Swift';
      case 'c':
        return 'C';
      case 'cpp':
        return 'C++';
      case 'csharp':
        return 'C#';
      case 'json':
        return 'JSON';
      case 'yaml':
        return 'YAML';
      case 'xml':
        return 'XML';
      case 'css':
        return 'CSS';
      case 'scss':
        return 'SCSS';
      case 'markdown':
        return 'Markdown';
      case 'sql':
        return 'SQL';
      case 'bash':
        return 'Shell Script';
      case 'powershell':
        return 'PowerShell';
      case 'ini':
        return 'Properties';
      case 'php':
        return 'PHP';
      case 'lua':
        return 'Lua';
      case 'r':
        return 'R';
      case 'dockerfile':
        return 'Dockerfile';
      case 'makefile':
        return 'Makefile';
      default:
        return 'Plain Text';
    }
  }

  static String? _getLanguageForFile(String fileName) {
    final ext =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
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
        return 'kotlin';
      case 'swift':
        return 'swift';
      case 'c':
        return 'c';
      case 'cpp':
      case 'cc':
      case 'cxx':
      case 'h':
      case 'hpp':
        return 'cpp';
      case 'cs':
        return 'csharp';
      case 'json':
        return 'json';
      case 'yaml':
      case 'yml':
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
      case 'toml':
      case 'ini':
      case 'cfg':
        return 'ini';
      case 'php':
        return 'php';
      case 'lua':
        return 'lua';
      case 'r':
        return 'r';
      case 'dockerfile':
        return 'dockerfile';
      default:
        if (fileName.toLowerCase() == 'dockerfile') return 'dockerfile';
        if (fileName.toLowerCase() == 'makefile') return 'makefile';
        return null;
    }
  }
}

/// Custom shortcuts builder that disables Ctrl+D (lineDelete) to avoid
/// accidental line deletion. We remap line deletion to Ctrl+Shift+K instead.
class _BewyShortcutsActivatorsBuilder extends CodeShortcutsActivatorsBuilder {
  const _BewyShortcutsActivatorsBuilder();

  @override
  List<ShortcutActivator>? build(CodeShortcutType type) {
    if (type == CodeShortcutType.lineDelete) {
      // Remap to Ctrl+Shift+K instead of the default Ctrl+D
      return const [
        SingleActivator(LogicalKeyboardKey.keyK, control: true, shift: true),
      ];
    }
    return const DefaultCodeShortcutsActivatorsBuilder().build(type);
  }
}

/// Renders [FindPanel] as a right-floating compact panel, similar to VS Code.
class _FloatingFindPanel extends StatelessWidget
    implements PreferredSizeWidget {
  const _FloatingFindPanel({
    required this.rightInset,
    required this.widthFactor,
    required this.controller,
    required this.readOnly,
  });

  final double rightInset;
  final double widthFactor;
  final CodeFindController controller;
  final bool readOnly;

  @override
  Size get preferredSize {
    final inner = FindPanel(controller: controller, readOnly: readOnly);
    return inner.preferredSize;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - rightInset - 8;
        if (available <= 0) return const SizedBox.shrink();

        var panelWidth = constraints.maxWidth * widthFactor;
        if (panelWidth > available) {
          panelWidth = available;
        }
        if (panelWidth < 300.0) {
          panelWidth = available < 300.0 ? available : 300.0;
        }

        return Padding(
          padding: EdgeInsets.only(right: rightInset),
          child: Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              width: panelWidth,
              child: FindPanel(controller: controller, readOnly: readOnly),
            ),
          ),
        );
      },
    );
  }
}

class _LayerDebugHud extends StatelessWidget {
  const _LayerDebugHud({
    required this.isVisuallyEmpty,
    required this.hasFocus,
    required this.findActive,
    required this.hasParagraph,
    required this.showMinimap,
  });

  final bool isVisuallyEmpty;
  final bool hasFocus;
  final bool findActive;
  final bool hasParagraph;
  final bool showMinimap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topRight,
        child: Container(
          margin: const EdgeInsets.only(top: 8, right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.border),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: AppColors.foreground,
              fontSize: 10,
              fontFamily: 'JetBrainsMono',
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('empty=$isVisuallyEmpty'),
                Text('focus=$hasFocus'),
                Text('find=$findActive'),
                Text('paragraph=$hasParagraph'),
                Text('minimap=$showMinimap'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CombinedOverlayPainter extends CustomPainter {
  const _CombinedOverlayPainter({
    required this.bracketPainter,
    this.diffPainter,
  });

  final _DiffLinePainter? diffPainter;
  final BracketMatchPainter bracketPainter;

  @override
  void paint(Canvas canvas, Size size) {
    diffPainter?.paint(canvas, size);
    bracketPainter.paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _CombinedOverlayPainter oldDelegate) {
    return true;
  }
}

class _DiffLinePainter extends CustomPainter {
  const _DiffLinePainter({
    required this.paragraphs,
    required this.changedLineIndexes,
    required this.indicatorWidth,
    required this.horizontalOffset,
    required this.color,
  });

  final List<dynamic> paragraphs;
  final Set<int> changedLineIndexes;
  final double indicatorWidth;
  final double horizontalOffset;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (changedLineIndexes.isEmpty) return;
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    for (final p in paragraphs) {
      if (!changedLineIndexes.contains(p.index)) continue;
      final top = p.top;
      final height = p.height;
      final rect = Rect.fromLTWH(
        indicatorWidth - horizontalOffset,
        top,
        size.width,
        height,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiffLinePainter oldDelegate) {
    return oldDelegate.changedLineIndexes != changedLineIndexes ||
        oldDelegate.indicatorWidth != indicatorWidth ||
        oldDelegate.horizontalOffset != horizontalOffset ||
        oldDelegate.color != color;
  }
}

class _MaxLinesChunkAnalyzer implements CodeChunkAnalyzer {
  const _MaxLinesChunkAnalyzer({
    required this.maxFoldableLines,
    required this.disableFoldLineThreshold,
  });

  final int maxFoldableLines;
  final int disableFoldLineThreshold;

  @override
  List<CodeChunk> run(CodeLines codeLines) {
    if (codeLines.lineCount >= disableFoldLineThreshold) {
      return const [];
    }
    final chunks = const DefaultCodeChunkAnalyzer().run(codeLines);
    return chunks
        .where((chunk) => (chunk.end - chunk.index - 1) <= maxFoldableLines)
        .toList(growable: false);
  }
}

class _DiagnosticScrollbar extends StatelessWidget {
  const _DiagnosticScrollbar({
    required this.scrollController,
    required this.lineCount,
    required this.diagnostics,
  });

  final ScrollController scrollController;
  final int lineCount;
  final List<CodeLspDiagnostic> diagnostics;

  @override
  Widget build(BuildContext context) {
    void jumpToByLocalDy(double localDy, double height) {
      if (!scrollController.hasClients || lineCount <= 0 || height <= 0) return;
      final ratio = (localDy / height).clamp(0.0, 1.0);
      final max = scrollController.position.maxScrollExtent;
      final target = ratio * max;
      scrollController.jumpTo(target.clamp(0.0, max));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (event) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        jumpToByLocalDy(event.localPosition.dy, box.size.height);
      },
      onVerticalDragStart: (event) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        jumpToByLocalDy(event.localPosition.dy, box.size.height);
      },
      onVerticalDragUpdate: (event) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        jumpToByLocalDy(event.localPosition.dy, box.size.height);
      },
      child: SizedBox(
        width: 14,
        child: CustomPaint(
          painter: _DiagnosticScrollbarPainter(
            lineCount: lineCount,
            diagnostics: diagnostics,
            scrollController: scrollController,
          ),
        ),
      ),
    );
  }
}

class _DiagnosticScrollbarPainter extends CustomPainter {
  const _DiagnosticScrollbarPainter({
    required this.lineCount,
    required this.diagnostics,
    required this.scrollController,
  }) : super(repaint: scrollController);

  final int lineCount;
  final List<CodeLspDiagnostic> diagnostics;
  final ScrollController scrollController;

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint =
        Paint()
          ..color = AppColors.surface.withValues(alpha: 0.72)
          ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(6),
      ),
      trackPaint,
    );

    if (scrollController.hasClients) {
      final max = scrollController.position.maxScrollExtent;
      final viewport = scrollController.position.viewportDimension;
      final thumbHeight = math.max(
        24.0,
        (viewport / (max + viewport)) * size.height,
      );
      final offsetRatio =
          max <= 0 ? 0.0 : (scrollController.offset / max).clamp(0.0, 1.0);
      final top = (size.height - thumbHeight) * offsetRatio;
      final thumbPaint =
          Paint()
            ..color = AppColors.foreground.withValues(alpha: 0.45)
            ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(2.5, top, size.width - 5, thumbHeight),
          const Radius.circular(5),
        ),
        thumbPaint,
      );
    }

    if (lineCount > 0 && diagnostics.isNotEmpty) {
      final markerPaint = Paint()..style = PaintingStyle.fill;
      final markerX = 1.2;
      final markerWidth = 3.2;
      final markerHeight = 2.8;
      for (final d in diagnostics) {
        final ratio = (d.startLine / (lineCount - 1 <= 0 ? 1 : lineCount - 1))
            .clamp(0.0, 1.0);
        final y = (ratio * (size.height - markerHeight)).clamp(
          0.0,
          size.height - markerHeight,
        );
        markerPaint.color = _severityColor(d.severity);
        final rect = Rect.fromLTWH(markerX, y, markerWidth, markerHeight);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(1)),
          markerPaint,
        );
      }
    }
  }

  Color _severityColor(int severity) {
    switch (severity) {
      case 1:
        return const Color(0xFFFF5F56);
      case 2:
        return const Color(0xFFF3C969);
      case 3:
        return const Color(0xFF58A6FF);
      default:
        return const Color(0xFF58A6FF);
    }
  }

  @override
  bool shouldRepaint(covariant _DiagnosticScrollbarPainter oldDelegate) {
    return oldDelegate.lineCount != lineCount ||
        oldDelegate.diagnostics != diagnostics ||
        oldDelegate.scrollController != scrollController;
  }
}

class _DiagnosticHoverPanel extends StatelessWidget {
  const _DiagnosticHoverPanel({required this.diagnostic});

  final CodeLspDiagnostic diagnostic;

  @override
  Widget build(BuildContext context) {
    final severityText = switch (diagnostic.severity) {
      1 => 'Error',
      2 => 'Warning',
      _ => 'Info',
    };
    final color = switch (diagnostic.severity) {
      1 => const Color(0xFFFF5F56),
      2 => const Color(0xFFF3C969),
      _ => const Color(0xFF58A6FF),
    };
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: AppTextStyles.uiSmall.copyWith(color: AppColors.foreground),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    '$severityText > L${diagnostic.startLine + 1}:${diagnostic.startCharacter + 1}',
                    style: TextStyle(color: AppColors.foreground, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                diagnostic.message.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
