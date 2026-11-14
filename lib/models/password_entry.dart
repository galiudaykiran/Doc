class PasswordEntry {
  final String id;
  final String title;
  final String username;
  final String password;
  final String? website;
  final String category;
  final DateTime createdAt;

  PasswordEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    this.website,
    this.category = 'Account',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'username': username,
    'password': password,
    'website': website,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PasswordEntry.fromJson(Map<String, dynamic> json) => PasswordEntry(
    id: json['id'],
    title: json['title'],
    username: json['username'],
    password: json['password'],
    website: json['website'],
    category: json['category'] ?? 'Account',
    createdAt: DateTime.parse(json['createdAt']),
  );
}
