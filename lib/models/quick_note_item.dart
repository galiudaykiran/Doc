class QuickNoteItem {
  final String id;
  String title;
  String category;
  String contentSnippet;
  DateTime lastUpdated;
  bool isPinned;

  QuickNoteItem({
    required this.id,
    required this.title,
    required this.category,
    required this.contentSnippet,
    required this.lastUpdated,
    this.isPinned = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'category': category,
    'contentSnippet': contentSnippet,
    'lastUpdated': lastUpdated.toIso8601String(),
    'isPinned': isPinned,
  };

  factory QuickNoteItem.fromMap(Map<String, dynamic> map) => QuickNoteItem(
    id: map['id'] ?? '',
    title: map['title'] ?? '',
    category: map['category'] ?? 'Personal',
    contentSnippet: map['contentSnippet'] ?? '',
    lastUpdated: map['lastUpdated'] != null
        ? DateTime.parse(map['lastUpdated'])
        : DateTime.now(),
    isPinned: map['isPinned'] ?? false,
  );
}

