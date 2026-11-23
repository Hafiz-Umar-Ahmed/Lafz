import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lafz/core/constants/app_constants.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/models/quote.dart';
import 'package:lafz/core/models/wallpaper_settings.dart';
import 'package:lafz/core/utils/contrast_checker.dart';

/// Draws the wallpaper. It is self-contained, so it looks identical wherever it
/// is placed (studio preview, off-screen capture, background rotation):
///
/// - It never depends on a parent Material/Scaffold, so no stray underline.
/// - All sizes scale with the canvas width, so the composition (font size,
///   margins, line breaks) is the same at any resolution.
/// - The phone's "font size" accessibility setting is ignored, so wallpapers
///   don't change depending on system text scaling.
class WallpaperRendererWidget extends StatelessWidget {
  final QuoteModel quote;
  final WallpaperSettingsModel settings;
  final bool showLockScreenOverlay;
  final bool showHomeScreenOverlay;

  const WallpaperRendererWidget({
    super.key,
    required this.quote,
    required this.settings,
    this.showLockScreenOverlay = false,
    this.showHomeScreenOverlay = false,
  });

  /// "Text size 22" means 22 logical pixels on a canvas this wide (a typical
  /// phone). On wider or narrower canvases everything scales proportionally.
  static const double _referenceWidth = 390.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = (width.isFinite && width > 0)
            ? width / _referenceWidth
            : 1.0;

        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: DefaultTextStyle(
            // Replaces Flutter's fallback style (yellow underline) that
            // appears when there is no Material ancestor.
            style: const TextStyle(decoration: TextDecoration.none),
            child: _buildCanvas(context, constraints, scale),
          ),
        );
      },
    );
  }

  Widget _buildCanvas(
    BuildContext context,
    BoxConstraints constraints,
    double scale,
  ) {
    final preset = settings.preset;

    // Background: user override wins, otherwise the template's colour.
    final bgColor = settings.backgroundColor != null
        ? Color(settings.backgroundColor!)
        : Color(preset.defaultBgColor);

    // Text colour: user override wins. If only the background was changed, pick
    // a readable colour automatically so the template's text never disappears
    // on the new background. Otherwise use the template's colour.
    final Color targetTextColor;
    if (settings.textColor != null) {
      targetTextColor = Color(settings.textColor!);
    } else if (settings.backgroundColor != null) {
      targetTextColor = bgColor.computeLuminance() > 0.5
          ? const Color(0xFF111111)
          : Colors.white;
    } else {
      targetTextColor = Color(preset.defaultTextColor);
    }

    // WCAG contrast overlay calculation per PRD 5.5 & SRS 5.2 step 4
    final (overlayColor, calculatedOpacity) = ContrastChecker.calculateOverlay(
      backgroundColor: bgColor,
      targetTextColor: targetTextColor,
      defaultOpacity: settings.overlayOpacity,
    );

    final baseSize = settings.textSize * scale;

    // Template typography
    TextStyle quoteStyle;
    switch (preset) {
      case WallpaperPreset.minimal:
        quoteStyle = GoogleFonts.playfairDisplay(
          fontSize: baseSize,
          fontWeight: FontWeight.w600,
          color: targetTextColor,
          height: 1.45,
        );
        break;
      case WallpaperPreset.nature:
        quoteStyle = GoogleFonts.lora(
          fontSize: baseSize,
          fontWeight: FontWeight.w500,
          color: targetTextColor,
          height: 1.45,
        );
        break;
      case WallpaperPreset.architecture:
      case WallpaperPreset.editorial:
        quoteStyle = GoogleFonts.cinzel(
          fontSize: baseSize * 0.9,
          fontWeight: FontWeight.w600,
          color: targetTextColor,
          height: 1.4,
        );
        break;
      case WallpaperPreset.dark:
      case WallpaperPreset.light:
      case WallpaperPreset.abstractPreset:
      case WallpaperPreset.clean:
        quoteStyle = GoogleFonts.plusJakartaSans(
          fontSize: baseSize,
          fontWeight: FontWeight.w600,
          color: targetTextColor,
          height: 1.45,
        );
        break;
    }

    // Font override: applied on top of the template's size, weight and colour.
    final fontFamily = settings.font == kTemplateFont ? null : settings.font;
    if (fontFamily != null) {
      quoteStyle = GoogleFonts.getFont(fontFamily, textStyle: quoteStyle);
    }

    // Attribution and source follow the chosen font too (when one is chosen).
    TextStyle secondaryStyle(TextStyle base) => fontFamily == null
        ? base
        : GoogleFonts.getFont(fontFamily, textStyle: base);

    TextAlign textAlign = TextAlign.center;
    Alignment containerAlignment = Alignment.center;
    switch (settings.textAlignment) {
      case WallpaperTextAlignment.topLeft:
        textAlign = TextAlign.left;
        containerAlignment = Alignment.topLeft;
        break;
      case WallpaperTextAlignment.topCenter:
        textAlign = TextAlign.center;
        containerAlignment = Alignment.topCenter;
        break;
      case WallpaperTextAlignment.topRight:
        textAlign = TextAlign.right;
        containerAlignment = Alignment.topRight;
        break;
      case WallpaperTextAlignment.centerLeft:
        textAlign = TextAlign.left;
        containerAlignment = Alignment.centerLeft;
        break;
      case WallpaperTextAlignment.center:
        textAlign = TextAlign.center;
        containerAlignment = Alignment.center;
        break;
      case WallpaperTextAlignment.centerRight:
        textAlign = TextAlign.right;
        containerAlignment = Alignment.centerRight;
        break;
      case WallpaperTextAlignment.bottomLeft:
        textAlign = TextAlign.left;
        containerAlignment = Alignment.bottomLeft;
        break;
      case WallpaperTextAlignment.bottomCenter:
        textAlign = TextAlign.center;
        containerAlignment = Alignment.bottomCenter;
        break;
      case WallpaperTextAlignment.bottomRight:
        textAlign = TextAlign.right;
        containerAlignment = Alignment.bottomRight;
        break;
    }

    final height = constraints.maxHeight;
    final topSafeMargin = height * AppConstants.lockScreenClockTopPercent;
    final bottomSafeMargin =
        height * AppConstants.lockScreenWidgetBottomPercent;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Wallpaper Background
        Container(color: bgColor),

        // 2. Readability Overlay
        if (calculatedOpacity > 0.0)
          Container(color: overlayColor.withValues(alpha: calculatedOpacity)),

        // 3. Safe-Area Bounded Quote Composition
        Padding(
          padding: EdgeInsets.fromLTRB(
            28 * scale,
            topSafeMargin,
            28 * scale,
            bottomSafeMargin,
          ),
          child: Align(
            alignment: containerAlignment,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: textAlign == TextAlign.left
                    ? CrossAxisAlignment.start
                    : (textAlign == TextAlign.right
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.center),
                children: [
                  // Arabic or Urdu original text if present
                  // (always Amiri, regardless of the font override)
                  if (quote.hasOriginal) ...[
                    Text(
                      quote.originalText!,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.amiri(
                        fontSize: baseSize * 1.1,
                        fontWeight: FontWeight.w500,
                        color: targetTextColor.withValues(alpha: 0.95),
                        height: 1.8,
                      ),
                    ),
                    SizedBox(height: 12 * scale),
                  ],

                  // Main Quote Text
                  Text(
                    '“${quote.text}”',
                    textAlign: textAlign,
                    style: quoteStyle,
                  ),
                  SizedBox(height: 14 * scale),

                  // Attribution
                  if (settings.showAttribution) ...[
                    Text(
                      '— ${quote.attribution}',
                      textAlign: textAlign,
                      style: secondaryStyle(
                        TextStyle(
                          fontSize: baseSize * 0.65,
                          fontWeight: FontWeight.w600,
                          color: targetTextColor.withValues(alpha: 0.85),
                          letterSpacing: 0.5 * scale,
                        ),
                      ),
                    ),
                  ],

                  // Source Reference
                  if (settings.showSource && quote.sourceTitle != null) ...[
                    SizedBox(height: 4 * scale),
                    Text(
                      quote.sourceReference != null
                          ? '${quote.sourceTitle} (${quote.sourceReference})'
                          : quote.sourceTitle!,
                      textAlign: textAlign,
                      style: secondaryStyle(
                        TextStyle(
                          fontSize: baseSize * 0.52,
                          color: targetTextColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // 4. Simulated Lock-Screen Overlay (kept for other callers; the
        // wallpaper screen no longer uses it)
        if (showLockScreenOverlay)
          IgnorePointer(child: _buildLockScreenSimulation(context)),

        // 5. Simulated Home-Screen Overlay (same note as above)
        if (showHomeScreenOverlay)
          IgnorePointer(child: _buildHomeScreenSimulation(context)),
      ],
    );
  }

  Widget _buildLockScreenSimulation(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    return Container(
      color: Colors.black.withValues(alpha: 0.15),
      child: Column(
        children: [
          const SizedBox(height: 45),
          const Icon(Icons.lock_outline, color: Colors.white70, size: 20),
          const SizedBox(height: 8),
          Text(
            '$hour:$minute',
            style: const TextStyle(
              fontSize: 68,
              fontWeight: FontWeight.w200,
              color: Colors.white,
              letterSpacing: -2,
            ),
          ),
          const Text(
            'Wednesday, November 19',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(
                    Icons.flashlight_on_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeScreenSimulation(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '9:41',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.wifi, color: Colors.white, size: 16),
            ],
          ),
          const Spacer(),
          // Dock simulation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAppIcon(Icons.phone, Colors.green),
                _buildAppIcon(Icons.chat, Colors.blue),
                _buildAppIcon(Icons.public, Colors.orange),
                _buildAppIcon(Icons.music_note, Colors.redAccent),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildAppIcon(IconData icon, Color color) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}
