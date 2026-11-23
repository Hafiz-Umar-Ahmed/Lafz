import 'package:lafz/core/enums/enums.dart';

/// Value of [WallpaperSettingsModel.font] meaning "use the template's own font".
const String kTemplateFont = 'template';

class WallpaperSettingsModel {
  final WallpaperPreset preset;
  final int? backgroundId;

  /// Google Fonts family name (e.g. 'Playfair Display'), or [kTemplateFont]
  /// to use the template's own font.
  final String font;

  /// Optional overrides (ARGB ints, e.g. 0xFF121417). null = use the template.
  final int? backgroundColor;
  final int? textColor;

  final WallpaperTextAlignment textAlignment;
  final double textSize;
  final double overlayOpacity;
  final String palette; // 'light' or 'dark'
  final bool showAttribution;
  final bool showSource;
  final WallpaperDestination destination;

  const WallpaperSettingsModel({
    this.preset = WallpaperPreset.minimal,
    this.backgroundId,
    this.font = kTemplateFont,
    this.backgroundColor,
    this.textColor,
    this.textAlignment = WallpaperTextAlignment.center,
    this.textSize = 22.0,
    this.overlayOpacity = 0.38,
    this.palette = 'dark',
    this.showAttribution = true,
    this.showSource = true,
    this.destination = WallpaperDestination.lockScreen,
  });

  Map<String, dynamic> toMap() {
    return {
      'preset': preset.name,
      'background_id': backgroundId,
      'font': font,
      'background_color': backgroundColor,
      'text_color': textColor,
      'text_alignment': textAlignment.name,
      'text_size': textSize,
      'overlay_opacity': overlayOpacity,
      'palette': palette,
      'show_attribution': showAttribution ? 1 : 0,
      'show_source': showSource ? 1 : 0,
      'destination': destination.name,
    };
  }

  factory WallpaperSettingsModel.fromMap(Map<String, dynamic> map) {
    // The old default ('Plus Jakarta Sans') was never applied by the renderer,
    // so treat it as "template font" rather than as a deliberate font choice.
    final storedFont = map['font'] as String?;
    final font = (storedFont == null || storedFont == 'Plus Jakarta Sans')
        ? kTemplateFont
        : storedFont;

    return WallpaperSettingsModel(
      preset: WallpaperPreset.fromString(map['preset'] as String? ?? 'minimal'),
      backgroundId: map['background_id'] as int?,
      font: font,
      backgroundColor: map['background_color'] as int?,
      textColor: map['text_color'] as int?,
      textAlignment: WallpaperTextAlignment.fromString(
        map['text_alignment'] as String? ?? 'center',
      ),
      textSize: (map['text_size'] as num?)?.toDouble() ?? 22.0,
      overlayOpacity: (map['overlay_opacity'] as num?)?.toDouble() ?? 0.38,
      palette: (map['palette'] as String?) ?? 'dark',
      showAttribution: (map['show_attribution'] as int? ?? 1) == 1,
      showSource: (map['show_source'] as int? ?? 1) == 1,
      destination: WallpaperDestination.fromString(
        map['destination'] as String? ?? 'lockScreen',
      ),
    );
  }

  WallpaperSettingsModel copyWith({
    WallpaperPreset? preset,
    int? backgroundId,
    String? font,
    int? backgroundColor,
    int? textColor,
    WallpaperTextAlignment? textAlignment,
    double? textSize,
    double? overlayOpacity,
    String? palette,
    bool? showAttribution,
    bool? showSource,
    WallpaperDestination? destination,
    // copyWith can't set a field back to null on its own, so use these flags
    // to go back to "use the template's colour".
    bool clearBackgroundColor = false,
    bool clearTextColor = false,
  }) {
    return WallpaperSettingsModel(
      preset: preset ?? this.preset,
      backgroundId: backgroundId ?? this.backgroundId,
      font: font ?? this.font,
      backgroundColor: clearBackgroundColor
          ? null
          : (backgroundColor ?? this.backgroundColor),
      textColor: clearTextColor ? null : (textColor ?? this.textColor),
      textAlignment: textAlignment ?? this.textAlignment,
      textSize: textSize ?? this.textSize,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      palette: palette ?? this.palette,
      showAttribution: showAttribution ?? this.showAttribution,
      showSource: showSource ?? this.showSource,
      destination: destination ?? this.destination,
    );
  }
}
