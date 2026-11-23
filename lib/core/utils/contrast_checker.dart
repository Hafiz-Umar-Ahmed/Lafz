import 'dart:math';
import 'package:flutter/material.dart';

class ContrastChecker {
  /// Calculate relative luminance of a color according to WCAG 2.1 specifications:
  /// https://www.w3.org/WAI/GL/wiki/Relative_luminance
  static double getRelativeLuminance(Color color) {
    double transform(double channel) {
      final s = channel / 255.0;
      return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = transform((color.r * 255.0).round().clamp(0, 255).toDouble());
    final g = transform((color.g * 255.0).round().clamp(0, 255).toDouble());
    final b = transform((color.b * 255.0).round().clamp(0, 255).toDouble());

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Contrast ratio between two colors: (L1 + 0.05) / (L2 + 0.05)
  static double getContrastRatio(Color foreground, Color background) {
    final l1 = getRelativeLuminance(foreground);
    final l2 = getRelativeLuminance(background);
    final lighter = max(l1, l2);
    final darker = min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Checks if contrast ratio meets WCAG 2.1 AA (4.5:1)
  static bool meetsWcagAA(Color foreground, Color background) {
    return getContrastRatio(foreground, background) >= 4.5;
  }

  /// Suggests overlay color and opacity to ensure >= 4.5:1 contrast
  static (Color overlayColor, double opacity) calculateOverlay({
    required Color backgroundColor,
    required Color targetTextColor,
    double defaultOpacity = 0.38,
  }) {
    if (meetsWcagAA(targetTextColor, backgroundColor)) {
      return (Colors.transparent, 0.0);
    }

    final isTextLight = getRelativeLuminance(targetTextColor) > 0.5;
    final overlayColor = isTextLight ? Colors.black : Colors.white;

    // Check with default opacity
    final blended = Color.alphaBlend(
      overlayColor.withValues(alpha: defaultOpacity),
      backgroundColor,
    );

    if (meetsWcagAA(targetTextColor, blended)) {
      return (overlayColor, defaultOpacity);
    }

    // Step up opacity if still insufficient
    for (double op = defaultOpacity; op <= 0.85; op += 0.05) {
      final testBlend = Color.alphaBlend(
        overlayColor.withValues(alpha: op),
        backgroundColor,
      );
      if (meetsWcagAA(targetTextColor, testBlend)) {
        return (overlayColor, op);
      }
    }

    return (overlayColor, 0.75);
  }
}
