class FolderNotes {
  final String folderPath;
  String notesContent;
  bool isPinned;
  int? noteColor;
  DateTime? lastEdited;
  List<String> tags;

  FolderNotes({
    required this.folderPath,
    this.notesContent = '',
    this.lastEdited,
    this.isPinned = false,
    this.noteColor,
    List<String>? tags,
  }) : tags = tags ?? [];

  // Convert a FolderNotes object into a Map object
  Map<String, dynamic> toMap() {
    return {
      'folderPath': folderPath,
      'notesContent': notesContent,
      'lastEdited': lastEdited?.toIso8601String(),
      'isPinned': isPinned,
      'noteColor': noteColor,
      'tags': tags,
    };
  }

  // Extract a FolderNotes object from a Map object
  factory FolderNotes.fromMap(Map<String, dynamic> map) {
    return FolderNotes(
      folderPath: map['folderPath'],
      notesContent: map['notesContent'] ?? '',
      lastEdited: map['lastEdited'] != null
          ? DateTime.parse(map['lastEdited'])
          : null,
      isPinned: map['isPinned'] ?? false,
      noteColor: map['noteColor'],
      tags: List<String>.from(map['tags'] ?? []),
    );
  }
}
