import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/premium_pin_overlay.dart';

class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  static const _prefsEnabledKey = 'app_lock_enabled';
  static const _securePinKey = 'app_lock_pin';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  bool _isUnlocked = false;
  bool get isUnlocked => _isUnlocked;
  bool get isLocked => !_isUnlocked;

  Future<void> lockSession() async {
    _isUnlocked = false;
  }

  Future<void> onAppPaused() async {
    _isUnlocked = false;
  }

  static Future<void> showLockScreen(BuildContext context) async {
    await instance.showLockScreenDialog(context);
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsEnabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabledKey, enabled);
    if (!enabled) _isUnlocked = true;
  }

  Future<bool> hasPin() async {
    final pin = await _secureStorage.read(key: _securePinKey);
    return pin != null && pin.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    await _secureStorage.write(key: _securePinKey, value: pin);
  }

  Future<bool> verifyPin(String pin) async {
    final savedPin = await _secureStorage.read(key: _securePinKey);
    return savedPin == pin;
  }

  void unlock() => _isUnlocked = true;
  void lock() => _isUnlocked = false;

  Future<bool> showLockScreenDialog(BuildContext context) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, anim1, anim2) {
        return PremiumPinOverlay(
          title: 'Enter App PIN',
          onVerify: (pin) async {
            final ok = await verifyPin(pin);
            if (ok) _isUnlocked = true;
            return ok;
          },
        );
      },
    );
    return result ?? false;
  }
}
