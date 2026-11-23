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

/// An Apple HIG-styled Quick Rotation Hub Widget.
///
/// Provides quick action tiles for:
/// 1. Wallpaper from Favourites
/// 2. Shuffle from Followed Collections
/// 3. Random Wisdom Selection
/// 4. Widget Shuffle
/// 5. Sync / Shuffle Both
class RotationHubWidget extends ConsumerStatefulWidget {
  const RotationHubWidget({super.key});

  @override
  ConsumerState<RotationHubWidget> createState() => _RotationHubWidgetState();
}

class _RotationHubWidgetState extends ConsumerState<RotationHubWidget> {
  String? _busyAction; // Key of action currently in progress

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<Uint8List?> _renderWallpaperPng(
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

  Future<void> _applyWallpaperForQuote(QuoteModel quote, String sourceLabel) async {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final style = await settingsRepo.getWallpaperSettings();

    final bytes = await _renderWallpaperPng(quote, style);
    if (bytes != null) {
      final ok = await NativeBridge.applyWallpaper(
        imageBytes: bytes,
        destination: style.destination,
      );
      if (ok) {
        _showSnack(
          'Wallpaper set from $sourceLabel: “${quote.text}” — ${quote.attribution}',
        );
      } else {
        _showSnack(
          'Selected “${quote.text}”, but OS prevented automatic wallpaper setting.',
        );
      }
    } else {
      _showSnack('Selected “${quote.text}”, but could not render wallpaper.');
    }
  }

  /// 1. Change wallpaper from favourites
  Future<void> _wallpaperFromFavorites() async {
    if (_busyAction != null) return;
    setState(() => _busyAction = 'favorites');

    try {
      final favRepo = ref.read(favoritesRepositoryProvider);
      final favs = await favRepo.getFavorites();

      if (favs.isEmpty) {
        _showSnack('No favorites yet! Bookmark quotes in the app to use them.');
        return;
      }

      final randomQuote = favs[Random().nextInt(favs.length)];
      await _applyWallpaperForQuote(randomQuote, 'Favorites');
    } catch (e) {
      _showSnack('Error applying favorite wallpaper: $e');
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  /// 2. Shuffle from followed collection
  Future<void> _shuffleFromCollection() async {
    if (_busyAction != null) return;
    setState(() => _busyAction = 'collection');

    try {
      final rotRepo = ref.read(rotationRepositoryProvider);
      final quote = await rotRepo.rotateNow(SurfaceType.wallpaper);

      if (quote == null) {
        _showSnack('No quote found in followed collections.');
        return;
      }

      await _applyWallpaperForQuote(quote, 'Collections');
    } catch (e) {
      _showSnack('Error shuffling from collection: $e');
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  /// 3. Random selection from all wisdom
  Future<void> _randomSelection() async {
    if (_busyAction != null) return;
    setState(() => _busyAction = 'random');

    try {
      final qRepo = ref.read(quotesRepositoryProvider);
      final quote = await qRepo.getRandomQuote();

      if (quote == null) {
        _showSnack('No quotes available.');
        return;
      }

      await _applyWallpaperForQuote(quote, 'Random Library');
    } catch (e) {
      _showSnack('Error picking random quote: $e');
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  /// 4. Widget shuffle
  Future<void> _widgetShuffle() async {
    if (_busyAction != null) return;
    setState(() => _busyAction = 'widget');

    try {
      final rotRepo = ref.read(rotationRepositoryProvider);
      final quote = await rotRepo.rotateNow(SurfaceType.widget);

      if (quote == null) {
        _showSnack('No quote found for widget rotation.');
        return;
      }

      await NativeBridge.updateWidgetTimeline(
        quoteText: '“${quote.text}”',
        attribution: '— ${quote.attribution}',
      );
      _showSnack('Widget updated: “${quote.text}” — ${quote.attribution}');
    } catch (e) {
      _showSnack('Error shuffling widget: $e');
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  /// 5. Full sync / shuffle both wallpaper and widget
  Future<void> _shuffleBoth() async {
    if (_busyAction != null) return;
    setState(() => _busyAction = 'both');

    try {
      final rotRepo = ref.read(rotationRepositoryProvider);
      final qRepo = ref.read(quotesRepositoryProvider);

      final quote = await rotRepo.rotateNow(SurfaceType.wallpaper) ??
          await qRepo.getRandomQuote();

      if (quote == null) {
        _showSnack('No quote found.');
        return;
      }

      // Update widget
      await NativeBridge.updateWidgetTimeline(
        quoteText: '“${quote.text}”',
        attribution: '— ${quote.attribution}',
      );

      // Update wallpaper
      await _applyWallpaperForQuote(quote, 'Complete Sync');
      _showSnack('Both Wallpaper & Widget updated to “${quote.text}”');
    } catch (e) {
      _showSnack('Error during complete shuffle: $e');
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          width: 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.bolt_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Quick Rotation Hub',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                if (_busyAction != null)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'One-tap immediate rotation for wallpaper and home screen widget.',
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 14),

            // Action Grid
            Row(
              children: [
                Expanded(
                  child: _buildActionPill(
                    icon: Icons.star_rounded,
                    iconColor: const Color(0xFFC29B38),
                    bgColor: const Color(0xFFC29B38).withValues(alpha: 0.12),
                    title: 'Favorites',
                    subtitle: 'Wallpaper',
                    isBusy: _busyAction == 'favorites',
                    onTap: _wallpaperFromFavorites,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionPill(
                    icon: Icons.collections_bookmark_rounded,
                    iconColor: const Color(0xFF4A6B5D),
                    bgColor: const Color(0xFF4A6B5D).withValues(alpha: 0.12),
                    title: 'Collections',
                    subtitle: 'Shuffle WP',
                    isBusy: _busyAction == 'collection',
                    onTap: _shuffleFromCollection,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionPill(
                    icon: Icons.casino_rounded,
                    iconColor: const Color(0xFF5E5CE6),
                    bgColor: const Color(0xFF5E5CE6).withValues(alpha: 0.12),
                    title: 'Random',
                    subtitle: 'Surprise WP',
                    isBusy: _busyAction == 'random',
                    onTap: _randomSelection,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildActionPill(
                    icon: Icons.widgets_rounded,
                    iconColor: const Color(0xFF007AFF),
                    bgColor: const Color(0xFF007AFF).withValues(alpha: 0.12),
                    title: 'Widget Shuffle',
                    subtitle: 'Rotate Home Widget',
                    isBusy: _busyAction == 'widget',
                    onTap: _widgetShuffle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionPill(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: const Color(0xFFAF52DE),
                    bgColor: const Color(0xFFAF52DE).withValues(alpha: 0.12),
                    title: 'Sync Both',
                    subtitle: 'WP + Widget Together',
                    isBusy: _busyAction == 'both',
                    onTap: _shuffleBoth,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required bool isBusy,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF252528) : const Color(0xFFF2F2F7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _busyAction != null ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: isBusy
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: iconColor,
                            ),
                          )
                        : Icon(icon, size: 16, color: iconColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
