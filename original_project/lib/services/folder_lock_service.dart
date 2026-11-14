import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class FolderLockService {
  FolderLockService._();
  static final FolderLockService instance = FolderLockService._();

  static const _prefsEnabledKey = 'folder_lock_enabled';
  static const _prefsLockedPathsKey = 'locked_folder_paths';
  static const _securePinKey = 'folder_lock_pin';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsEnabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabledKey, enabled);
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

  Future<Set<String>> getLockedPaths() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_prefsLockedPathsKey) ?? []).toSet();
  }

  Future<Set<String>> lockedFolders() => getLockedPaths();

  Future<void> setFolderLocked(String path, bool lock) async {
    final prefs = await SharedPreferences.getInstance();
    final paths = (prefs.getStringList(_prefsLockedPathsKey) ?? []).toSet();
    if (lock) {
      paths.add(path);
    } else {
      paths.remove(path);
    }
    await prefs.setStringList(_prefsLockedPathsKey, paths.toList());
  }

  bool _isSessionValid = false;
  bool isSessionValidSync() => _isSessionValid;
  Future<bool> isSessionValid() async => _isSessionValid;

  void lockSession() {
    _isSessionValid = false;
  }

  Future<void> toggleFolderLock(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final paths = (prefs.getStringList(_prefsLockedPathsKey) ?? []).toSet();
    if (paths.contains(path)) {
      paths.remove(path);
    } else {
      paths.add(path);
    }
    await prefs.setStringList(_prefsLockedPathsKey, paths.toList());
  }

  Future<bool> ensureUnlocked(BuildContext context, {required String reason}) async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Icon(Icons.lock_outline_rounded, size: 48, color: isDark ? Colors.white : Colors.black),
            const SizedBox(height: 16),
            Text('Unlock Folder', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reason, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: GoogleFonts.inter(),
              decoration: InputDecoration(
                hintText: 'Enter 4-digit PIN',
                filled: true,
                fillColor: isDark ? Colors.black : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final ok = await verifyPin(controller.text);
              if (ok) {
                _isSessionValid = true;
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
              }
            },
            child: Text('Unlock', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
