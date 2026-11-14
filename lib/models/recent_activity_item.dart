import 'dart:convert';

class RecentActivityItem {
  final String id;
  final String title;
  final String subtitle;
  final String type; // 'folder', 'note', 'document', 'credential'
  final DateTime timestamp;
  final String? targetPath;

  const RecentActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.timestamp,
    this.targetPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'targetPath': targetPath,
    };
  }

  factory RecentActivityItem.fromMap(Map<String, dynamic> map) {
    return RecentActivityItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      subtitle: map['subtitle'] ?? '',
      type: map['type'] ?? 'folder',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      targetPath: map['targetPath'],
    );
  }

  String toJson() => jsonEncode(toMap());

  factory RecentActivityItem.fromJson(String source) =>
      RecentActivityItem.fromMap(jsonDecode(source));
}

