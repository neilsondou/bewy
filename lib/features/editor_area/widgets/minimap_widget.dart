import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:bewy/core/editor/re_editor_compat.dart';
import '../../../core/theme/app_colors.dart';

/// VS Code-inspired minimap with pixel-row aggregation for large files.
///
/// For short files it keeps a clearer per-line representation.
/// For large files it aggregates multiple lines into one pixel row to avoid
/// blurry overdraw and keeps the viewport slider interactive.
class MinimapWidget extends StatefulWidget {
  const MinimapWidget({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.focusedLineNotifier,
    required this.diagnostics,
  });

  final CodeLineEditingController controller;
  final CodeScrollController scrollController;
  final ValueNotifier<int> focusedLineNotifier;
  final List<CodeLspDiagnostic> diagnostics;

  static const double width = 80.0;

  @override
  State<MinimapWidget> createState() => _MinimapWidgetState();
}

class _MinimapWidgetState extends State<MinimapWidget> {
  bool _isDragging = false;
  double _dragAnchor = 0.0;

  ScrollController get _scroller => widget.scrollController.verticalScroller;
  bool get _ready => _scroller.hasClients;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    _scroller.addListener(_rebuild);
    widget.focusedLineNotifier.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(MinimapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.verticalScroller.removeListener(_rebuild);
      _scroller.addListener(_rebuild);
    }
    if (oldWidget.focusedLineNotifier != widget.focusedLineNotifier) {
      oldWidget.focusedLineNotifier.removeListener(_rebuild);
      widget.focusedLineNotifier.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _scroller.removeListener(_rebuild);
    widget.focusedLineNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  double get _maxExtent => _ready ? _scroller.position.maxScrollExtent : 0.0;
  double get _offset => _ready ? _scroller.offset : 0.0;
  double get _viewportDim =>
      _ready ? _scroller.position.viewportDimension : 1.0;
  double get _totalContent => _maxExtent + _viewportDim;

  /// Dynamic minimap content height.
  ///
  /// Small files get larger per-line space.
  /// Large files prioritize dense packing with pixel aggregation.
  double _contentH(double widgetH) {
    final lines = widget.controller.lineCount.clamp(1, 1000000);
    final double pitch;
    if (lines <= 200) {
      pitch = 2.0;
    } else if (lines <= 2000) {
      pitch = 0.8;
    } else {
      pitch = 0.25;
    }
    final natural = lines * pitch;
    return natural.clamp(widgetH * 0.35, widgetH * 0.92);
  }

  double _sliderH(double contentH) {
    if (_totalContent <= 0) return contentH;
    return (_viewportDim / _totalContent * contentH).clamp(12.0, contentH);
  }

  double _sliderTop(double contentH) {
    if (_maxExtent <= 0) return 0;
    final range = contentH - _sliderH(contentH);
    return (_offset / _maxExtent * range).clamp(0.0, range);
  }

  void _scrollToY(double localY, double contentH) {
    if (!_ready || _maxExtent <= 0 || contentH <= 0) return;
    final fraction = (localY / contentH).clamp(0.0, 1.0);
    final target = (fraction * _totalContent - _viewportDim / 2).clamp(
      0.0,
      _maxExtent,
    );
    _scroller.jumpTo(target);
  }

  void _dragSliderTo(double localY, double contentH) {
    if (!_ready || _maxExtent <= 0) return;
    final sliderH = _sliderH(contentH);
    final range = contentH - sliderH;
    if (range <= 0) return;
    final top = localY - _dragAnchor;
    final fraction = (top / range).clamp(0.0, 1.0);
    _scroller.jumpTo(fraction * _maxExtent);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widgetH = constraints.maxHeight;
        final contentH = _contentH(widgetH);
        final sliderTop = _sliderTop(contentH);
        final sliderH = _sliderH(contentH);

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final y = d.localPosition.dy;
              if (y > contentH) return;
              if (y >= sliderTop && y <= sliderTop + sliderH) return;
              _scrollToY(y, contentH);
            },
            onVerticalDragStart: (d) {
              final y = d.localPosition.dy;
              if (y >= sliderTop && y <= sliderTop + sliderH) {
                _isDragging = true;
                _dragAnchor = y - sliderTop;
              } else if (y <= contentH) {
                _isDragging = true;
                _dragAnchor = sliderH / 2;
                _dragSliderTo(y, contentH);
              }
            },
            onVerticalDragUpdate: (d) {
              if (_isDragging) _dragSliderTo(d.localPosition.dy, contentH);
            },
            onVerticalDragEnd: (_) => _isDragging = false,
            onVerticalDragCancel: () => _isDragging = false,
            child: Container(
              width: MinimapWidget.width,
              color: AppColors.minimapBackground,
              child: CustomPaint(
                size: Size(MinimapWidget.width, widgetH),
                painter: _MinimapPainter(
                  lines: widget.controller.codeLines,
                  diagnostics: widget.diagnostics,
                  contentHeight: contentH,
                  sliderTop: sliderTop,
                  sliderHeight: sliderH,
                  focusedLine: widget.focusedLineNotifier.value,
                  contentHash: widget.controller.text.hashCode,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({
    required this.lines,
    required this.diagnostics,
    required this.contentHeight,
    required this.sliderTop,
    required this.sliderHeight,
    required this.focusedLine,
    required this.contentHash,
  });

  final CodeLines lines;
  final List<CodeLspDiagnostic> diagnostics;
  final double contentHeight;
  final double sliderTop;
  final double sliderHeight;
  final int focusedLine;
  final int contentHash;

  static const double _leftPad = 4.0;
  static const double _rightPad = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final totalLines = lines.length;
    if (totalLines == 0 || contentHeight <= 0) return;

    final usableW = size.width - _leftPad - _rightPad;
    final rows = math.max(1, contentHeight.floor());
    final linesPerRow = totalLines / rows;

    final paint =
        Paint()
          ..style = PaintingStyle.fill
          ..isAntiAlias = false;

    for (int row = 0; row < rows; row++) {
      final start = (row * linesPerRow).floor();
      final end = math.min(totalLines, ((row + 1) * linesPerRow).ceil());
      if (start >= end) continue;

      double maxDensity = 0;
      double maxIndentPx = 0;
      bool hasText = false;

      for (int i = start; i < end; i++) {
        final text = lines[i].text;
        if (text.isEmpty) continue;

        int leading = 0;
        for (int c = 0; c < text.length; c++) {
          final ch = text[c];
          if (ch == ' ') {
            leading += 1;
          } else if (ch == '\t') {
            leading += 4;
          } else {
            break;
          }
        }

        final visible = text.length - leading;
        if (visible <= 0) continue;

        hasText = true;
        final density = (visible / 140.0).clamp(0.0, 1.0);
        if (density > maxDensity) maxDensity = density;

        final indentPx = math.min(leading * 0.18, usableW * 0.55);
        if (indentPx > maxIndentPx) maxIndentPx = indentPx;
      }

      if (!hasText) continue;

      final y = row.toDouble();
      final x = _leftPad + maxIndentPx;
      final widthFactor = 0.2 + maxDensity * 0.8;
      final width = math.max(1.0, (usableW - maxIndentPx) * widthFactor);
      final alpha = (0.22 + maxDensity * 0.5).clamp(0.0, 1.0);

      paint.color = AppColors.minimapForeground.withValues(alpha: alpha);
      canvas.drawRect(Rect.fromLTWH(x, y, width, 1.0), paint);
    }

    if (focusedLine >= 0 && focusedLine < totalLines) {
      final focusY = ((focusedLine / totalLines) * contentHeight).clamp(
        0.0,
        contentHeight - 1.0,
      );
      canvas.drawRect(
        Rect.fromLTWH(0, focusY, size.width, 1.5),
        Paint()..color = AppColors.accent.withValues(alpha: 0.22),
      );
    }

    if (diagnostics.isNotEmpty && totalLines > 0) {
      for (final d in diagnostics) {
        final y = ((d.startLine / (totalLines - 1 <= 0 ? 1 : totalLines - 1)) *
                contentHeight)
            .clamp(0.0, contentHeight - 1.0);
        final markerHeight = 1.6;
        final color = switch (d.severity) {
          1 => const Color(0xFFFF5F56),
          2 => const Color(0xFFF3C969),
          _ => const Color(0xFF58A6FF),
        };
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, y, size.width, markerHeight),
            const Radius.circular(1),
          ),
          Paint()..color = color.withValues(alpha: 0.88),
        );
      }
    }

    canvas.drawRect(
      Rect.fromLTWH(0, sliderTop, size.width, sliderHeight),
      Paint()..color = AppColors.minimapViewport,
    );
    final borderPaint =
        Paint()
          ..color = AppColors.minimapViewportBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..isAntiAlias = false;
    canvas.drawLine(
      Offset(0, sliderTop),
      Offset(size.width, sliderTop),
      borderPaint,
    );
    canvas.drawLine(
      Offset(0, sliderTop + sliderHeight),
      Offset(size.width, sliderTop + sliderHeight),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(_MinimapPainter oldDelegate) {
    return oldDelegate.sliderTop != sliderTop ||
        oldDelegate.sliderHeight != sliderHeight ||
        oldDelegate.contentHeight != contentHeight ||
        oldDelegate.focusedLine != focusedLine ||
        oldDelegate.lines.length != lines.length ||
        oldDelegate.contentHash != contentHash ||
        oldDelegate.diagnostics != diagnostics;
  }
}
