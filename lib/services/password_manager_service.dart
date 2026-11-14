import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/password_entry.dart';

class PasswordManagerService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _pinKey = 'pm_pin';
  static const _recoveryKey = 'pm_recovery_answer';
  static const _entriesKey = 'pm_entries';

  Future<bool> isSetupComplete() async {
    final pin = await _storage.read(key: _pinKey);
    final recovery = await _storage.read(key: _recoveryKey);
    return pin != null && recovery != null;
  }

  Future<void> setupSecurity(String pin, String recoveryAnswer) async {
    await _storage.write(key: _pinKey, value: pin);
    await _storage.write(key: _recoveryKey, value: recoveryAnswer.toLowerCase().trim());
  }

  Future<bool> authenticate(String pin) async {
    final savedPin = await _storage.read(key: _pinKey);
    return savedPin == pin;
  }

  Future<bool> verifyRecovery(String answer) async {
    final savedAnswer = await _storage.read(key: _recoveryKey);
    return savedAnswer == answer.toLowerCase().trim();
  }

  Future<List<PasswordEntry>> getEntries() async {
    final data = await _storage.read(key: _entriesKey);
    if (data == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((e) => PasswordEntry.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveEntries(List<PasswordEntry> entries) async {
    final data = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _storage.write(key: _entriesKey, value: data);
  }

  Future<void> addEntry(PasswordEntry entry) async {
    final entries = await getEntries();
    entries.add(entry);
    await saveEntries(entries);
  }

  Future<void> deleteEntry(String id) async {
    final entries = await getEntries();
    entries.removeWhere((e) => e.id == id);
    await saveEntries(entries);
  }

  Future<void> updateEntry(PasswordEntry updatedEntry) async {
    final entries = await getEntries();
    final index = entries.indexWhere((e) => e.id == updatedEntry.id);
    if (index != -1) {
      entries[index] = updatedEntry;
      await saveEntries(entries);
    }
  }
}
