import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/core/models/wallpaper_settings.dart';
import 'package:lafz/core/providers/providers.dart';
import 'package:lafz/features/wallpapers/widgets/wallpaper_renderer_widget.dart';
import 'package:lafz/native/native_bridge.dart';

/// The five quick actions. Each returns a short message describing the result.
/// Used by the home-screen widget's deep links (see HubActionScreen).
class HubActions {
  static Future<String> run(
    String action,
    WidgetRef ref,
    BuildContext context,
  ) async {
    try {
      switch (action) {
        case 'favorites':
          return await _favorites(ref, context);
        case 'collection':
          return await _collection(ref, context);
        case 'random':
          return await _random(ref, context);
        case 'widget':
          return await _widgetShuffle(ref);
        case 'both':
          return await _both(ref, context);
        default:
          return 'Unknown action: $action';
      }
    } catch (e) {
      return 'Something went wrong: $e';
    }
  }

  static Future<String> _favorites(WidgetRef ref, BuildContext context) async {
    final favs = await ref.read(favoritesRepositoryProvider).getFavorites();
    if (favs.isEmpty) {
      return 'No favorites yet. Bookmark quotes in the app first.';
    }
    final quote = favs[Random().nextInt(favs.length)];
    if (!context.mounted) return 'Cancelled';
    return _applyWallpaper(ref, context, quote, 'Favorites');
  }

  static Future<String> _collection(WidgetRef ref, BuildContext context) async {
    final quote =
        await ref.read(rotationRepositoryProvider).rotateNow(SurfaceType.wallpaper);
    if (quote == null) return 'No quote found in followed collections.';
    if (!context.mounted) return 'Cancelled';
    return _applyWallpaper(ref, context, quote, 'Collections');
  }

  static Future<String> _random(WidgetRef ref, BuildContext context) async {
    final quote = await ref.read(quotesRepositoryProvider).getRandomQuote();
    if (quote == null) return 'No quotes available.';
    if (!context.mounted) return 'Cancelled';
    return _applyWallpaper(ref, context, quote, 'Random');
  }

  static Future<String> _widgetShuffle(WidgetRef ref) async {
    final quote =
        await ref.read(rotationRepositoryProvider).rotateNow(SurfaceType.widget);
    if (quote == null) return 'No quote found for the widget.';
    await NativeBridge.updateWidgetTimeline(
      quoteText: '\u201c${quote.text}\u201d',
      attribution: '\u2014 ${quote.attribution}',
    );
    return 'Widget updated: "${quote.text}"';
  }

  static Future<String> _both(WidgetRef ref, BuildContext context) async {
    final quote =
        await ref.read(rotationRepositoryProvider).rotateNow(SurfaceType.wallpaper) ??
            await ref.read(quotesRepositoryProvider).getRandomQuote();
    if (quote == null) return 'No quote found.';

    await NativeBridge.updateWidgetTimeline(
      quoteText: '\u201c${quote.text}\u201d',
      attribution: '\u2014 ${quote.attribution}',
    );
    if (!context.mounted) return 'Cancelled';
    final wallpaperResult = await _applyWallpaper(ref, context, quote, 'Sync');
    return 'Widget updated. $wallpaperResult';
  }

  // ---------------------------------------------------------------------------

  static Future<String> _applyWallpaper(
    WidgetRef ref,
    BuildContext context,
    QuoteModel quote,
    String source,
  ) async {
    final style = await ref.read(settingsRepositoryProvider).getWallpaperSettings();
    if (!context.mounted) return 'Cancelled';

    final bytes = await _renderPng(context, quote, style);
    if (bytes == null) return 'Could not render the wallpaper.';

    final ok = await NativeBridge.applyWallpaper(
      imageBytes: bytes,
      destination: style.destination,
    );
    return ok
        ? 'Wallpaper set ($source): "${quote.text}"'
        : 'The system blocked setting the wallpaper.';
  }

  /// Draws WallpaperRendererWidget off-screen at the phone's real size and
  /// returns PNG bytes.
  static Future<Uint8List?> _renderPng(
    BuildContext context,
    QuoteModel quote,
    WallpaperSettingsModel style,
  ) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return null;

    final media = MediaQuery.of(context);
    final size = media.size;
    final key = GlobalKey();

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -size.width * 3,
        top: 0,
        width: size.width,
        height: size.height,
        child: IgnorePointer(
          child: RepaintBoundary(
            key: key,
            child: WallpaperRendererWidget(
              quote: quote,
              settings: style,
              showLockScreenOverlay: false,
              showHomeScreenOverlay: false,
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      await GoogleFonts.pendingFonts();
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || boundary.size.isEmpty) return null;

      final image = await boundary.toImage(pixelRatio: media.devicePixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      entry.remove();
    }
  }
}
