import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lafz/core/constants/app_constants.dart';
import 'package:lafz/core/enums/enums.dart';

class WallpaperLayoutSpec {
  final double width;
  final double height;
  final double safeTopPercent;
  final double safeBottomPercent;
  final double horizontalMarginPercent;
  final String text;
  final String attribution;
  final String? source;
  final String fontFamily;
  final double fontSize;
  final double minFontSize;
  final WallpaperTextAlignment alignment;
  final int backgroundColor;
  final int textColor;
  final int overlayColor;
  final double overlayOpacity;
  final bool showAttribution;
  final bool showSource;
  final bool isRtl;

  const WallpaperLayoutSpec({
    required this.width,
    required this.height,
    this.safeTopPercent = AppConstants.lockScreenClockTopPercent,
    this.safeBottomPercent = AppConstants.lockScreenWidgetBottomPercent,
    this.horizontalMarginPercent = 0.08,
    required this.text,
    required this.attribution,
    this.source,
    required this.fontFamily,
    this.fontSize = AppConstants.defaultFontSize,
    this.minFontSize = AppConstants.minFontSize,
    this.alignment = WallpaperTextAlignment.center,
    this.backgroundColor = 0xFF121417,
    this.textColor = 0xFFF5F7FA,
    this.overlayColor = 0xFF000000,
    this.overlayOpacity = AppConstants.defaultOverlayOpacity,
    this.showAttribution = true,
    this.showSource = true,
    this.isRtl = false,
  });

  Rect get safeBounds {
    final top = height * safeTopPercent;
    final bottom = height * (1.0 - safeBottomPercent);
    final left = width * horizontalMarginPercent;
    final right = width * (1.0 - horizontalMarginPercent);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  TextAlign get textAlign {
    switch (alignment) {
      case WallpaperTextAlignment.topLeft:
      case WallpaperTextAlignment.centerLeft:
      case WallpaperTextAlignment.bottomLeft:
        return TextAlign.left;
      case WallpaperTextAlignment.topRight:
      case WallpaperTextAlignment.centerRight:
      case WallpaperTextAlignment.bottomRight:
        return TextAlign.right;
      case WallpaperTextAlignment.topCenter:
      case WallpaperTextAlignment.center:
      case WallpaperTextAlignment.bottomCenter:
        return TextAlign.center;
    }
  }

  Alignment get containerAlignment {
    switch (alignment) {
      case WallpaperTextAlignment.topLeft:
        return Alignment.topLeft;
      case WallpaperTextAlignment.topCenter:
        return Alignment.topCenter;
      case WallpaperTextAlignment.topRight:
        return Alignment.topRight;
      case WallpaperTextAlignment.centerLeft:
        return Alignment.centerLeft;
      case WallpaperTextAlignment.center:
        return Alignment.center;
      case WallpaperTextAlignment.centerRight:
        return Alignment.centerRight;
      case WallpaperTextAlignment.bottomLeft:
        return Alignment.bottomLeft;
      case WallpaperTextAlignment.bottomCenter:
        return Alignment.bottomCenter;
      case WallpaperTextAlignment.bottomRight:
        return Alignment.bottomRight;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
      'safe_top_percent': safeTopPercent,
      'safe_bottom_percent': safeBottomPercent,
      'horizontal_margin_percent': horizontalMarginPercent,
      'text': text,
      'attribution': attribution,
      'source': source,
      'font_family': fontFamily,
      'font_size': fontSize,
      'min_font_size': minFontSize,
      'alignment': alignment.name,
      'background_color': backgroundColor,
      'text_color': textColor,
      'overlay_color': overlayColor,
      'overlay_opacity': overlayOpacity,
      'show_attribution': showAttribution,
      'show_source': showSource,
      'is_rtl': isRtl,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory WallpaperLayoutSpec.fromJson(Map<String, dynamic> json) {
    return WallpaperLayoutSpec(
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      safeTopPercent: (json['safe_top_percent'] as num?)?.toDouble() ??
          AppConstants.lockScreenClockTopPercent,
      safeBottomPercent: (json['safe_bottom_percent'] as num?)?.toDouble() ??
          AppConstants.lockScreenWidgetBottomPercent,
      horizontalMarginPercent:
          (json['horizontal_margin_percent'] as num?)?.toDouble() ?? 0.08,
      text: json['text'] as String,
      attribution: json['attribution'] as String,
      source: json['source'] as String?,
      fontFamily: json['font_family'] as String? ?? 'Plus Jakarta Sans',
      fontSize: (json['font_size'] as num?)?.toDouble() ??
          AppConstants.defaultFontSize,
      minFontSize: (json['min_font_size'] as num?)?.toDouble() ??
          AppConstants.minFontSize,
      alignment: WallpaperTextAlignment.fromString(
        json['alignment'] as String? ?? 'center',
      ),
      backgroundColor: (json['background_color'] as int?) ?? 0xFF121417,
      textColor: (json['text_color'] as int?) ?? 0xFFF5F7FA,
      overlayColor: (json['overlay_color'] as int?) ?? 0xFF000000,
      overlayOpacity: (json['overlay_opacity'] as num?)?.toDouble() ??
          AppConstants.defaultOverlayOpacity,
      showAttribution: json['show_attribution'] as bool? ?? true,
      showSource: json['show_source'] as bool? ?? true,
      isRtl: json['is_rtl'] as bool? ?? false,
    );
  }
}
