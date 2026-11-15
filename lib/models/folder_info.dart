import 'dart:io';
import 'package:gallery_app/models/file_info.dart';

class FolderInfo {
  final String name;
  final String path;
  final List<FileInfo> files;
  final String? customThumbnailPath;
  DateTime? _lastModified;
  String? _cachedThumbnailPath;

  FolderInfo({
    required this.name,
    required this.path,
    this.files = const [],
    this.customThumbnailPath,
    DateTime? lastModified,
  }) : _lastModified = lastModified;

  int get fileCount => files.length;

  DateTime get lastModified {
    if (_lastModified != null) return _lastModified!;
    try {
      final dir = Directory(path);
      if (dir.existsSync()) {
        _lastModified = dir.statSync().modified;
        return _lastModified!;
      }
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String? get thumbnailPath {
    if (customThumbnailPath != null) {
      return customThumbnailPath;
    }
    if (_cachedThumbnailPath != null) {
      return _cachedThumbnailPath;
    }
    for (final f in files) {
      if (f.type == FileType.image) {
        _cachedThumbnailPath = f.path;
        return f.path;
      }
    }
    return null;
  }
}
