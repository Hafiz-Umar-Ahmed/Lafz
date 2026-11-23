import 'dart:io';
import 'package:flutter/services.dart';
import 'package:lafz/core/constants/app_constants.dart';
import 'package:lafz/core/enums/enums.dart';

class NativeBridge {
  static const MethodChannel _wallpaperChannel =
      MethodChannel(AppConstants.wallpaperChannelName);
  static const MethodChannel _widgetChannel =
      MethodChannel(AppConstants.widgetChannelName);

  /// Apply wallpaper to Android device (or invoke fallback)
  static Future<bool> applyWallpaper({
    required Uint8List imageBytes,
    required WallpaperDestination destination,
  }) async {
    if (!Platform.isAndroid) {
      // iOS / desktop uses export fallback
      return false;
    }

    try {
      final String flag;
      switch (destination) {
        case WallpaperDestination.lockScreen:
          flag = 'lock';
          break;
        case WallpaperDestination.homeScreen:
          flag = 'home';
          break;
        case WallpaperDestination.both:
          flag = 'both';
          break;
      }

      final result = await _wallpaperChannel.invokeMethod<bool>('setWallpaper', {
        'image': imageBytes,
        'destination': flag,
      });

      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Check whether battery optimization is active or ignored
  static Future<Map<String, dynamic>> checkAutomationHealth() async {
    if (!Platform.isAndroid) {
      return {
        'isIgnoringBatteryOptimizations': true,
        'canScheduleExactAlarms': true,
        'platform': Platform.operatingSystem,
      };
    }

    try {
      final result = await _wallpaperChannel.invokeMapMethod<String, dynamic>(
        'getBatteryOptimizationStatus',
      );
      return result ?? {
        'isIgnoringBatteryOptimizations': false,
        'canScheduleExactAlarms': true,
      };
    } catch (_) {
      return {
        'isIgnoringBatteryOptimizations': false,
        'canScheduleExactAlarms': true,
      };
    }
  }

  /// Request opening system battery optimization settings
  static Future<void> openBatterySettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _wallpaperChannel.invokeMethod('openBatterySettings');
    } catch (_) {}
  }

  /// Export widget timeline data for iOS WidgetKit / Android AppWidget
  /// Optionally pass bgColor and textColor as hex strings (e.g. '#FF1E232B')
  static Future<void> updateWidgetTimeline({
    required String quoteText,
    required String attribution,
    String? collectionName,
    String? bgColor,
    String? textColor,
  }) async {
    try {
      await _widgetChannel.invokeMethod('updateWidget', {
        'quote': quoteText,
        'attribution': attribution,
        'collection': collectionName ?? 'Lafz Daily',
        if (bgColor != null) 'bg_color': bgColor as dynamic,
        if (textColor != null) 'text_color': textColor as dynamic,
      });
    } catch (_) {}
  }

  /// Schedule background WorkManager rotation
  static Future<bool> scheduleWorkManager({int intervalHours = 12}) async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _wallpaperChannel.invokeMethod<bool>('scheduleWorkManager', {
        'intervalHours': intervalHours,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Trigger WorkManager immediately for headless testing
  static Future<bool> triggerWorkManagerNow() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _wallpaperChannel.invokeMethod<bool>('triggerWorkManagerNow');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Get status and recent execution logs of native WorkManager
  static Future<Map<String, dynamic>> getWorkManagerStatus() async {
    if (!Platform.isAndroid) {
      return {
        'isScheduled': true,
        'lastRunTimestamp': DateTime.now().millisecondsSinceEpoch,
        'lastQuote': 'Desktop/iOS simulated worker',
        'lastAttribution': 'NativeBridge',
        'lastStatus': 'SUCCESS',
      };
    }
    try {
      final res = await _wallpaperChannel.invokeMapMethod<String, dynamic>('getWorkManagerStatus');
      return res ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Set rotation mode for background worker ('standard', 'favorites', 'random')
  static Future<void> setRotationMode(String mode) async {
    if (!Platform.isAndroid) return;
    try {
      await _wallpaperChannel.invokeMethod('setRotationMode', {'mode': mode});
    } catch (_) {}
  }
}
