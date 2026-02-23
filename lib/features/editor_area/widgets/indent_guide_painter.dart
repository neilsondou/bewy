import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bewy/core/editor/re_editor_compat.dart';
import '../../../core/theme/app_colors.dart';

/// Paints vertical indent guide lines and current-line background highlight
/// over the code editor area.
class IndentGuidePainter extends CustomPainter {
  static final RegExp _invisibleChars = RegExp(
    r'[\s\u200B\u200C\u200D\uFEFF]+',
  );

  IndentGuidePainter({
    required this.paragraphs,
    required this.focusedIndex,
    required this.hasVisibleText,
    required this.lineTextByIndex,
    required this.fontSize,
    required this.fontFamily,
    required this.letterSpacing,
    required this.indicatorWidth,
    required this.horizontalOffset,
    required this.tabSize,
  });

  final List<CodeLineRenderParagraph> paragraphs;
  final int focusedIndex;
  final bool hasVisibleText;
  final Map<int, String> lineTextByIndex;
  final double fontSize;
  final String fontFamily;
  final double letterSpacing;
  final double indicatorWidth;
  final double horizontalOffset;
  final int tabSize;

  /// Default padding used by re_editor (_kDefaultPadding = EdgeInsets.all(5)).
  static const double _editorPadding = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (paragraphs.isEmpty) return;

    final charWidth = _measureCharWidth();
    final leftStart = indicatorWidth + _editorPadding;
    final tabWidth = tabSize * charWidth;

    // Paint current line highlight
    _paintCurrentLineHighlight(canvas, size, leftStart);

    // Paint indent guides
    _paintIndentGuides(canvas, size, leftStart, charWidth, tabWidth);
  }

  void _paintCurrentLineHighlight(Canvas canvas, Size size, double leftStart) {
    if (!hasVisibleText) {
      return;
    }

    final paint =
        Paint()
          ..color = AppColors.editorCursorLine
          ..style = PaintingStyle.fill;

    for (final p in paragraphs) {
      if (p.index == focusedIndex) {
        final y = p.offset.dy;
        canvas.drawRect(
          Rect.fromLTWH(0, y, size.width, p.preferredLineHeight),
          paint,
        );
        break;
      }
    }
  }

  void _paintIndentGuides(
    Canvas canvas,
    Size size,
    double leftStart,
    double charWidth,
    double tabWidth,
  ) {
    final visibleParagraphs = paragraphs;
    if (visibleParagraphs.isEmpty) return;

    final paint =
        Paint()
          ..color = AppColors.indentGuide
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.square;

    final levels = List<int>.filled(visibleParagraphs.length, 0);
    final nonEmpty = List<bool>.filled(visibleParagraphs.length, false);

    for (int i = 0; i < visibleParagraphs.length; i++) {
      final p = visibleParagraphs[i];
      final lineText = lineTextByIndex[p.index] ?? '';
      final compact = lineText.replaceAll(_invisibleChars, '');
      final isNonEmpty = compact.isNotEmpty;
      nonEmpty[i] = isNonEmpty;
      if (!isNonEmpty) continue;
      final indentSpaces = _countLeadingSpaces(lineText, tabSize);
      levels[i] = indentSpaces ~/ tabSize;
    }

    // Forward pass: carry indentation into blank lines.
    int carryForward = 0;
    for (int i = 0; i < levels.length; i++) {
      if (nonEmpty[i]) {
        carryForward = levels[i];
      } else {
        levels[i] = carryForward;
      }
    }

    // Backward pass: trim carried level by following context, so blank-line
    // guides don't over-extend across dedent boundaries.
    int carryBackward = 0;
    for (int i = levels.length - 1; i >= 0; i--) {
      if (nonEmpty[i]) {
        carryBackward = levels[i];
      } else if (carryBackward < levels[i]) {
        levels[i] = carryBackward;
      }
    }

    for (int i = 0; i < visibleParagraphs.length; i++) {
      final p = visibleParagraphs[i];
      final indentLevels = levels[i];
      if (indentLevels <= 0) continue;
      final yTop = p.offset.dy;
      final yBottom = yTop + p.preferredLineHeight;

      for (int level = 1; level <= indentLevels; level++) {
        final x = leftStart + (level * tabWidth) - horizontalOffset;
        if (x < -1 || x > size.width + 1) continue;
        canvas.drawLine(Offset(x, yTop), Offset(x, yBottom), paint);
      }
    }
  }

  /// Count the number of leading space-equivalent characters.
  /// Tabs count as [tabSize] spaces.
  static int _countLeadingSpaces(String text, int tabSize) {
    int count = 0;
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == ' ') {
        count++;
      } else if (ch == '\t') {
        count += tabSize;
      } else {
        break;
      }
    }
    return count;
  }

  double _measureCharWidth() {
    final tp = TextPainter(
      text: TextSpan(
        text: '0',
        style: TextStyle(
          fontFamily: fontFamily,
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

  /// Calculate the line number indicator width (same algorithm as
  /// DefaultCodeLineNumber in re_editor).
  static double measureIndicatorWidth(
    int lineCount,
    double fontSize,
    String fontFamily,
    double letterSpacing,
    double sizedBoxGap,
  ) {
    final digits = max(3, lineCount.toString().length);
    final tp = TextPainter(
      text: TextSpan(
        text: '0' * digits,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          letterSpacing: letterSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final w = tp.width + sizedBoxGap;
    tp.dispose();
    return w;
  }

  @override
  bool shouldRepaint(covariant IndentGuidePainter oldDelegate) {
    return oldDelegate.paragraphs != paragraphs ||
        oldDelegate.focusedIndex != focusedIndex ||
        oldDelegate.hasVisibleText != hasVisibleText ||
        oldDelegate.lineTextByIndex != lineTextByIndex ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.indicatorWidth != indicatorWidth ||
        oldDelegate.horizontalOffset != horizontalOffset ||
        oldDelegate.tabSize != tabSize ||
        oldDelegate.fontFamily != fontFamily ||
        oldDelegate.letterSpacing != letterSpacing;
  }
}
