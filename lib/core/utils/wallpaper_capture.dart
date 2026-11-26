import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/core/models/wallpaper_settings.dart';
import 'package:lafz/features/wallpapers/widgets/wallpaper_renderer_widget.dart';

/// Shared helper for rendering and capturing crisp, release-safe wallpaper PNGs.
abstract final class WallpaperCapture {
  /// Caps the longest output edge to stay safely within Android GPU texture
  /// limits and [WallpaperManager] memory budgets on high-DPI devices.
  static const double _maxOutputDimension = 2560.0;

  /// Captures an already-mounted [RepaintBoundary] identified by [key] as PNG bytes.
  ///
  /// Awaits frame settlement and handles [GoogleFonts.pendingFonts] on a
  /// best-effort basis so offline devices or font-download failures never abort
  /// wallpaper rendering.
  static Future<Uint8List?> captureBoundary(
    GlobalKey key,
    BuildContext context,
  ) async {
    try {
      final media = MediaQuery.of(context);
      final targetPixelRatio = media.devicePixelRatio;

      // Let any pending state changes (e.g. busy indicators) finish painting first.
      await WidgetsBinding.instance.endOfFrame;

      // Best-effort wait for web fonts; never let a font network error/timeout
      // fail the whole wallpaper capture in release or offline mode.
      try {
        await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 3));
      } catch (_) {}

      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize || boundary.size.isEmpty) {
        return null;
      }

      final maxSide = math.max(boundary.size.width, boundary.size.height);
      final safeRatio = maxSide > 0
          ? math.min(targetPixelRatio, _maxOutputDimension / maxSide)
          : targetPixelRatio;

      final image = await boundary.toImage(
        pixelRatio: safeRatio.clamp(1.0, 4.0),
      );
      try {
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        return byteData?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  /// Renders [quote] with [settings] in a temporary overlay layer at the
  /// device's logical viewport size and returns encoded PNG bytes.
  static Future<Uint8List?> renderQuoteToPng(
    BuildContext context,
    QuoteModel quote,
    WallpaperSettingsModel settings,
  ) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return null;

    final media = MediaQuery.of(context);
    final size = media.size;
    if (size.isEmpty) return null;

    final key = GlobalKey();

    // Positioned inside the viewport with near-zero parent opacity (alpha=1/255)
    // so Flutter/Impeller never skips layout/painting due to off-screen culling,
    // while capturing the RepaintBoundary child at 100% full opacity.
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        width: size.width,
        height: size.height,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.004,
            child: RepaintBoundary(
              key: key,
              child: WallpaperRendererWidget(
                quote: quote,
                settings: settings,
                showLockScreenOverlay: false,
                showHomeScreenOverlay: false,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      return await captureBoundary(key, context);
    } finally {
      entry.remove();
    }
  }
}
