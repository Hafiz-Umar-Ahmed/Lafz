enum VerificationStatus {
  draft,
  sourceIdentified,
  verified,
  verifiedTranslation,
  reviewedDisputed,
  rejected,
  revoked;

  bool get isDisplayable =>
      this == VerificationStatus.verified ||
      this == VerificationStatus.verifiedTranslation;

  String get label {
    switch (this) {
      case VerificationStatus.draft:
        return 'Draft';
      case VerificationStatus.sourceIdentified:
        return 'Source Identified';
      case VerificationStatus.verified:
        return 'Verified';
      case VerificationStatus.verifiedTranslation:
        return 'Verified Translation';
      case VerificationStatus.reviewedDisputed:
        return 'Disputed';
      case VerificationStatus.rejected:
        return 'Rejected';
      case VerificationStatus.revoked:
        return 'Revoked';
    }
  }

  static VerificationStatus fromString(String value) {
    return VerificationStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase().replaceAll('-', '_'),
      orElse: () => VerificationStatus.draft,
    );
  }
}

enum PublicationStatus {
  draft,
  published,
  archived,
  revoked;

  bool get isVisible => this == PublicationStatus.published;

  static PublicationStatus fromString(String value) {
    return PublicationStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => PublicationStatus.draft,
    );
  }
}

enum ContentTier {
  free,
  premium;

  static ContentTier fromString(String value) {
    return ContentTier.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ContentTier.free,
    );
  }
}

enum ScheduleType {
  interval,
  specificTimes,
  routine,
  manual;

  String get label {
    switch (this) {
      case ScheduleType.interval:
        return 'Regular Interval';
      case ScheduleType.specificTimes:
        return 'Specific Times';
      case ScheduleType.routine:
        return 'Daily Routines';
      case ScheduleType.manual:
        return 'Manual Only';
    }
  }

  static ScheduleType fromString(String value) {
    return ScheduleType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ScheduleType.interval,
    );
  }
}

enum IntervalHours {
  six(6, 'Every 6 hours'),
  eight(8, 'Every 8 hours'),
  twelve(12, 'Every 12 hours'),
  twentyFour(24, 'Once a day (24h)');

  final int hours;
  final String label;
  const IntervalHours(this.hours, this.label);

  static IntervalHours fromHours(int hours) {
    return IntervalHours.values.firstWhere(
      (e) => e.hours == hours,
      orElse: () => IntervalHours.twelve,
    );
  }
}

enum RoutineType {
  morning('Morning (Fajr/Dawn)', 6),
  study('Study / Focus', 10),
  work('Midday Work', 14),
  evening('Evening (Maghrib/Dusk)', 18),
  sleep('Night Reflection', 22);

  final String label;
  final int defaultHour;
  const RoutineType(this.label, this.defaultHour);

  static RoutineType fromString(String value) {
    return RoutineType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => RoutineType.morning,
    );
  }
}

enum SurfaceType {
  widget('Widget'),
  wallpaper('Wallpaper');

  final String label;
  const SurfaceType(this.label);

  static SurfaceType fromString(String value) {
    return SurfaceType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => SurfaceType.widget,
    );
  }
}

enum WallpaperPreset {
  minimal('Minimal', 0xFF121417, 0xFFF5F7FA, 'Playfair Display'),
  dark('Dark Studio', 0xFF0D0F12, 0xFFE2E8F0, 'Plus Jakarta Sans'),
  light('Clean Light', 0xFFF8FAFC, 0xFF0F172A, 'Plus Jakarta Sans'),
  nature('Nature Calm', 0xFF1B2E24, 0xFFF0FDF4, 'Lora'),
  architecture('Monolith', 0xFF1E1E24, 0xFFE0E0E6, 'Cinzel'),
  abstractPreset('Elysian Abstract', 0xFF231942, 0xFFF3C68F, 'Plus Jakarta Sans'),
  editorial('Editorial Serif', 0xFF18181B, 0xFFFAFAFA, 'Cinzel'),
  clean('Modern Clean', 0xFF27272A, 0xFFFFFFFF, 'Plus Jakarta Sans');

  final String label;
  final int defaultBgColor;
  final int defaultTextColor;
  final String recommendedFont;

  const WallpaperPreset(
    this.label,
    this.defaultBgColor,
    this.defaultTextColor,
    this.recommendedFont,
  );

  static WallpaperPreset fromString(String value) {
    return WallpaperPreset.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => WallpaperPreset.minimal,
    );
  }
}

enum BackgroundType {
  solid,
  gradient,
  scenery;

  static BackgroundType fromString(String value) {
    return BackgroundType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => BackgroundType.solid,
    );
  }
}

enum WallpaperTextAlignment {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight;

  static WallpaperTextAlignment fromString(String value) {
    return WallpaperTextAlignment.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => WallpaperTextAlignment.center,
    );
  }
}

enum WallpaperDestination {
  lockScreen('Lock Screen'),
  homeScreen('Home Screen'),
  both('Both Screens');

  final String label;
  const WallpaperDestination(this.label);

  static WallpaperDestination fromString(String value) {
    return WallpaperDestination.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => WallpaperDestination.lockScreen,
    );
  }
}

enum SourceType {
  book,
  speech,
  interview,
  quran,
  hadith,
  other;

  static SourceType fromString(String value) {
    return SourceType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => SourceType.other,
    );
  }
}

enum AppLanguage {
  english('en', 'English', false),
  arabic('ar', 'العربية', true),
  urdu('ur', 'اردو', true);

  final String code;
  final String displayName;
  final bool isRtl;

  const AppLanguage(this.code, this.displayName, this.isRtl);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (e) => e.code.toLowerCase() == code.toLowerCase(),
      orElse: () => AppLanguage.english,
    );
  }
}

enum CollectionType {
  category('Category'),
  subcategory('Subcategory'),
  personality('Personality'),
  creatorCollection('Curated Collection'),
  personalCollection('Personal Collection');

  final String label;
  const CollectionType(this.label);

  static CollectionType fromString(String value) {
    return CollectionType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => CollectionType.category,
    );
  }
}

enum OnboardingStep {
  welcome,
  interests,
  personalities,
  wallpaperStyle,
  widgetSchedule,
  wallpaperSchedule,
  addWidget,
  automationSetup;
}

enum SubmissionStatus {
  received('Received'),
  accepted('Accepted'),
  rejected('Rejected');

  final String label;
  const SubmissionStatus(this.label);

  static SubmissionStatus fromString(String value) {
    return SubmissionStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => SubmissionStatus.received,
    );
  }
}
