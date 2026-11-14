import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage custom accent color with persistence
class AccentColorService {
  AccentColorService._();
  static final AccentColorService instance = AccentColorService._();

  static const String _prefsColorKey = 'accent_color_value';
  static const int _defaultColor = 0xFF000000; // Black

  /// Available preset colors
  static const List<AccentColorOption> presetColors = [
    AccentColorOption('Black', Color(0xFF000000)),
  ];

  Color _currentColor = const Color(_defaultColor);
  Color get currentColor => _currentColor;

  /// Load the saved accent color
  Future<Color> loadAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_prefsColorKey) ?? _defaultColor;
    
    bool isValid = presetColors.any((element) => element.color.value == colorValue);
    
    if (!isValid) {
      _currentColor = const Color(_defaultColor);
      // ignore: deprecated_member_use
      await prefs.setInt(_prefsColorKey, _defaultColor);
    } else {
      _currentColor = Color(colorValue);
    }
    
    return _currentColor;
  }

  /// Alias for loadAccentColor
  Future<Color> loadColor() => loadAccentColor();

  /// Save accent color
  Future<void> saveAccentColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    // ignore: deprecated_member_use
    await prefs.setInt(_prefsColorKey, color.value);
    _currentColor = color;
  }

  /// Alias for saveAccentColor
  Future<void> saveColor(Color color) => saveAccentColor(color);

  /// Reset to default
  Future<void> resetToDefault() async {
    await saveAccentColor(const Color(_defaultColor));
  }
}

class AccentColorOption {
  final String name;
  final Color color;

  const AccentColorOption(this.name, this.color);
}
