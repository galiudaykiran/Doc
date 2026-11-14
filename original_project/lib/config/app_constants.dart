/// Professional App Constants for MNC-grade consistency
/// Document Hub - Enterprise Document Management Solution
library;

class AppConstants {
  // App Identity
  static const String appName = 'Document Hub';
  static const String appTagline = 'Smart Document Management';
  static const String appVersion = '2.0.0';
  static const String appBuildNumber = '2024.02.11';

  // Company/Brand Info
  static const String companyName = 'Document Hub Inc.';
  static const String supportEmail = 'support@documenthub.app';
  static const String privacyPolicyUrl = 'https://documenthub.app/privacy';
  static const String termsOfServiceUrl = 'https://documenthub.app/terms';

  // Feature Limits (Free Tier)
  static const int maxFreeCollections = 10;
  static const int maxFreePdfPages = 50;
  static const int maxFreeScans = 100;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration longAnimation = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 300);

  // UI Dimensions
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusXLarge = 24.0;

  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  static const double iconSizeSmall = 20.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;

  static const double cardElevation = 4.0;
  static const double dialogElevation = 8.0;

  // Auto-save & Performance
  static const Duration autoSaveDelay = Duration(seconds: 2);
  static const Duration searchDebounce = Duration(milliseconds: 300);
  static const int maxHistoryItems = 50;
  static const int maxRecentItems = 20;
  static const int maxFavorites = 100;

  // File Size Limits
  static const int maxImageSizeMb = 25;
  static const int maxPdfSizeMb = 100;
  static const int maxTotalStorageMb = 2048;

  // Supported Formats
  static const List<String> supportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
  ];
  static const List<String> supportedDocumentFormats = [
    'pdf',
    'doc',
    'docx',
    'txt',
    'rtf',
    'odt',
  ];
  static const List<String> supportedMediaFormats = [
    'mp4',
    'mov',
    'avi',
    'mp3',
    'wav',
    'aac',
  ];

  // Cache Settings
  static const int thumbnailCacheSize = 100;
  static const Duration cacheExpiry = Duration(days: 7);
}

/// Professional Color Palette - Deep Indigo Style
class AppColors {
  // Primary Brand Colors (Deep Indigo)
  static const int primaryIndigo = 0xFF4F46E5;
  static const int primaryIndigoDark = 0xFF3730A3;
  static const int primaryIndigoLight = 0xFF818CF8;

  // Legacy aliases for compatibility
  static const int primaryGray = primaryIndigo;
  static const int primaryGrayDark = primaryIndigoDark;
  static const int primaryGrayLight = primaryIndigoLight;
  static const int primaryGreen = primaryIndigo;
  static const int primaryGreenDark = primaryIndigoDark;
  static const int primaryGreenLight = primaryIndigoLight;
  static const int primaryCyan = primaryIndigo;
  static const int primaryCyanDark = primaryIndigoDark;
  static const int primaryCyanLight = primaryIndigoLight;

  // Semantic Colors (kept for status indicators)
  static const int success = 0xFF10B981;
  static const int warning = 0xFFF59E0B;
  static const int error = 0xFFEF4444;
  static const int info = 0xFF3B82F6;

  // Neutral Colors - Pure dark/light mode
  static const int neutralDark = 0xFF0A0A0A;
  static const int neutralMedium = 0xFF6B7280;
  static const int neutralLight = 0xFF1A1A2E;
  static const int neutralWhite = 0xFFFAFAFF;

  // Gradients (Deep Indigo)
  static const List<int> primaryGradient = [0xFF4F46E5, 0xFF3730A3];
  static const List<int> warmGradient = [0xFFEC4899, 0xFFF59E0B];
  static const List<int> coolGradient = [0xFF6366F1, 0xFF8B5CF6];
  static const List<int> darkGradient = [0xFF1E1B4B, 0xFF312E81];
}

/// Text Styles following Material Design 3
class AppTextStyles {
  static const String primaryFont = 'Poppins';
  static const String secondaryFont = 'Inter';
  static const String monoFont = 'JetBrains Mono';

  // Font Weights
  static const int weightLight = 300;
  static const int weightRegular = 400;
  static const int weightMedium = 500;
  static const int weightSemiBold = 600;
  static const int weightBold = 700;
}

/// Spacing System (8pt Grid)
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}
