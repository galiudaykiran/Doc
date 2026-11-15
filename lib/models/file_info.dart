import 'dart:io';
import 'package:flutter/material.dart';

class FileInfo {
  final String name;
  final String path;
  final FileType type;
  DateTime? _lastModified;
  int? _size;

  FileInfo({
    required this.name,
    required this.path,
    required this.type,
    DateTime? lastModified,
    int? size,
  })  : _lastModified = lastModified,
        _size = size;

  DateTime get lastModified {
    if (_lastModified != null) return _lastModified!;
    try {
      final file = File(path);
      if (file.existsSync()) {
        _lastModified = file.lastModifiedSync();
        return _lastModified!;
      }
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  int get size {
    if (_size != null) return _size!;
    try {
      final file = File(path);
      if (file.existsSync()) {
        _size = file.lengthSync();
        return _size!;
      }
    } catch (_) {}
    return 0;
  }

  IconData get icon {
    switch (type) {
      case FileType.image:
        return Icons.image;
      case FileType.pdf:
        return Icons.picture_as_pdf;
      case FileType.document:
        return Icons.description;
      case FileType.video:
        return Icons.video_file;
      case FileType.audio:
        return Icons.audio_file;
      case FileType.unknown:
        return Icons.insert_drive_file;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileInfo && runtimeType == other.runtimeType && path == other.path;

  @override
  int get hashCode => path.hashCode;
}

enum FileType {
  image,
  pdf,
  document,
  video,
  audio,
  unknown,
}

FileType getFileType(String path) {
  final String extension = path.split('.').last.toLowerCase();
  switch (extension) {
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'bmp':
    case 'webp':
      return FileType.image;
    case 'pdf':
      return FileType.pdf;
    case 'doc':
    case 'docx':
    case 'txt':
    case 'rtf':
    case 'odt':
      return FileType.document;
    case 'mp4':
    case 'mov':
    case 'avi':
    case 'mkv':
      return FileType.video;
    case 'mp3':
    case 'wav':
    case 'aac':
      return FileType.audio;
    default:
      return FileType.unknown;
  }
}
