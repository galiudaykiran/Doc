import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Screen device breakpoint classification
enum DeviceScreenType {
  compact, // Mobile (< 600)
  medium,  // Tablet / Foldable (600 - 900)
  expanded // Desktop / Large Tablet (> 900)
}

/// Helper utility for adaptive screens and overflow elimination across all devices
class ResponsiveLayout {
  ResponsiveLayout._();

  /// Get current screen classification
  static DeviceScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return DeviceScreenType.compact;
    if (width < 900) return DeviceScreenType.medium;
    return DeviceScreenType.expanded;
  }

  /// Whether current device is a compact mobile screen
  static bool isCompact(BuildContext context) =>
      getScreenType(context) == DeviceScreenType.compact;

  /// Whether current device is tablet / foldable / wide screen
  static bool isMediumOrExpanded(BuildContext context) =>
      getScreenType(context) != DeviceScreenType.compact;

  /// Calculate optimal grid columns adaptively based on screen width
  /// Guarantees that items never look squeezed or overflowing
  static int getAdaptiveGridColumns(
    BuildContext context, {
    double minItemWidth = 160.0,
    int minColumns = 2,
    int maxColumns = 6,
    double horizontalPadding = 32.0,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final availableWidth = screenWidth - horizontalPadding;
    final calculated = (availableWidth / minItemWidth).floor();
    return calculated.clamp(minColumns, maxColumns);
  }

  /// Calculate adaptive child aspect ratio for document/folder cards
  static double getCardAspectRatio(BuildContext context, {bool isCompactGrid = false}) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth < 360) {
      // Very small phones (e.g. small Androids)
      return isCompactGrid ? 0.70 : 0.78;
    } else if (screenWidth < 600) {
      // Standard mobile
      return isCompactGrid ? 0.75 : 0.85;
    } else {
      // Tablets and desktop
      return 0.88;
    }
  }

  /// Get a safe text scale factor clamped to prevent UI overflow from extreme OS settings
  static double getClampedTextScale(BuildContext context, {double min = 0.85, double max = 1.25}) {
    final factor = MediaQuery.textScalerOf(context).scale(1.0);
    return factor.clamp(min, max);
  }

  /// Dialog and BottomSheet max width constraint for tablets/desktop
  static double getDialogMaxWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return math.min(screenWidth * 0.92, 540.0);
  }

  /// Safe padding for keyboard input views to prevent RenderFlex overflow
  static EdgeInsets getKeyboardPadding(BuildContext context, {double defaultBottom = 24.0}) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return EdgeInsets.only(bottom: math.max(defaultBottom, bottomInset + 16.0));
  }
}

/// A wrapper widget that clamps text scaling factor to prevent text overflow
class SafeTextScaleScope extends StatelessWidget {
  final Widget child;
  final double minScale;
  final double maxScale;

  const SafeTextScaleScope({
    super.key,
    required this.child,
    this.minScale = 0.85,
    this.maxScale = 1.25,
  });

  @override
  Widget build(BuildContext context) {
    final currentScaler = MediaQuery.textScalerOf(context);
    final clampedScale = currentScaler.scale(1.0).clamp(minScale, maxScale);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(clampedScale),
      ),
      child: child,
    );
  }
}

