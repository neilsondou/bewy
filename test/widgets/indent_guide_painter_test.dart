import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:bewy/features/editor_area/widgets/indent_guide_painter.dart';

void main() {
  group('IndentGuidePainter', () {
    group('measureIndicatorWidth', () {
      test('uses minimum 3 digits for small line counts', () {
        final width1 = IndentGuidePainter.measureIndicatorWidth(
          1,
          14.0,
          'JetBrainsMono',
          0.0,
          8.0,
        );
        final width10 = IndentGuidePainter.measureIndicatorWidth(
          10,
          14.0,
          'JetBrainsMono',
          0.0,
          8.0,
        );
        final width99 = IndentGuidePainter.measureIndicatorWidth(
          99,
          14.0,
          'JetBrainsMono',
          0.0,
          8.0,
        );
        // All should be the same because min digits = 3
        expect(width1, equals(width10));
        expect(width10, equals(width99));
      });

      test('grows when line count exceeds 999', () {
        final width999 = IndentGuidePainter.measureIndicatorWidth(
          999,
          14.0,
          'JetBrainsMono',
          0.0,
          8.0,
        );
        final width1000 = IndentGuidePainter.measureIndicatorWidth(
          1000,
          14.0,
          'JetBrainsMono',
          0.0,
          8.0,
        );
        expect(width1000, greaterThan(width999));
      });

      test('includes the SizedBox gap', () {
        final widthWithGap = IndentGuidePainter.measureIndicatorWidth(
          100,
          14.0,
          'JetBrainsMono',
          0.0,
          8.0,
        );
        final widthNoGap = IndentGuidePainter.measureIndicatorWidth(
          100,
          14.0,
          'JetBrainsMono',
          0.0,
          0.0,
        );
        expect(widthWithGap - widthNoGap, closeTo(8.0, 0.01));
      });

      test('scales with font size', () {
        final widthSmall = IndentGuidePainter.measureIndicatorWidth(
          100,
          12.0,
          'JetBrainsMono',
          0.0,
          8.0,
        );
        final widthLarge = IndentGuidePainter.measureIndicatorWidth(
          100,
          18.0,
          'JetBrainsMono',
          0.0,
          8.0,
        );
        expect(widthLarge, greaterThan(widthSmall));
      });
    });
  });
}
