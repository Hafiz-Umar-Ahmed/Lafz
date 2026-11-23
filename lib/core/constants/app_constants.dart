abstract final class AppConstants {
  static const String appName = 'Lafz';
  static const String appTagline = 'Your chosen wisdom, beautifully delivered.';
  
  // Database & Content
  static const String dbName = 'lafz.db';
  static const int currentSchemaVersion = 1;
  static const String contentPackageDir = 'content';
  static const String baselinePackageAsset = 'assets/content/baseline_content.json';
  
  // Rotation & Schedules
  static const int defaultIntervalHours = 12;
  static const int widgetTimelineDays = 7;
  static const int overdueMultiplier = 2; // Warning if overdue > 2x interval
  
  // Rendering & Typography
  static const double minFontSize = 14.0;
  static const double maxFontSize = 46.0;
  static const double defaultFontSize = 22.0;
  static const double contrastThreshold = 4.5; // WCAG 2.1 AA
  static const double defaultOverlayOpacity = 0.38;
  static const int maxRenderTimeMs = 3000;
  
  // Safe Areas for Lockscreen and Homescreen Wallpapers
  static const double lockScreenClockTopPercent = 0.22; // Reserve top 22% for clock/date
  static const double lockScreenWidgetBottomPercent = 0.14; // Reserve bottom 14% for gestures/shortcuts
  static const double homeScreenDockBottomPercent = 0.18; // Reserve bottom 18% for dock apps
  
  // Fallback Quote (M3 & M4 requirements)
  static const String fallbackQuoteText =
      'The only true wisdom is in knowing you know nothing.';
  static const String fallbackQuoteAttribution = 'Socrates';
  static const String fallbackQuoteSource = 'Plato, Apology';
  
  // Onboarding
  static const int onboardingTargetSeconds = 90;
  
  // Method Channels
  static const String wallpaperChannelName = 'com.lafz.lafz/wallpaper';
  static const String widgetChannelName = 'com.lafz.lafz/widget';
}
