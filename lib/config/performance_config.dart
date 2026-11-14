/// App Performance Configuration
///
/// This file contains constants and configurations
/// for optimizing app performance
library;

class PerformanceConfig {
  // Image caching settings
  static const int maxImageCacheSize = 100; // MB
  static const int thumbnailSize = 150; // pixels
  static const int largeImageSize = 800; // pixels

  // List rendering
  static const int initialListLoadCount = 20;
  static const int listPageSize = 20;
  static const double listItemHeight = 100.0;

  // Animation durations
  static const Duration quickAnimationDuration = Duration(milliseconds: 200);
  static const Duration standardAnimationDuration = Duration(milliseconds: 300);
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);

  // Debounce/Throttle durations
  static const Duration searchDebounceDelay = Duration(milliseconds: 300);
  static const Duration scrollThrottleDelay = Duration(milliseconds: 100);
  static const Duration autoSaveDelay = Duration(seconds: 2);

  // File operations
  static const int maxConcurrentFileOps = 3;
  static const Duration fileOpTimeout = Duration(seconds: 30);

  // Memory management
  static const int maxHistorySize = 50;
  static const int maxRecentItems = 10;

  // Cache settings
  static const Duration cacheValidityDuration = Duration(hours: 24);
  static const bool enableImageCaching = true;
  static const bool enableMemoryCache = true;
}
