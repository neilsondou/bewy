import 'package:flutter/material.dart';
import 'package:bewy/core/editor/re_editor_compat.dart';
import '../../../core/theme/app_colors.dart';

/// Paints bracket match highlights over the code editor area.
///
/// When the cursor is adjacent to a bracket character, both the bracket
/// at the cursor and its matching counterpart are highlighted with a
/// semi-transparent background rectangle.
class BracketMatchPainter extends CustomPainter {
  BracketMatchPainter({
    required this.paragraphs,
    required this.bracketMatch,
    required this.fontSize,
    required this.indicatorWidth,
    required this.horizontalOffset,
  });

  final List<CodeLineRenderParagraph> paragraphs;

  /// (line1, col1, line2, col2) of the matched bracket pair, or null.
  final (int, int, int, int)? bracketMatch;
  final double fontSize;
  final double indicatorWidth;
  final double horizontalOffset;

  /// Default padding used by re_editor (_kDefaultPadding = EdgeInsets.all(5)).
  static const double _editorPadding = 5.0;

  static const _openBrackets = '({[';
  static const _matchMap = {
    '(': ')',
    ')': '(',
    '{': '}',
    '}': '{',
    '[': ']',
    ']': '[',
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (bracketMatch == null || paragraphs.isEmpty) return;

    final (line1, col1, line2, col2) = bracketMatch!;
    final charWidth = _measureCharWidth();
    final leftStart = indicatorWidth + _editorPadding;

    final paint =
        Paint()
          ..color = AppColors.bracketMatchBackground
          ..style = PaintingStyle.fill;

    final borderPaint =
        Paint()
          ..color = AppColors.bracketMatchBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    // Draw highlight for first bracket
    _drawBracketHighlight(
      canvas,
      line1,
      col1,
      charWidth,
      leftStart,
      paint,
      borderPaint,
    );
    // Draw highlight for second bracket
    _drawBracketHighlight(
      canvas,
      line2,
      col2,
      charWidth,
      leftStart,
      paint,
      borderPaint,
    );
  }

  void _drawBracketHighlight(
    Canvas canvas,
    int line,
    int col,
    double charWidth,
    double leftStart,
    Paint fillPaint,
    Paint borderPaint,
  ) {
    for (final p in paragraphs) {
      if (p.index == line) {
        final x = leftStart + col * charWidth - horizontalOffset;
        final y = p.offset.dy;
        final rect = Rect.fromLTWH(x, y, charWidth, p.preferredLineHeight);
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, borderPaint);
        break;
      }
    }
  }

  double _measureCharWidth() {
    final tp = TextPainter(
      text: TextSpan(
        text: '0',
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: fontSize,
          height: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  @override
  bool shouldRepaint(covariant BracketMatchPainter oldDelegate) {
    return oldDelegate.bracketMatch != bracketMatch ||
        oldDelegate.paragraphs != paragraphs ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.indicatorWidth != indicatorWidth ||
        oldDelegate.horizontalOffset != horizontalOffset;
  }

  /// Finds the matching bracket pair for the cursor position.
  ///
  /// Returns (line1, col1, line2, col2) if a match is found, null otherwise.
  /// Checks the character before the cursor and at the cursor position.
  static (int, int, int, int)? findBracketMatch(
    CodeLines codeLines,
    int cursorLine,
    int cursorCol,
  ) {
    if (cursorLine < 0 || cursorLine >= codeLines.length) return null;

    final lineText = codeLines[cursorLine].text;

    // Check character before cursor
    if (cursorCol > 0 && cursorCol <= lineText.length) {
      final ch = lineText[cursorCol - 1];
      if (_matchMap.containsKey(ch)) {
        final result = _findMatch(codeLines, cursorLine, cursorCol - 1, ch);
        if (result != null) return result;
      }
    }

    // Check character at cursor
    if (cursorCol < lineText.length) {
      final ch = lineText[cursorCol];
      if (_matchMap.containsKey(ch)) {
        final result = _findMatch(codeLines, cursorLine, cursorCol, ch);
        if (result != null) return result;
      }
    }

    return null;
  }

  static (int, int, int, int)? _findMatch(
    CodeLines codeLines,
    int line,
    int col,
    String bracket,
  ) {
    final target = _matchMap[bracket]!;
    final isOpen = _openBrackets.contains(bracket);

    if (isOpen) {
      return _searchForward(codeLines, line, col, bracket, target);
    } else {
      return _searchBackward(codeLines, line, col, bracket, target);
    }
  }

  static (int, int, int, int)? _searchForward(
    CodeLines codeLines,
    int startLine,
    int startCol,
    String open,
    String close,
  ) {
    int depth = 0;
    bool inSingleQuote = false;
    bool inDoubleQuote = false;

    for (int i = startLine; i < codeLines.length; i++) {
      final text = codeLines[i].text;
      final startJ = (i == startLine) ? startCol : 0;
      for (int j = startJ; j < text.length; j++) {
        final ch = text[j];

        // Simple string skipping
        if (ch == "'" && !inDoubleQuote && (j == 0 || text[j - 1] != '\\')) {
          inSingleQuote = !inSingleQuote;
          continue;
        }
        if (ch == '"' && !inSingleQuote && (j == 0 || text[j - 1] != '\\')) {
          inDoubleQuote = !inDoubleQuote;
          continue;
        }
        if (inSingleQuote || inDoubleQuote) continue;

        if (ch == open) {
          depth++;
        } else if (ch == close) {
          depth--;
          if (depth == 0) {
            return (startLine, startCol, i, j);
          }
        }
      }
      // Reset quote state at line boundaries
      inSingleQuote = false;
      inDoubleQuote = false;
    }
    return null;
  }

  static (int, int, int, int)? _searchBackward(
    CodeLines codeLines,
    int startLine,
    int startCol,
    String close,
    String open,
  ) {
    int depth = 0;
    bool inSingleQuote = false;
    bool inDoubleQuote = false;

    for (int i = startLine; i >= 0; i--) {
      final text = codeLines[i].text;
      final startJ = (i == startLine) ? startCol : text.length - 1;
      for (int j = startJ; j >= 0; j--) {
        final ch = text[j];

        // Simple string skipping (reversed)
        if (ch == "'" && !inDoubleQuote && (j == 0 || text[j - 1] != '\\')) {
          inSingleQuote = !inSingleQuote;
          continue;
        }
        if (ch == '"' && !inSingleQuote && (j == 0 || text[j - 1] != '\\')) {
          inDoubleQuote = !inDoubleQuote;
          continue;
        }
        if (inSingleQuote || inDoubleQuote) continue;

        if (ch == close) {
          depth++;
        } else if (ch == open) {
          depth--;
          if (depth == 0) {
            return (i, j, startLine, startCol);
          }
        }
      }
      // Reset quote state at line boundaries
      inSingleQuote = false;
      inDoubleQuote = false;
    }
    return null;
  }
}
