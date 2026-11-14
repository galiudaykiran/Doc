import 'dart:convert';

class PasswordEntry {
  final String id;
  final String title;
  final String username;
  final String password;
  final String? website;
  final DateTime createdAt;

  PasswordEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    this.website,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'username': username,
    'password': password,
    'website': website,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PasswordEntry.fromJson(Map<String, dynamic> json) => PasswordEntry(
    id: json['id'],
    title: json['title'],
    username: json['username'],
    password: json['password'],
    website: json['website'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}
