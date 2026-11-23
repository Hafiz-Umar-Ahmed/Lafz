import 'dart:convert';
import 'package:lafz/core/enums/enums.dart';
export 'package:lafz/core/models/wallpaper_settings.dart';

class RotationSettingsModel {
  final SurfaceType surface;
  final bool enabled;
  final ScheduleType scheduleType;
  final int intervalHours;
  final List<int> specificTimes; // e.g. [8, 14, 20]
  final RoutineType? routine;
  final bool includeFavorites;
  final int? currentQuoteId;
  final DateTime? lastRotationAt;
  final DateTime? nextRotationAt;
  final List<int> shuffleBag;
  final int contentVersion;

  const RotationSettingsModel({
    required this.surface,
    this.enabled = true,
    this.scheduleType = ScheduleType.interval,
    this.intervalHours = 12,
    this.specificTimes = const [],
    this.routine,
    this.includeFavorites = true,
    this.currentQuoteId,
    this.lastRotationAt,
    this.nextRotationAt,
    this.shuffleBag = const [],
    this.contentVersion = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'surface': surface.name,
      'enabled': enabled ? 1 : 0,
      'schedule_type': scheduleType.name,
      'interval_hours': intervalHours,
      'times_json': jsonEncode(specificTimes),
      'routine': routine?.name,
      'include_favorites': includeFavorites ? 1 : 0,
      'current_quote_id': currentQuoteId,
      'last_rotation_at': lastRotationAt?.toIso8601String(),
      'next_rotation_at': nextRotationAt?.toIso8601String(),
      'shuffle_bag_json': jsonEncode(shuffleBag),
      'content_version': contentVersion,
    };
  }

  factory RotationSettingsModel.fromMap(Map<String, dynamic> map) {
    List<int> times = [];
    if (map['times_json'] != null) {
      try {
        final decoded = jsonDecode(map['times_json'] as String);
        if (decoded is List) {
          times = decoded.map((e) => (e as num).toInt()).toList();
        }
      } catch (_) {}
    }

    List<int> bag = [];
    if (map['shuffle_bag_json'] != null) {
      try {
        final decoded = jsonDecode(map['shuffle_bag_json'] as String);
        if (decoded is List) {
          bag = decoded.map((e) => (e as num).toInt()).toList();
        }
      } catch (_) {}
    }

    return RotationSettingsModel(
      surface: SurfaceType.fromString(map['surface'] as String? ?? 'widget'),
      enabled: (map['enabled'] as int? ?? 1) == 1,
      scheduleType: ScheduleType.fromString(
        map['schedule_type'] as String? ?? 'interval',
      ),
      intervalHours: (map['interval_hours'] as int?) ?? 12,
      specificTimes: times,
      routine: map['routine'] != null
          ? RoutineType.fromString(map['routine'] as String)
          : null,
      includeFavorites: (map['include_favorites'] as int? ?? 1) == 1,
      currentQuoteId: map['current_quote_id'] as int?,
      lastRotationAt: map['last_rotation_at'] != null
          ? DateTime.tryParse(map['last_rotation_at'] as String)
          : null,
      nextRotationAt: map['next_rotation_at'] != null
          ? DateTime.tryParse(map['next_rotation_at'] as String)
          : null,
      shuffleBag: bag,
      contentVersion: (map['content_version'] as int?) ?? 1,
    );
  }

  RotationSettingsModel copyWith({
    bool? enabled,
    ScheduleType? scheduleType,
    int? intervalHours,
    List<int>? specificTimes,
    RoutineType? routine,
    bool? includeFavorites,
    int? currentQuoteId,
    DateTime? lastRotationAt,
    DateTime? nextRotationAt,
    List<int>? shuffleBag,
    int? contentVersion,
  }) {
    return RotationSettingsModel(
      surface: surface,
      enabled: enabled ?? this.enabled,
      scheduleType: scheduleType ?? this.scheduleType,
      intervalHours: intervalHours ?? this.intervalHours,
      specificTimes: specificTimes ?? this.specificTimes,
      routine: routine ?? this.routine,
      includeFavorites: includeFavorites ?? this.includeFavorites,
      currentQuoteId: currentQuoteId ?? this.currentQuoteId,
      lastRotationAt: lastRotationAt ?? this.lastRotationAt,
      nextRotationAt: nextRotationAt ?? this.nextRotationAt,
      shuffleBag: shuffleBag ?? this.shuffleBag,
      contentVersion: contentVersion ?? this.contentVersion,
    );
  }
}
