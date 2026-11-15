import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class ProfileService {
  static const String _prefKey = 'hub_user_profile_v1';

  static Future<UserProfile> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      try {
        return UserProfile.fromJson(raw);
      } catch (_) {}
    }
    // Default initial profile
    return const UserProfile(
      username: 'Uday Kiran',
      email: 'uday.docs@gmail.com',
      dob: '15/08/1998',
      phone: '+91 98765 43210',
      aadhar: '5412 8965 2314',
    );
  }

  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, profile.toJson());
  }
}

