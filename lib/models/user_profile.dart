import 'dart:convert';

class UserProfile {
  final String username;
  final String email;
  final String dob;
  final String phone;
  final String aadhar;
  final Map<String, String> customFields;

  const UserProfile({
    required this.username,
    required this.email,
    required this.dob,
    required this.phone,
    required this.aadhar,
    this.customFields = const {},
  });

  UserProfile copyWith({
    String? username,
    String? email,
    String? dob,
    String? phone,
    String? aadhar,
    Map<String, String>? customFields,
  }) {
    return UserProfile(
      username: username ?? this.username,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      phone: phone ?? this.phone,
      aadhar: aadhar ?? this.aadhar,
      customFields: customFields ?? this.customFields,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'dob': dob,
      'phone': phone,
      'aadhar': aadhar,
      'customFields': customFields,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    Map<String, String> parsedCustomFields = {};
    if (map['customFields'] != null && map['customFields'] is Map) {
      final rawMap = map['customFields'] as Map;
      rawMap.forEach((key, value) {
        parsedCustomFields[key.toString()] = value.toString();
      });
    }

    return UserProfile(
      username: map['username'] ?? 'Uday Kiran',
      email: map['email'] ?? 'uday.docs@gmail.com',
      dob: map['dob'] ?? '15/08/1998',
      phone: map['phone'] ?? '+91 98765 43210',
      aadhar: map['aadhar'] ?? '5412 8965 2314',
      customFields: parsedCustomFields,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserProfile.fromJson(String source) =>
      UserProfile.fromMap(jsonDecode(source));
}

