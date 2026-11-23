import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lafz/core/utils/contrast_checker.dart';

void main() {
  group('ContrastChecker WCAG Tests (NFR-09 & SRS 5.2)', () {
    test('Calculates black and white luminance accurately', () {
      final whiteLum = ContrastChecker.getRelativeLuminance(Colors.white);
      final blackLum = ContrastChecker.getRelativeLuminance(Colors.black);

      expect(whiteLum, closeTo(1.0, 0.01));
      expect(blackLum, closeTo(0.0, 0.01));
    });

    test('Black text on white background yields max contrast ratio (21:1)', () {
      final ratio = ContrastChecker.getContrastRatio(Colors.black, Colors.white);
      expect(ratio, closeTo(21.0, 0.5));
      expect(ContrastChecker.meetsWcagAA(Colors.black, Colors.white), isTrue);
    });

    test('Identical colors yield 1:1 contrast ratio and fail WCAG AA', () {
      final ratio = ContrastChecker.getContrastRatio(Colors.grey, Colors.grey);
      expect(ratio, closeTo(1.0, 0.1));
      expect(ContrastChecker.meetsWcagAA(Colors.grey, Colors.grey), isFalse);
    });

    test('Calculates overlay opacity when background contrast is insufficient', () {
      // Light grey on white has poor contrast
      final fg = Colors.grey.shade400;
      final bg = Colors.white;

      final (overlayColor, opacity) = ContrastChecker.calculateOverlay(
        backgroundColor: bg,
        targetTextColor: fg,
      );

      expect(opacity, greaterThan(0.0));
      expect(overlayColor, isNotNull);
    });
  });
}
